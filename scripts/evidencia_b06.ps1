# Evidencia reproducible de B-06: plan mensual, meta y semanas hábiles contra el Excel (stg.esperado).
# Requiere la base BUK real cargada (scripts\cargar_buk_prueba.ps1). Salida: database\evidencia\b06\
# Deja calc.plan_mes calculado con semanas del Excel. Uso: .\scripts\evidencia_b06.ps1
param([ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto')
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path (Join-Path $Raiz 'database') 'evidencia') 'b06') | Out-Null
$codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'database\evidencia\b06_export.sql'
if ($codigo -ne 0) { Write-Host 'ERROR exportando evidencia B-06' -ForegroundColor Red; exit 1 }
Write-Host 'OK · database\evidencia\b06\resumen.txt y diferencias_*.csv' -ForegroundColor Green
