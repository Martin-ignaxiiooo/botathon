# Instala PlanBot en PostgreSQL 16 nativo (PC sin Docker o VM de la Botathon).
# Requisitos: PostgreSQL 16 instalado y .env completo (PG_SUPER_USER / PG_SUPER_PASSWORD = superusuario).
# Uso: .\scripts\instalar_sin_docker.ps1 [-PgBin "C:\Program Files\PostgreSQL\16\bin"]
param([string] $PgBin)
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
if ($PgBin) { $cfg['PG_BIN'] = $PgBin }
$su = $cfg['PG_SUPER_USER']; if (-not $su) { $su = 'postgres' }
if (-not $cfg['PG_SUPER_PASSWORD']) { throw 'Falta PG_SUPER_PASSWORD en .env (clave del superusuario postgres).' }

Write-Host "psql: $(Ruta-Psql $cfg)"
Write-Host "1/2 Creando rol $($cfg['POSTGRES_USER']) y base $($cfg['POSTGRES_DB']) (si no existen)"
$codigo = Invocar-Psql -Cfg $cfg -Modo 'nativo' -Archivo 'database\instalar\crear_base.sql' `
    -Usuario $su -Clave $cfg['PG_SUPER_PASSWORD'] -Base 'postgres' `
    -Vars @{ owner = $cfg['POSTGRES_USER']; owner_pwd = $cfg['POSTGRES_PASSWORD']; db = $cfg['POSTGRES_DB'] }
if ($codigo -ne 0) { Write-Host 'ERROR creando rol o base' -ForegroundColor Red; exit 1 }

Write-Host '2/2 Migraciones, funciones, vistas y semilla'
& (Join-Path $PSScriptRoot 'migrar.ps1') -Modo nativo
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host 'Instalación lista. Probar con: .\scripts\test.ps1 -Modulo db -Modo nativo' -ForegroundColor Green
