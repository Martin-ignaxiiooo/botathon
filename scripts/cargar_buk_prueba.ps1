# SOLO PRUEBAS: carga una base BUK (.xlsx) a stg.buk_fila con una carga tipo 'buk' y llama cargar_dotacion.
# En el sistema final esto lo hace el robot de Blue Prism (P01/P02).
# Uso: .\scripts\cargar_buk_prueba.ps1 [-Archivo "data\excel\Nac - Base contratos x mes.xlsx"] [-Forzar] [-SinDotacion]
#   -Forzar      vuelve a cargar aunque ya exista una carga con el mismo hash (le agrega sufijo al hash)
#   -SinDotacion solo deja las filas en stg.buk_fila (no llama cargar_dotacion)
param(
    [string] $Archivo = 'data\excel\Nac - Base contratos x mes.xlsx',
    [switch] $Forzar,
    [switch] $SinDotacion,
    [ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto'
)
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
$xlsx = if ([IO.Path]::IsPathRooted($Archivo)) { $Archivo } else { Join-Path $Raiz (Ruta-Sistema $Archivo) }
if (-not (Test-Path $xlsx)) { throw "No existe $xlsx" }

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $xlsx).Hash.ToLower()
if ($Forzar) { $hash = "$hash-" + (Get-Date -Format 'yyyyMMddHHmmss') }
$nombre = Split-Path $xlsx -Leaf

$dirTmp = Join-Path $Raiz 'logs'
New-Item -ItemType Directory -Force -Path $dirTmp | Out-Null
$csv = Join-Path $dirTmp 'buk_prueba.csv'
$sql = Join-Path $dirTmp 'buk_prueba.sql'

Write-Host "1/3 Excel -> CSV ($nombre)"
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw 'No encuentro python en el PATH' }
& $py.Source (Join-Path $PSScriptRoot 'buk_a_csv.py') $xlsx $csv
if ($LASTEXITCODE -ne 0) { throw 'Falló buk_a_csv.py (¿falta openpyxl? pip install --user openpyxl)' }

# En Docker el CSV se lee desde /planbot/logs (montado en docker-compose.yml)
$rutaCsv = if ($modo -eq 'docker') { 'logs/buk_prueba.csv' } else { $csv -replace '\\', '/' }
$llamar = if ($SinDotacion) { "\echo 'Carga' :carga 'sin cargar_dotacion'" } else { 'SELECT * FROM api.cargar_dotacion(:carga);' }
$nombreSql = $nombre -replace "'", "''"

@"
SELECT EXISTS (SELECT 1 FROM stg.carga WHERE hash = '$hash') AS ya_cargada \gset
\if :ya_cargada
\echo 'Ya existe una carga con este hash; usa -Forzar para cargar de nuevo.'
\else
BEGIN;
INSERT INTO stg.carga (tipo, archivo, hash, estado) VALUES ('buk', '$nombreSql', '$hash', 'recibida')
RETURNING carga_id AS carga \gset
CREATE TEMP TABLE t_buk (it int, instituto text, persona_id bigint, area text, sub_area text, centro_costo text,
    periodo date, tipo_contrato text, tipo_trabajador text, fecha_ingreso date, fecha_termino date,
    horas_semanales numeric, cargo text, dias_jornada text, ndias int, cod_esp text) ON COMMIT DROP;
\copy t_buk FROM '$rutaCsv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato,
    tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp)
SELECT :carga, * FROM t_buk;
UPDATE stg.carga SET leidas = (SELECT count(*) FROM t_buk), estado = 'validada' WHERE carga_id = :carga;
\echo 'Carga buk' :carga
$llamar
COMMIT;
\endif
"@ | ForEach-Object { [IO.File]::WriteAllText($sql, $_, (New-Object System.Text.UTF8Encoding($false))) }  # psql no acepta BOM

Write-Host '2/3 CSV -> stg.buk_fila'
Write-Host '3/3 cargar_dotacion'
$codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'logs\buk_prueba.sql'
if ($codigo -ne 0) { Write-Host 'ERROR cargando la base BUK' -ForegroundColor Red; exit 1 }
Write-Host 'OK' -ForegroundColor Green
