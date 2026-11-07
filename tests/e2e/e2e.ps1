#requires -Version 5.1
# Siempre crea su propio cluster y restaura en otra base; nunca usa la VM activa.
param([string]$PgBin='C:\Program Files\PostgreSQL\16\bin',
      [string]$Salida=(Join-Path ([IO.Path]::GetTempPath()) ('PlanBot_E2E_'+[Guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { Write-Host 'OMITIDO: e2e de contingencia requiere Windows/.NET Framework; no es un E2E aprobado en Linux.'; return }
$raizE2e=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $raizE2e 'tools\vm\psql_robot.ps1')
$psql=Join-Path $PgBin 'psql.exe'; $ctl=Join-Path $PgBin 'pg_ctl.exe'
foreach($f in @($psql,$ctl,(Join-Path $PgBin 'initdb.exe'),(Join-Path $PgBin 'pg_dump.exe'),(Join-Path $PgBin 'pg_restore.exe'))) {
    if (-not (Test-Path -LiteralPath $f)) { throw "Falta $f" }
}
if (Test-Path -LiteralPath $Salida) { throw 'Salida del e2e debe ser nueva; no se reutiliza un cluster.' }
New-Item -ItemType Directory -Path $Salida | Out-Null
$Salida=(Resolve-Path -LiteralPath $Salida).Path
$fuente=Join-Path $Salida 'fuente'; $datos=Join-Path $Salida 'pgdata'
$sha=(& git -C $raizE2e rev-parse HEAD).Trim()
& git -C $raizE2e archive --format=zip "--output=$Salida\fuente.zip" $sha database scripts tests/sql data/csv .env.example
if ($LASTEXITCODE -ne 0) { throw 'No se pudo congelar back de HEAD.' }
Expand-Archive -LiteralPath (Join-Path $Salida 'fuente.zip') -DestinationPath $fuente
$oyente=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$oyente.Start(); $puerto=$oyente.LocalEndpoint.Port; $oyente.Stop()
if ($puerto -in @(5432,5433,3000,8080)) { throw 'No se usa puerto reservado del equipo.' }
$sqlRuta=Join-Path $Salida 'consulta.sql'
$conexion=@{Psql=$psql;Servidor='127.0.0.1';Puerto=$puerto;Base='planbot';Usuario='owner_planbot';VariableClave='POSTGRES_PASSWORD'}
$previos=@{}
foreach($k in @('POSTGRES_PASSWORD','BOT_CARGA_PASSWORD','WEB_LECTURA_PASSWORD','PGCONNECT_TIMEOUT','PGPASSWORD')) { $previos[$k]=[Environment]::GetEnvironmentVariable($k,'Process') }
$iniciado=$false; $codigoE2e=1
function Controlar-E2e([string]$Operacion) {
    $argumentos=@('-D',('"'+$datos+'"'),'-w','-t','20')
    if ($Operacion -eq 'start') { $argumentos+=@('-l',('"'+(Join-Path $Salida 'postgres.log')+'"'),'-o',('"-h 127.0.0.1 -p '+$puerto+'"'),'start') }
    else { $argumentos+=@('-m','fast','stop') }
    # .WaitForExit solo espera pg_ctl; Start-Process -Wait esperaría también al servidor.
    $p=Start-Process -FilePath $ctl -ArgumentList $argumentos -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Salida ($Operacion+'.out')) -RedirectStandardError (Join-Path $Salida ($Operacion+'.err'))
    $handleControl=$p.Handle
    if (-not $p.WaitForExit(30000)) { throw "Timeout pg_ctl $Operacion" }
    if ($p.ExitCode -ne 0) { throw "pg_ctl $Operacion fallo; revisar $Operacion.err" }
}
function Consultar-E2e([string]$Sql,[string]$ArchivoSalida='') {
    $q=Write-RobotSql $sqlRuta $Sql
    $s=Invoke-RobotPsql @conexion -ArchivoSql $q
    if ($ArchivoSalida) { [IO.File]::WriteAllText((Join-Path $Salida $ArchivoSalida),$s,(New-Object Text.UTF8Encoding($false))) }
    return $s
}
function Simular-E2e([string]$Archivo,[string]$Caso,[string]$Base='planbot') {
    $r=& (Join-Path $raizE2e 'tools\vm\simular_robot.ps1') -Archivo $Archivo -Servidor '127.0.0.1' -Puerto $puerto -Base $Base -PgBin $PgBin -EnvArchivo (Join-Path $fuente '.env') -Salida (Join-Path $Salida $Caso)
    if ($r.estado -ne 'cargada' -and $r.estado -ne 'archivo repetido') { throw "Simulador no completo $Caso" }
    return $r
}
function Script-E2e([string]$Archivo,[string[]]$Opciones,[string]$NombreLog) {
    $a=@('-NoProfile','-File',('"'+$Archivo+'"'))+$Opciones
    $p=Start-Process -FilePath $hostPs -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Salida ($NombreLog+'.log')) -RedirectStandardError (Join-Path $Salida ($NombreLog+'.err'))
    $handleScript=$p.Handle
    if(-not $p.WaitForExit(120000)) { Stop-Process -Id $p.Id; throw "Timeout $NombreLog" }
    if($p.ExitCode -ne 0) { throw "Fallo $NombreLog; revisar .log/.err" }
}
try {
    $env:POSTGRES_PASSWORD='solo_ensayo_owner'; $env:BOT_CARGA_PASSWORD='solo_ensayo_bot'; $env:WEB_LECTURA_PASSWORD='solo_ensayo_web'; $env:PGCONNECT_TIMEOUT='3'
    & (Join-Path $PgBin 'initdb.exe') -D $datos -U integracion_admin --auth=trust --no-locale --encoding=UTF8 *> (Join-Path $Salida 'initdb.log')
    if ($LASTEXITCODE -ne 0) { throw 'initdb fallo' }
    Controlar-E2e 'start'; $iniciado=$true
    $admin=@{}+$conexion; $admin.Usuario='integracion_admin'; $admin.Base='postgres'
    $q=Write-RobotSql $sqlRuta "SELECT current_setting('data_directory');"
    $ubicacion=Invoke-RobotPsql @admin -ArchivoSql $q
    if ([IO.Path]::GetFullPath($ubicacion) -ne [IO.Path]::GetFullPath($datos)) { throw 'No coincide el cluster; no se continua.' }
    $env:PGPASSWORD=$env:POSTGRES_PASSWORD
    & $psql -X -w -h 127.0.0.1 -p $puerto -U integracion_admin -d postgres -v ON_ERROR_STOP=1 -v owner=owner_planbot -v owner_pwd=solo_ensayo_owner -v db=planbot -f (Join-Path $fuente 'database\instalar\crear_base.sql') *> (Join-Path $Salida 'crear_base.log')
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base privada' }
    @('POSTGRES_DB=planbot','POSTGRES_USER=owner_planbot','POSTGRES_PASSWORD=solo_ensayo_owner','BOT_CARGA_PASSWORD=solo_ensayo_bot','WEB_LECTURA_PASSWORD=solo_ensayo_web','PG_HOST=127.0.0.1',"PG_PORT=$puerto","PG_BIN=$PgBin") | Set-Content -LiteralPath (Join-Path $fuente '.env') -Encoding UTF8
    $hostPs=Join-Path $PSHOME 'powershell.exe'; if (-not (Test-Path $hostPs)) { $hostPs=(Get-Command pwsh.exe).Source }
    Script-E2e (Join-Path $fuente 'scripts\migrar.ps1') @('-Modo','nativo') 'migrar'
    Write-Host 'OK: cluster exclusivo y migraciones del back (sin servicios activos)'
    $original=Join-Path $raizE2e 'data\buk\01_original.xlsx'; $cambios=Join-Path $raizE2e 'data\buk\02_cambios.xlsx'
    $r01=Simular-E2e $original '01'
    Script-E2e (Join-Path $fuente 'scripts\test.ps1') @('-Modulo','db','-Modo','nativo') 'test_db'
    Write-Host 'OK: suite SQL de Andres sobre original'
    $planSql="SELECT coalesce(json_agg(json_build_object('persona_id',p.persona_id,'it',p.it,'mes',p.mes,'fila',to_jsonb(p)-'calculado_en')),'[]'::json) FROM calc.plan_mes p;"
    $null=Consultar-E2e $planSql 'antes.json'
    & (Join-Path $PgBin 'pg_dump.exe') -w -h 127.0.0.1 -p $puerto -U owner_planbot -d planbot -Fc -f (Join-Path $Salida '01.dump')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo snapshot 01' }
    $r02=Simular-E2e $cambios '02'
    $null=Consultar-E2e ("SELECT coalesce(json_agg(r),'[]'::json) FROM (SELECT tipo,persona_id,it,mes_vigencia FROM api.v_cambios WHERE carga_id="+[long]$r02.carga_id+") r;") 'cambios.json'
    $null=Consultar-E2e $planSql 'despues.json'
    $nAntes=Consultar-E2e 'SELECT count(*) FROM stg.carga;'
    $dup=Simular-E2e $cambios 'duplicado'
    if ($nAntes -ne (Consultar-E2e 'SELECT count(*) FROM stg.carga;')) { throw 'Duplicado creo carga nueva' }
    # Otra huella, mismos datos: entrada ZIP extra, sin reescribir hojas ni inventar meses.
    $igual=Join-Path $Salida '02_sin_cambios.xlsx'; Copy-Item -LiteralPath $cambios -Destination $igual
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::Open($igual,[IO.Compression.ZipArchiveMode]::Update)
    try { $entry=$zip.CreateEntry('planbot_e2e.txt'); $w=New-Object IO.StreamWriter($entry.Open()); try {$w.Write('Misma dotacion; prueba NULL')} finally {$w.Dispose()} } finally {$zip.Dispose()}
    $sin=Simular-E2e $igual 'sin_cambios'
    # Restauracion a una NUEVA base del mismo cluster privado: no DROP ni limpieza ajena.
    & (Join-Path $PgBin 'createdb.exe') -w -h 127.0.0.1 -p $puerto -U integracion_admin -O owner_planbot planbot_errores
    if ($LASTEXITCODE -ne 0) { throw 'No se creo destino de restauracion' }
    & (Join-Path $PgBin 'pg_restore.exe') -w -h 127.0.0.1 -p $puerto -U owner_planbot -d planbot_errores --exit-on-error (Join-Path $Salida '01.dump') *> (Join-Path $Salida 'restaurar.log')
    if ($LASTEXITCODE -ne 0) { throw 'Restauracion de 01 fallo' }
    $r03=Simular-E2e (Join-Path $raizE2e 'data\buk\03_errores.xlsx') '03' 'planbot_errores'
    $conexion.Base='planbot_errores'
    $null=Consultar-E2e ("SELECT coalesce(json_agg(e),'[]'::json) FROM stg.error_fila e WHERE carga_id="+[long]$r03.carga_id+';') 'errores.json'
    & python (Join-Path $raizE2e 'tools\vm\comparar_e2e.py') $Salida (Join-Path $raizE2e 'data\buk')
    $codigoE2e=$LASTEXITCODE
    $conexion.Base='planbot'
} catch { Write-Host ('FALLA: infraestructura/ejecucion: '+$_.Exception.Message) -ForegroundColor Red; $codigoE2e=1 }
finally {
    if ($iniciado -or (Test-Path -LiteralPath (Join-Path $datos 'postmaster.pid'))) { try { Controlar-E2e 'stop' } catch { Write-Host ('FALLA: '+$_.Exception.Message); $codigoE2e=1 } }
    foreach($k in $previos.Keys) { [Environment]::SetEnvironmentVariable($k,$previos[$k],'Process') }
    [IO.File]::WriteAllText((Join-Path $Salida 'ejecucion.json'),(@{sha=$sha;puerto=$puerto;codigo=$codigoE2e;cluster_detenido=(-not (Test-Path -LiteralPath (Join-Path $datos 'postmaster.pid')))} | ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
    Write-Host "Evidencia e2e: $Salida"
}
exit $codigoE2e
