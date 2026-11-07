# Evidencia reproducible de B-05: exporta el cálculo semanal (v0 y v1) y lo cruza con el Excel de planificación.
# Requiere la base BUK real cargada (scripts\cargar_buk_prueba.ps1) y openpyxl. Salida: database\evidencia\b05\
# Uso: .\scripts\evidencia_b05.ps1
param([ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto')
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
$dir = Join-Path (Join-Path (Join-Path $Raiz 'database') 'evidencia') 'b05'
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host '1/2 Exportando calc.v_semanal (v0 y v1) y stg.esperado'
$codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'database\evidencia\b05_export.sql'
if ($codigo -ne 0) { Write-Host 'ERROR exportando' -ForegroundColor Red; exit 1 }

Write-Host '2/2 Cruzando con el Excel'
$xlsx = Join-Path $Raiz (Ruta-Sistema 'data\excel\Nac - Planificacion Asistencial x mes.xlsx')
$param = Join-Path $Raiz (Ruta-Sistema 'data\csv\param_cargo.csv')
& python (Join-Path $PSScriptRoot 'evidencia_b05.py') $xlsx $param $dir
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR en evidencia_b05.py' -ForegroundColor Red; exit 1 }
