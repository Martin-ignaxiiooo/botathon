# Funciones comunes de los scripts de PlanBot. Uso: . "$PSScriptRoot\_comun.ps1"
# Modo 'docker' = psql dentro del contenedor postgres; 'nativo' = psql local (Windows, VM o CI).
# Compatible con PowerShell 5.1 y 7. Guardar en UTF-8 con BOM.
$ErrorActionPreference = 'Stop'
$Raiz = Split-Path -Parent $PSScriptRoot
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$PG_BIN_DEFECTO = 'C:\Program Files\PostgreSQL\16\bin'

function Primero([object[]] $valores) {
    foreach ($v in $valores) { if ($v) { return $v } }
    return $null
}

function Leer-Env {
    $ruta = Join-Path $Raiz '.env'
    if (-not (Test-Path $ruta)) {
        throw "Falta .env en $Raiz. Copia .env.example a .env y completa las claves."
    }
    $cfg = @{}
    foreach ($linea in Get-Content $ruta -Encoding utf8) {
        if ($linea -match '^\s*(#|$)' -or $linea -notmatch '=') { continue }
        $k, $v = $linea -split '=', 2
        $cfg[$k.Trim().TrimStart([char]0xFEFF)] = $v.Trim()
    }
    foreach ($k in 'POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'BOT_CARGA_PASSWORD', 'WEB_LECTURA_PASSWORD') {
        if (-not $cfg[$k]) { throw "Falta $k en .env" }
    }
    # Conexión: PG_HOST/PG_PORT/PG_BIN (aceptan también PGHOST/PGPORT y POSTGRES_HOST/POSTGRES_PORT del CI)
    $cfg['PG_HOST'] = Primero @($cfg['PG_HOST'], $cfg['PGHOST'], $cfg['POSTGRES_HOST'], 'localhost')
    $cfg['PG_PORT'] = Primero @($cfg['PG_PORT'], $cfg['PGPORT'], $cfg['POSTGRES_PORT'], '5432')
    $cfg['PG_BIN']  = Primero @($cfg['PG_BIN'], $PG_BIN_DEFECTO)
    return $cfg
}

function Resolver-Modo([string]$Modo) {
    if ($Modo -and $Modo -ne 'auto') { return $Modo }
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $id = & docker compose -f (Join-Path $Raiz 'docker-compose.yml') ps -q postgres 2>$null
        if ($LASTEXITCODE -eq 0 -and $id) { return 'docker' }
    }
    return 'nativo'
}

function Ruta-Psql($Cfg) {
    foreach ($nombre in 'psql.exe', 'psql') {
        $p = Join-Path $Cfg['PG_BIN'] $nombre
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command psql -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "No encuentro psql. Instala PostgreSQL 16 o define PG_BIN en .env."
}

# Ruta relativa a la raíz del repo -> separador del sistema (\ en Windows, / en Linux)
function Ruta-Sistema([string] $rel) {
    return ($rel -replace '[\\/]', [IO.Path]::DirectorySeparatorChar)
}

# Ejecuta psql con ON_ERROR_STOP. -Archivo es relativo a la raíz del repo. Devuelve el código de salida.
function Invocar-Psql {
    param(
        [Parameter(Mandatory)] $Cfg,
        [Parameter(Mandatory)] [string] $Modo,
        [string] $Archivo,
        [string] $Comando,
        [hashtable] $Vars = @{},
        [string] $Usuario,
        [string] $Clave,
        [string] $Base
    )
    if (-not $Usuario) { $Usuario = $Cfg['POSTGRES_USER']; $Clave = $Cfg['POSTGRES_PASSWORD'] }
    if (-not $Base) { $Base = $Cfg['POSTGRES_DB'] }

    $a = @('-X', '-q', '-v', 'ON_ERROR_STOP=1', '-P', 'pager=off', '-U', $Usuario, '-d', $Base)
    foreach ($k in $Vars.Keys) { $a += @('-v', "$k=$($Vars[$k])") }

    if ($Modo -eq 'docker') {
        if ($Archivo) { $a += @('-f', '/planbot/' + ($Archivo -replace '\\', '/')) }
        if ($Comando) { $a += @('-c', $Comando) }
        & docker compose -f (Join-Path $Raiz 'docker-compose.yml') exec -T postgres psql @a | Out-Host
        return $LASTEXITCODE
    }

    $psql = Ruta-Psql $Cfg
    $a += @('-h', $Cfg['PG_HOST'], '-p', $Cfg['PG_PORT'])
    if ($Archivo) { $a += @('-f', (Ruta-Sistema $Archivo)) }
    if ($Comando) { $a += @('-c', $Comando) }
    $env:PGPASSWORD = $Clave
    $env:PGCLIENTENCODING = 'UTF8'
    Push-Location $Raiz   # \copy usa rutas relativas a la raíz (data/csv/...)
    try {
        & $psql @a | Out-Host
        return $LASTEXITCODE
    } finally {
        Pop-Location
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}
