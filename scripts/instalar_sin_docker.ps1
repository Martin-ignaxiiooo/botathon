# Instala PlanBot en PostgreSQL 16 nativo (VM de la demo o PC sin Docker) con UN comando:
#   .\scripts\instalar_sin_docker.ps1 -SuperClave '<clave de postgres>' [-CargarBukPrueba]
# Hace, en orden (todo idempotente, se puede repetir):
#   0. Si no existe .env, lo crea desde .env.example con claves aleatorias para owner_planbot, bot_carga y
#      web_lectura (las claves quedan SOLO en .env, que no se versiona; no se muestran en pantalla).
#      PGRST_JWT_SECRET (PostgREST) se genera si falta, es el de ejemplo o tiene menos de 32 caracteres.
#   1. Crea el rol owner_planbot y la base planbot (UTF8, America/Santiago) con el superusuario.
#   2. Migraciones, funciones, vistas y semilla (roles bot_carga / web_lectura / planificador incluidos).
#   3. Opcional -CargarBukPrueba: carga la base BUK de data\excel (requiere python + openpyxl), calcula el plan,
#      la cuadratura y 3 escenarios de ejemplo (database\demo\escenarios_demo.sql).
#   4. Verifica con las pruebas de base de datos (.\scripts\test.ps1 -Modulo db).
# Requisitos: PostgreSQL 16 instalado con su servicio corriendo (PG_PORT, por defecto 5432).
# No requiere Docker, reinicio ni permisos de administrador (solo la clave del superusuario de PostgreSQL).
param(
    [string] $SuperClave,
    [string] $SuperUsuario,
    [string] $PgBin,
    [int]    $Puerto,
    [switch] $CargarBukPrueba,
    [switch] $SinPruebas
)
. "$PSScriptRoot\_comun.ps1"

function Clave-Aleatoria([int] $largo = 24) {
    $bytes = New-Object byte[] $largo
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    return -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Fijar-Env([string] $ruta, [string] $clave, [string] $valor) {
    $lineas = @([IO.File]::ReadAllLines($ruta))
    $hecho = $false
    for ($i = 0; $i -lt $lineas.Length; $i++) {
        if ($lineas[$i] -match ('^\s*' + [regex]::Escape($clave) + '\s*=')) { $lineas[$i] = "$clave=$valor"; $hecho = $true }
    }
    if (-not $hecho) { $lineas += "$clave=$valor" }
    [IO.File]::WriteAllLines($ruta, [string[]] $lineas, (New-Object System.Text.UTF8Encoding($false)))
}

# 0 · .env
$rutaEnv = Join-Path $Raiz '.env'
if (-not (Test-Path $rutaEnv)) {
    Write-Host '0/4 Creando .env desde .env.example con claves aleatorias'
    Copy-Item (Join-Path $Raiz '.env.example') $rutaEnv
    foreach ($k in 'POSTGRES_PASSWORD', 'BOT_CARGA_PASSWORD', 'WEB_LECTURA_PASSWORD') { Fijar-Env $rutaEnv $k (Clave-Aleatoria) }
    Fijar-Env $rutaEnv 'PGRST_JWT_SECRET' (Clave-Aleatoria 40)
} else {
    Write-Host '0/4 Usando el .env existente'
}
# Secreto JWT de PostgREST: 32 caracteres o más; si falta, es el de ejemplo o es corto, se genera uno nuevo
$secretoJwt = ''
foreach ($l in [IO.File]::ReadAllLines($rutaEnv)) { if ($l -match '^\s*PGRST_JWT_SECRET\s*=(.*)$') { $secretoJwt = $Matches[1].Trim() } }
if (-not $secretoJwt -or $secretoJwt -like 'cambiar*' -or $secretoJwt.Length -lt 32) {
    Write-Host '    PGRST_JWT_SECRET nuevo en .env (40 caracteres). Si PostgREST ya corría, reinícialo.'
    Fijar-Env $rutaEnv 'PGRST_JWT_SECRET' (Clave-Aleatoria 40)
}
if ($SuperClave)   { Fijar-Env $rutaEnv 'PG_SUPER_PASSWORD' $SuperClave }
if ($SuperUsuario) { Fijar-Env $rutaEnv 'PG_SUPER_USER' $SuperUsuario }
if ($PgBin)        { Fijar-Env $rutaEnv 'PG_BIN' $PgBin }
if ($Puerto)       { Fijar-Env $rutaEnv 'PG_PORT' $Puerto }

$cfg = Leer-Env
foreach ($k in 'POSTGRES_PASSWORD', 'BOT_CARGA_PASSWORD', 'WEB_LECTURA_PASSWORD') {
    if ($cfg[$k] -eq 'cambiar') { throw "$k sigue en 'cambiar' en .env: pon una clave real o borra .env para generarlas." }
}
$su = $cfg['PG_SUPER_USER']; if (-not $su) { $su = 'postgres' }
if (-not $cfg['PG_SUPER_PASSWORD'] -or $cfg['PG_SUPER_PASSWORD'] -eq 'cambiar') {
    throw "Falta la clave del superusuario: .\scripts\instalar_sin_docker.ps1 -SuperClave '<clave de $su>'"
}
Write-Host "    psql: $(Ruta-Psql $cfg) · servidor $($cfg['PG_HOST']):$($cfg['PG_PORT'])"

# 1 · rol dueño y base
Write-Host "1/4 Rol $($cfg['POSTGRES_USER']) y base $($cfg['POSTGRES_DB']) (si no existen)"
$codigo = Invocar-Psql -Cfg $cfg -Modo 'nativo' -Archivo 'database\instalar\crear_base.sql' `
    -Usuario $su -Clave $cfg['PG_SUPER_PASSWORD'] -Base 'postgres' `
    -Vars @{ owner = $cfg['POSTGRES_USER']; owner_pwd = $cfg['POSTGRES_PASSWORD']; db = $cfg['POSTGRES_DB'] }
if ($codigo -ne 0) {
    Write-Host "ERROR creando rol o base. ¿Corre el servicio de PostgreSQL en el puerto $($cfg['PG_PORT'])? ¿Es correcta la clave de $su?" -ForegroundColor Red
    exit 1
}

# 2 · esquema completo + semilla (también fija las claves de bot_carga y web_lectura desde .env)
Write-Host '2/4 Migraciones, funciones, vistas y semilla'
& (Join-Path $PSScriptRoot 'migrar.ps1') -Modo nativo
if ($LASTEXITCODE -ne 0) { exit 1 }

# 3 · datos BUK de prueba (opcional) + plan
if ($CargarBukPrueba) {
    Write-Host '3/4 Base BUK de prueba, plan mensual, cuadratura y escenarios de ejemplo'
    & (Join-Path $PSScriptRoot 'cargar_buk_prueba.ps1') -Modo nativo
    if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR cargando la base BUK de prueba' -ForegroundColor Red; exit 1 }
    $codigo = Invocar-Psql -Cfg $cfg -Modo 'nativo' -Comando "SELECT set_config('planbot.motivo', 'instalacion', false); SELECT * FROM api.recalcular(1); SELECT api.cuadratura() AS pct_coincidencia;"
    if ($codigo -ne 0) { Write-Host 'ERROR en recalcular(1)' -ForegroundColor Red; exit 1 }
    $codigo = Invocar-Psql -Cfg $cfg -Modo 'nativo' -Archivo 'database\demo\escenarios_demo.sql'
    if ($codigo -ne 0) { Write-Host 'ERROR cargando los escenarios de ejemplo' -ForegroundColor Red; exit 1 }
} else {
    Write-Host '3/4 Sin datos BUK (los carga Blue Prism; para la demo agregar -CargarBukPrueba)'
}

# 4 · verificación
if (-not $SinPruebas) {
    Write-Host '4/4 Pruebas de base de datos'
    & (Join-Path $PSScriptRoot 'test.ps1') -Modulo db -Modo nativo
    if ($LASTEXITCODE -ne 0) { Write-Host 'Instalada, pero hay pruebas en rojo' -ForegroundColor Red; exit 1 }
}
Write-Host ''
Write-Host "Instalación lista: base $($cfg['POSTGRES_DB']) en $($cfg['PG_HOST']):$($cfg['PG_PORT'])." -ForegroundColor Green
Write-Host '  Blue Prism se conecta como bot_carga (clave BOT_CARGA_PASSWORD en .env); PostgREST como web_lectura.'
Write-Host '  PostgREST: api\postgrest.conf con PGRST_DB_URI y PGRST_JWT_SECRET de .env en el entorno.'
Write-Host '  Token para aprobar/rechazar escenarios (24 h): .\scripts\token_planificador.ps1'
