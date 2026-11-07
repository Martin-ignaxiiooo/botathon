#requires -Version 5.1
param(
    [string]$RaizRepo=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$DirectorioPlanBot='C:\PlanBot',
    [string]$DirectorioHerramientas='C:\tools',
    [string]$PostgrestVersion='v16.5',
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
            if ($k -notmatch '^(POSTGRES_|BOT_CARGA_PASSWORD$|WEB_LECTURA_PASSWORD$|PG_|PGHOST$|PGPORT$)') { continue }
            if (-not $antesEntorno.ContainsKey($k)) { $antesEntorno[$k]=[Environment]::GetEnvironmentVariable($k,'Process') }
            [Environment]::SetEnvironmentVariable($k,$v,'Process')
        }
    }
}
try {
    Importar-PlanBotEnv
    $psql=Get-PlanBotPsql
    $base=Get-PlanBotVariable 'POSTGRES_DB' 'planbot'
    $administrador=Get-PlanBotVariable 'POSTGRES_USER' 'owner_planbot'
    $clave=Get-PlanBotVariable 'POSTGRES_PASSWORD'
    if (Get-PlanBotVariable 'PG_SUPER_PASSWORD') {
        $administrador=Get-PlanBotVariable 'PG_SUPER_USER' 'postgres'
        $clave=Get-PlanBotVariable 'PG_SUPER_PASSWORD'
    }
    $baseLiteral=$base.Replace("'","''")
    $r=Invoke-PlanBotLectura $psql $administrador $clave 'postgres' ("SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname='$baseLiteral');")
    if (-not $r.Ok) { throw 'No se pudo determinar si la base existe. Definir POSTGRES_PASSWORD o PG_SUPER_PASSWORD correctos; no se instala a ciegas.' }
    if ($r.Texto -eq 'f') {
        if (-not (Test-Path -LiteralPath $instalar -PathType Leaf)) { throw 'Falta el instalador de Andres en scripts\instalar_sin_docker.ps1.' }
        $superClave=Get-PlanBotVariable 'PG_SUPER_PASSWORD'
        if (-not $superClave) { throw 'Base ausente: definir PG_SUPER_PASSWORD antes de instalar.' }
        $opciones=@{ SuperClave=$superClave; SuperUsuario=(Get-PlanBotVariable 'PG_SUPER_USER' 'postgres');
            Puerto=[int](Get-PlanBotVariable 'PG_PORT' (Get-PlanBotVariable 'PGPORT' '5432')) }
        if (Get-PlanBotVariable 'PG_BIN') { $opciones.PgBin=Get-PlanBotVariable 'PG_BIN' }
        if ($CargarBukPrueba) { $opciones.CargarBukPrueba=$true }
        # En el mismo proceso: la clave no aparece en argumentos de consola.
        $global:LASTEXITCODE=0
        & $instalar @opciones
        if ($LASTEXITCODE -ne 0) { throw 'Instalador de Andres fallo; revisar su salida antes de arrancar servicios.' }
        Importar-PlanBotEnv # Puede haber generado claves aleatorias en .env.
    } elseif ($CargarBukPrueba) {
        Write-Host 'Base existente: no se recarga BUK ni se ejecutan migraciones. La carga inicial corresponde al robot/Andres.'
    }
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
    $exe=Join-Path $DirectorioHerramientas 'postgrest.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        if ($PostgrestVersion -notmatch '^v\d+\.\d+(\.\d+)?$') { throw 'Version PostgREST invalida (ejemplo v16.5).' }
        New-Item -ItemType Directory -Force -Path $DirectorioHerramientas | Out-Null
        $tlsAnterior=[Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
            $release=Invoke-RestMethod ("https://api.github.com/repos/PostgREST/postgrest/releases/tags/$PostgrestVersion") -Headers @{'User-Agent'='PlanBot-VM'} -TimeoutSec 20
            $archivo=@($release.assets | Where-Object name -Match 'windows.*(x86-64|x86_64).*\.zip$')
            if ($archivo.Count -ne 1 -or $archivo[0].browser_download_url -notlike 'https://github.com/PostgREST/postgrest/releases/download/*') { throw 'Release oficial sin un ZIP Windows x64 inequívoco.' }
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
    if (-not (Get-PlanBotProcesoPuerto $PuertoApi)) {
        $plantilla=Join-Path $RaizRepo 'api\postgrest.conf'
        if (-not (Test-Path -LiteralPath $plantilla)) {
            $plantilla=Join-Path $PSScriptRoot 'postgrest.conf.example'
            Write-Host 'Falta plantilla api\postgrest.conf: usando respaldo de tools\vm (sin editar api\).'
        }
        # Conserva la plantilla salvo URI/JWT y ajustes que se fijan para esta VM.
        # Nunca copia credenciales de una plantilla local al nuevo archivo.
        $contenido=@(Get-Content -LiteralPath $plantilla | Where-Object {
            $_ -notmatch '(?i)password|secret|postgres(ql)?://' -and
            $_ -notmatch '^\s*(db-uri|db-schemas|db-anon-role|db-config|server-host|server-port|server-cors-allowed-origins|jwt-[a-z-]+)\s*='
        })
        $config=Join-Path $runtime 'postgrest.conf'
        $lineasConfig=@($contenido)+@('db-schemas = "api"','db-anon-role = "web_lectura"','db-config = false',
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
            # Evitar que PGRST_* ajenos sobrescriban esquema, rol, puerto o JWT.
            foreach ($v in @(Get-ChildItem Env:PGRST_*)) { $previoPgrst[$v.Name]=$v.Value; Remove-Item ('Env:'+ $v.Name) }
            $env:PGRST_DB_URI=$uri
            # El ZIP Windows requiere libpq.dll y dependencias de PostgreSQL.
            $env:PATH=(Split-Path -Parent $psql)+';'+$env:PATH
            $p=Start-Process -FilePath $exe -ArgumentList ('"'+$config+'"') -WindowStyle Hidden -PassThru -WorkingDirectory $runtime -RedirectStandardOutput (Join-Path $runtime 'postgrest.out.log') -RedirectStandardError (Join-Path $runtime 'postgrest.err.log')
            $procesos+=New-PlanBotRegistroProceso $p 'PostgREST'
            Save-PlanBotProcesos $estado $procesos
        } finally {
            $env:PATH=$pathAnterior
            Remove-Item Env:PGRST_DB_URI -ErrorAction SilentlyContinue
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
    & (Join-Path $PSScriptRoot 'verificar_vm.ps1') -DirectorioPlanBot $DirectorioPlanBot -PuertoApi $PuertoApi -PuertoWeb $PuertoWeb
    $codigoVerificacion=$LASTEXITCODE
} finally {
    foreach ($k in $antesEntorno.Keys) { [Environment]::SetEnvironmentVariable($k,$antesEntorno[$k],'Process') }
}
exit $codigoVerificacion
