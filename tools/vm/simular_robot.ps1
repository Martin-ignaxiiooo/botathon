#requires -Version 5.1
# Contingencia; Blue Prism sigue siendo el camino principal. No mueve el Excel.
param(
    [string]$Archivo,
    [string]$Servidor='localhost', [int]$Puerto=5432, [string]$Base='planbot',
    [string]$Usuario='bot_carga', [string]$VariableClave='BOT_CARGA_PASSWORD',
    [string]$UsuarioCatalogos='owner_planbot', [string]$VariableClaveCatalogos='POSTGRES_PASSWORD',
    [string]$Catalogos, [string]$EnvArchivo, [string]$PgBin='C:\Program Files\PostgreSQL\16\bin',
    [string]$Salida=(Join-Path $env:TEMP ('PlanBot_Sim_'+[Guid]::NewGuid().ToString('N')))
)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($Archivo)) { throw 'Falta -Archivo (no se solicita entrada interactiva).' }
. (Join-Path $PSScriptRoot 'psql_robot.ps1')
$raizRobot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Archivo=(Resolve-Path -LiteralPath $Archivo).Path
$psql=Join-Path $PgBin 'psql.exe'
$csc='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
foreach($f in @($psql,$csc)) { if (-not (Test-Path -LiteralPath $f)) { throw "Falta dependencia: $f" } }
$python=(Get-Command python -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$Salida=(Resolve-Path -LiteralPath $Salida).Path
if (Get-ChildItem -LiteralPath $Salida -Force) { throw 'Salida debe ser una carpeta nueva/vacia para no mezclar lotes.' }
$conexion=@{Psql=$psql;Servidor=$Servidor;Puerto=$Puerto;Base=$Base;Usuario=$Usuario;VariableClave=$VariableClave}
function Obtener-HashRobot([string]$Ruta) {
    # Mismo SHA-256/lectura compartida que el BO; no depende de la carga
    # automática de Get-FileHash en ámbitos anidados de Windows PowerShell.
    $flujo=[IO.File]::Open($Ruta,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($flujo)).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose(); $flujo.Dispose() }
}
$resumen=[ordered]@{archivo=[IO.Path]::GetFileName($Archivo);sha256=(Obtener-HashRobot $Archivo);carga_id=0;duplicado=$false;estado='iniciando';artefactos=$Salida}
$resumen.fuentes_cs=@{}
foreach($nombre in @('PlanBot_Limpieza.cs','PlanBot_Validador.cs','PlanBot_PostgreSQL.cs')) {
    $resumen.fuentes_cs[$nombre]=Obtener-HashRobot (Join-Path $raizRobot ('bluePrism\codigo\'+$nombre))
}
$sqlRuta=Join-Path $Salida 'paso.sql'
$antesClaves=@{}
try {
    if ($EnvArchivo) {
        foreach($linea in Get-Content -LiteralPath $EnvArchivo -Encoding UTF8) {
            if($linea -match '^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$') {
                $k=$Matches[1];$v=$Matches[2].Trim()
                if($k -in @($VariableClave,$VariableClaveCatalogos)) {
                    if(-not $antesClaves.ContainsKey($k)) { $antesClaves[$k]=[Environment]::GetEnvironmentVariable($k,'Process') }
                    [Environment]::SetEnvironmentVariable($k,$v,'Process')
                }
            }
        }
    }
    if (-not $Catalogos) {
        $Catalogos=Join-Path $Salida 'catalogos.json'
        $consulta=Write-RobotSql $sqlRuta @'
BEGIN READ ONLY;
SELECT json_build_object('institutos',(SELECT json_agg(json_build_object('it',it)) FROM param.instituto),
 'cargos',(SELECT json_agg(json_build_object('cargo_origen',cargo_origen)) FROM param.cargo_homologado));
COMMIT;
'@
        $c=@{}+$conexion; $c.Usuario=$UsuarioCatalogos; $c.VariableClave=$VariableClaveCatalogos
        $json=Invoke-RobotPsql @c -ArchivoSql $consulta
        [IO.File]::WriteAllText($Catalogos,$json,(New-Object Text.UTF8Encoding($false)))
    }
    $consulta=Write-RobotSql $sqlRuta @'
INSERT INTO stg.carga(tipo,archivo,hash,estado) VALUES('buk',:'archivo',:'hash','recibida')
ON CONFLICT(hash) DO NOTHING RETURNING carga_id;
'@
    $id=Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{archivo=[IO.Path]::GetFileName($Archivo);hash=$resumen.sha256}
    if (-not $id) {
        $consulta=Write-RobotSql $sqlRuta "SELECT carga_id FROM stg.carga WHERE hash=:'hash';"
        $id=Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{hash=$resumen.sha256}
        $resumen.carga_id=[long]$id; $resumen.duplicado=$true; $resumen.estado='archivo repetido'
    } else {
        $resumen.carga_id=[long]$id
        $entrada=Join-Path $Salida 'entrada.xml'
        & $python (Join-Path $PSScriptRoot 'preparar_buk.py') $Archivo $Catalogos $entrada
        if ($LASTEXITCODE -ne 0) { throw 'Fallo lector Excel; consultar stderr, sin continuar la carga.' }
        $puente=Join-Path $Salida 'PrepararBuk.exe'
        & $csc /nologo /noconfig /langversion:5 /warnaserror /r:System.dll /r:System.Data.dll /r:System.Xml.dll "/out:$puente" (Join-Path $PSScriptRoot 'PrepararBuk.cs') (Join-Path $raizRobot 'bluePrism\codigo\PlanBot_Limpieza.cs') (Join-Path $raizRobot 'bluePrism\codigo\PlanBot_Validador.cs') (Join-Path $raizRobot 'bluePrism\codigo\PlanBot_PostgreSQL.cs') | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'No compilan los Code stages originales; no sustituir su logica.' }
        & $puente $entrada ([string]$resumen.carga_id) $Salida
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron limpieza/validacion originales C#.' }
        $conteos=Import-Csv -LiteralPath (Join-Path $Salida 'conteos.csv') | Select-Object -First 1
        $resumen.conteos=$conteos
        foreach($tipo in @('errores','buk')) {
            if ($tipo -eq 'buk' -and [int]$conteos.validas -eq 0) { throw 'Sin filas validas: no reemplazar la foto completa de dotacion.' }
            $tabla='stg.error_fila'; $columnas='carga_id,fila,persona_id,campo,valor,motivo'
            if ($tipo -eq 'buk') { $tabla='stg.buk_fila'; $columnas='carga_id,it,instituto,persona_id,area,sub_area,centro_costo,periodo,tipo_contrato,tipo_trabajador,fecha_ingreso,fecha_termino,horas_semanales,cargo,dias_jornada,ndias,cod_esp' }
            foreach($lote in Get-ChildItem -LiteralPath $Salida -Filter ($tipo+'_????.csv') | Sort-Object Name) {
                $rutaCsv=$lote.FullName.Replace('\','/').Replace("'","''")
                $consulta=Write-RobotSql $sqlRuta ("BEGIN;`n\copy $tabla ($columnas) FROM '$rutaCsv' WITH (FORMAT csv,HEADER true,NULL '\N')`nCOMMIT;")
                $null=Invoke-RobotPsql @conexion -ArchivoSql $consulta
            }
        }
        $consulta=Write-RobotSql $sqlRuta "SELECT row_to_json(r) FROM api.cargar_dotacion(CAST(:'carga' AS bigint)) r;"
        $resumen.core=(Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id}) | ConvertFrom-Json
        $consulta=Write-RobotSql $sqlRuta "SELECT count(*) FROM stg.error_fila WHERE carga_id=CAST(:'carga' AS bigint);"
        $mensajes=Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id}
        if ([int]$mensajes -ne [int]$conteos.mensajes) { throw 'La BD agrego/eliminó rechazos: conciliar; no adivinar filas originales ni recalcular.' }
        $consulta=Write-RobotSql $sqlRuta "SELECT coalesce(json_agg(r),'[]'::json) FROM api.detectar_cambios(CAST(:'carga' AS bigint)) r;"
        $cambiosJson=(Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id}) | ConvertFrom-Json
        $resumen.cambios=@($cambiosJson | ForEach-Object {$_})
        $consulta=Write-RobotSql $sqlRuta "SELECT json_build_object('mes',api.mes_minimo_afectado(CAST(:'carga' AS bigint)));"
        $corte=(Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id}) | ConvertFrom-Json
        $resumen.mes_minimo=$corte.mes
        if ($null -ne $corte.mes) {
            $consulta=Write-RobotSql $sqlRuta @'
WITH contexto AS MATERIALIZED (SELECT set_config('planbot.motivo',
 'Simulador contingencia; carga='||CAST(CAST(:'carga' AS bigint) AS text),true) AS motivo)
SELECT row_to_json(r) FROM contexto c CROSS JOIN LATERAL api.recalcular(
 CASE WHEN c.motivo IS NOT NULL THEN CAST(:'mes' AS integer) END) r;
'@
            $resumen.recalculo=(Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id;mes=$corte.mes}) | ConvertFrom-Json
        }
        # El back es dueño del cierre y sus contadores. El robot solo los lee;
        # una discrepancia exige conciliación, nunca sobrescribirla con BP.
        $consulta=Write-RobotSql $sqlRuta "SELECT row_to_json(c) FROM (SELECT leidas,validas,con_error,estado FROM stg.carga WHERE carga_id=CAST(:'carga' AS bigint)) c;"
        $resumen.cierre=Invoke-RobotPsql @conexion -ArchivoSql $consulta -Variables @{carga=$id} | ConvertFrom-Json
        foreach($campo in @('leidas','validas','con_error')) {
            if ([int]$resumen.cierre.$campo -ne [int]$conteos.$campo) { throw "Contador BD $campo difiere de BP: conciliar sin sobrescribirlo." }
        }
        if ($resumen.cierre.estado -ne 'cargada') { throw 'La BD no confirmo estado cargada; conciliar.' }
        $consulta=Write-RobotSql $sqlRuta 'SELECT api.cuadratura();'
        $resumen.cuadratura=Invoke-RobotPsql @conexion -ArchivoSql $consulta
        $resumen.estado='cargada'
    }
} catch {
    $resumen.estado='error'; $resumen.error=$_.Exception.Message
    if ($resumen.carga_id -gt 0 -and -not $resumen.duplicado) {
        try { $q=Write-RobotSql $sqlRuta "UPDATE stg.carga SET estado='error' WHERE carga_id=CAST(:'carga' AS bigint);"; $null=Invoke-RobotPsql @conexion -ArchivoSql $q -Variables @{carga=$resumen.carga_id} }
        catch { $resumen.error_cierre='No se pudo marcar estado error; conciliar por hash.' }
    }
    throw
} finally {
    foreach($k in $antesClaves.Keys) { [Environment]::SetEnvironmentVariable($k,$antesClaves[$k],'Process') }
    [IO.File]::WriteAllText((Join-Path $Salida 'resumen.json'),($resumen | ConvertTo-Json -Depth 9),(New-Object Text.UTF8Encoding($false)))
    Write-Host ("Simulador: {0}; carga {1}; evidencia {2}" -f $resumen.estado,$resumen.carga_id,$Salida)
}
[pscustomobject]$resumen
