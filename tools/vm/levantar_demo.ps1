#requires -Version 5.1
param(
    [string]$RaizRepo=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$DirectorioPlanBot='C:\PlanBot',
    [string]$DirectorioHerramientas='C:\tools',
    [ValidateRange(1,65535)][int]$PuertoApi=3000,
    [ValidateRange(1,65535)][int]$PuertoWeb=8080,
    [switch]$CargarBukPrueba
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')
$RaizRepo=(Resolve-Path -LiteralPath $RaizRepo).Path
$instalar=Join-Path $RaizRepo 'scripts\instalar_sin_docker.ps1'
$servir=Join-Path $RaizRepo 'scripts\servir_web.ps1'
if (-not (Test-Path -LiteralPath $servir -PathType Leaf)) { throw 'Falta scripts\servir_web.ps1: usar -RaizRepo con el repositorio integrado del equipo.' }
$antesEntorno=@{}
function Importar-PlanBotEnv {
    $ruta=Join-Path $RaizRepo '.env'
    if (-not (Test-Path -LiteralPath $ruta)) { return }
    foreach ($linea in Get-Content -LiteralPath $ruta -Encoding UTF8) {
        if ($linea -match '^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$') {
            $k=$Matches[1]; $v=$Matches[2].Trim()
            if ($k -notmatch '^(POSTGRES_|BOT_CARGA_PASSWORD$|WEB_LECTURA_PASSWORD$|PGRST_JWT_SECRET$|PG_|PGHOST$|PGPORT$)') { continue }
            if ($k -eq 'PG_SUPER_PASSWORD' -and (-not $v -or $v -like 'cambiar*') -and (Get-PlanBotVariable $k)) { continue }
            if (-not $antesEntorno.ContainsKey($k)) { $antesEntorno[$k]=[Environment]::GetEnvironmentVariable($k,'Process') }
            [Environment]::SetEnvironmentVariable($k,$v,'Process')
        }
    }
}
try {
    Importar-PlanBotEnv
    $psql=Get-PlanBotPsql
    if (-not (Test-Path -LiteralPath $instalar -PathType Leaf)) { throw 'Falta el instalador de Andres en scripts\instalar_sin_docker.ps1.' }
    $opciones=@{SinPruebas=$true;Puerto=[int](Get-PlanBotVariable 'PG_PORT' (Get-PlanBotVariable 'PGPORT' '5432'))}
    if (Get-PlanBotVariable 'PG_SUPER_PASSWORD') { $opciones.SuperClave=Get-PlanBotVariable 'PG_SUPER_PASSWORD' }
    if (Get-PlanBotVariable 'PG_SUPER_USER') { $opciones.SuperUsuario=Get-PlanBotVariable 'PG_SUPER_USER' }
    if (Get-PlanBotVariable 'PG_BIN') { $opciones.PgBin=Get-PlanBotVariable 'PG_BIN' }
    if ($CargarBukPrueba) { $opciones.CargarBukPrueba=$true }
    # Siempre migrar/sembrar tras pull. En proceso: ningun secreto aparece en argv.
    $global:LASTEXITCODE=0
    & $instalar @opciones
    if ($LASTEXITCODE -ne 0) { throw 'Instalador de Andres fallo; revisar salida antes de arrancar servicios.' }
    Importar-PlanBotEnv
    $base=Get-PlanBotVariable 'POSTGRES_DB' 'planbot'
    $secretoJwt=Get-PlanBotVariable 'PGRST_JWT_SECRET'
    if ($secretoJwt.Length -lt 32 -or $secretoJwt -like 'cambiar*') { throw 'El instalador no dejo un secreto JWT valido; no se publica PostgREST.' }
    foreach ($rel in @('entrada\planificacion','entrada\buk','entrada\asignaciones','procesados','errores','logs','respaldo','preparar','runtime')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $DirectorioPlanBot $rel) | Out-Null
    }
    $runtime=Join-Path $DirectorioPlanBot 'runtime'
    $estado=Join-Path $runtime 'demo-procesos.json'
    $procesos=@()
    if (Test-Path -LiteralPath $estado) {
        $guardados=Get-Content -LiteralPath $estado -Raw | ConvertFrom-Json
        foreach ($p in $guardados) {
            if ($p -and (Test-PlanBotIdentidadProceso $p)) { $procesos+= $p }
        }
    }
    # Recargar esquema/JWT despues de migrar, pero solo reiniciar procesos propios.
    foreach($r in @($procesos | Where-Object Tipo -eq 'PostgREST')) {
        $propio=Test-PlanBotIdentidadProceso $r
        if ($propio) { Stop-Process -Id $propio.Id -ErrorAction Stop; $propio.WaitForExit(5000) | Out-Null }
    }
    $procesos=@($procesos | Where-Object Tipo -ne 'PostgREST')
    Save-PlanBotProcesos $estado $procesos
    $versionFijada=Get-Content (Join-Path $PSScriptRoot 'postgrest-version.json') -Raw | ConvertFrom-Json
    $exe=Join-Path $DirectorioHerramientas 'postgrest.exe'
    $binarioPc=Join-Path $DirectorioHerramientas 'postgrest\artifacts\postgrest-windows-x64\postgrest.exe'
    if (-not (Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $binarioPc)) { $exe=$binarioPc }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path $DirectorioHerramientas | Out-Null
        $tlsAnterior=[Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
            $release=Invoke-RestMethod ("https://api.github.com/repos/PostgREST/postgrest/releases/tags/"+$versionFijada.tag) -Headers @{'User-Agent'='PlanBot-VM'} -TimeoutSec 20
            $archivo=@($release.assets | Where-Object name -EQ $versionFijada.asset)
            if ($archivo.Count -ne 1 -or $archivo[0].browser_download_url -ne $versionFijada.url) { throw 'Release oficial sin un ZIP Windows x64 inequívoco.' }
            $descarga=Join-Path $DirectorioHerramientas ('postgrest_'+[Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $descarga | Out-Null
            $zip=Join-Path $descarga 'postgrest.zip'
            Invoke-WebRequest $archivo[0].browser_download_url -OutFile $zip -UseBasicParsing -TimeoutSec 120
            if ($archivo[0].digest -match '^sha256:(.+)$') {
                if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $Matches[1]) { throw 'SHA-256 de descarga no coincide con el release oficial.' }
            }
            Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $descarga 'extraido')
            $binarios=@(Get-ChildItem (Join-Path $descarga 'extraido') -Recurse -Filter postgrest.exe -File)
            if ($binarios.Count -ne 1) { throw 'ZIP sin un unico postgrest.exe.' }
            Copy-Item -LiteralPath $binarios[0].FullName -Destination $exe
        } finally { [Net.ServicePointManager]::SecurityProtocol=$tlsAnterior }
    }
    $pathVersion=$env:PATH
    try {
        $env:PATH=(Split-Path -Parent $psql)+';'+$env:PATH
        $versionOut=Join-Path $runtime 'postgrest-version.txt'; $versionErr=Join-Path $runtime 'postgrest-version.err'
        $v=Start-Process -FilePath $exe -ArgumentList '--version' -WindowStyle Hidden -PassThru -RedirectStandardOutput $versionOut -RedirectStandardError $versionErr
        $handleVersion=$v.Handle
        if (-not $v.WaitForExit(10000)) { Stop-Process -Id $v.Id; throw 'Timeout comprobando version de PostgREST.' }
        $versionReal=Get-Content -LiteralPath $versionOut -Raw
        if ($v.ExitCode -ne 0 -or $versionReal -notmatch ('PostgREST\s+'+[regex]::Escape($versionFijada.version)+'(?:\s|$)')) { throw 'El binario no coincide con tools\vm\postgrest-version.json; usar una carpeta con la version fijada.' }
    } finally { $env:PATH=$pathVersion }
    if (-not (Get-PlanBotProcesoPuerto $PuertoApi)) {
        $plantilla=Join-Path $RaizRepo 'api\postgrest.conf'
        if (-not (Test-Path -LiteralPath $plantilla)) {
            $plantilla=Join-Path $PSScriptRoot 'postgrest.conf.example'
            Write-Host 'Falta plantilla api\postgrest.conf: usando respaldo de tools\vm (sin editar api\).'
        }
        # Conserva la plantilla salvo URI/JWT y ajustes que se fijan para esta VM.
        # Nunca copia credenciales de una plantilla local al nuevo archivo.
        $contenido=@(Get-Content -LiteralPath $plantilla | Where-Object {
            $_ -notmatch '(?i)postgres(ql)?://' -and
            $_ -notmatch '^\s*(db-uri|db-schemas|db-anon-role|db-config|server-host|server-port|server-cors-allowed-origins)\s*=' -and
            ($_ -notmatch '^\s*jwt-secret\s*=' -or $_ -match '\$\(PGRST_JWT_SECRET\)')
        })
        $config=Join-Path $runtime 'postgrest.conf'
        if (-not ($contenido -match '^\s*jwt-secret\s*=')) { $contenido+= 'jwt-secret = "$(PGRST_JWT_SECRET)"' }
        $lineasConfig=@($contenido)+@('db-uri = "$(PGRST_DB_URI)"','db-schemas = "api"','db-anon-role = "web_lectura"','db-config = false',
            'server-host = "127.0.0.1"',('server-port = '+$PuertoApi),('server-cors-allowed-origins = "http://localhost:'+$PuertoWeb+'"'))
        [IO.File]::WriteAllLines($config,[string[]]$lineasConfig,(New-Object Text.UTF8Encoding($false)))
        $claveWeb=Get-PlanBotVariable 'WEB_LECTURA_PASSWORD'
        if (-not $claveWeb -or $claveWeb -eq 'cambiar') { throw 'Falta WEB_LECTURA_PASSWORD en entorno/.env.' }
        $servidor=Get-PlanBotVariable 'PG_HOST' (Get-PlanBotVariable 'PGHOST' 'localhost')
        $puerto=Get-PlanBotVariable 'PG_PORT' (Get-PlanBotVariable 'PGPORT' '5432')
        $uri='postgresql://web_lectura:'+ [uri]::EscapeDataString($claveWeb)+'@'+$servidor+':'+$puerto+'/'+[uri]::EscapeDataString($base)
        $previoPgrst=@{}
        $pathAnterior=$env:PATH
        try {
            # Ajustes controlados, sin borrar JWT ni el resto de PGRST_* del llamador.
            $valoresPgrst=@{PGRST_DB_URI=$uri;PGRST_JWT_SECRET=$secretoJwt;PGRST_JWT_SECRET_IS_BASE64='false';PGRST_JWT_ROLE_CLAIM_KEY='.role';PGRST_DB_SCHEMAS='api';PGRST_DB_ANON_ROLE='web_lectura';PGRST_DB_CONFIG='false';PGRST_SERVER_HOST='127.0.0.1';PGRST_SERVER_PORT=[string]$PuertoApi;PGRST_SERVER_CORS_ALLOWED_ORIGINS="http://localhost:$PuertoWeb"}
            foreach($k in $valoresPgrst.Keys) { $previoPgrst[$k]=[Environment]::GetEnvironmentVariable($k,'Process'); [Environment]::SetEnvironmentVariable($k,$valoresPgrst[$k],'Process') }
            # El ZIP Windows requiere libpq.dll y dependencias de PostgreSQL.
            $env:PATH=(Split-Path -Parent $psql)+';'+$env:PATH
            $p=Start-Process -FilePath $exe -ArgumentList ('"'+$config+'"') -WindowStyle Hidden -PassThru -WorkingDirectory $runtime -RedirectStandardOutput (Join-Path $runtime 'postgrest.out.log') -RedirectStandardError (Join-Path $runtime 'postgrest.err.log')
            $procesos+=New-PlanBotRegistroProceso $p 'PostgREST'
            Save-PlanBotProcesos $estado $procesos
        } finally {
            $env:PATH=$pathAnterior
            foreach ($k in $previoPgrst.Keys) { [Environment]::SetEnvironmentVariable($k,$previoPgrst[$k],'Process') }
        }
    } else { Write-Host "Puerto $PuertoApi ocupado: se verificara el servicio existente; no se adopta ni reinicia." }
    if (-not (Get-PlanBotProcesoPuerto $PuertoWeb)) {
        $hostPs=Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $hostPs)) { $hostPs=(Get-Command pwsh.exe).Source }
        $lanzador=Start-Process -FilePath $hostPs -ArgumentList @('-NoProfile','-File',('"'+$servir+'"'),'-Puerto',([string]$PuertoWeb)) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'web.out.log') -RedirectStandardError (Join-Path $runtime 'web.err.log')
        $web=$null
        for ($i=0;$i -lt 25;$i++) {
            Start-Sleep -Milliseconds 200
            $candidato=Get-PlanBotProcesoPuerto $PuertoWeb
            if ($candidato) {
                $datos=Get-CimInstance Win32_Process -Filter ("ProcessId="+$candidato.Id)
                if ($datos.ParentProcessId -eq $lanzador.Id -and $datos.CommandLine -match ('http\.server\s+'+$PuertoWeb+'(?:\s|$)')) { $web=$candidato; break }
                throw "Otro proceso ocupo $PuertoWeb durante el arranque; no se adopta."
            }
        }
        if (-not $web) { throw 'servir_web.ps1 no inicio el servidor; revisar runtime\web.err.log.' }
        $procesos+=New-PlanBotRegistroProceso $web 'Web'
        Save-PlanBotProcesos $estado $procesos
    } else { Write-Host "Puerto $PuertoWeb ocupado: se verificara el servicio existente; no se adopta ni reinicia." }
    for ($i=0;$i -lt 20;$i++) {
        if (Test-PlanBotPuerto 'localhost' $PuertoApi) { break }
        Start-Sleep -Milliseconds 250
    }
    Write-Host "Abrir http://localhost:$PuertoWeb/?modo=api#nacional y confirmar la marca En vivo."
    & (Join-Path $PSScriptRoot 'verificar_vm.ps1') -RaizRepo $RaizRepo -DirectorioPlanBot $DirectorioPlanBot -PuertoApi $PuertoApi -PuertoWeb $PuertoWeb
    $codigoVerificacion=$LASTEXITCODE
} finally {
    foreach ($k in $antesEntorno.Keys) { [Environment]::SetEnvironmentVariable($k,$antesEntorno[$k],'Process') }
}
exit $codigoVerificacion
