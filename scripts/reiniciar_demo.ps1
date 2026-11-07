# Deja la base en el estado "antes de la demo": solo la base BUK 01_original cargada, plan y cuadratura calculados
# y los 3 escenarios de ejemplo. Así Blue Prism carga 02_cambios en vivo y se ven los 5 cambios y el recálculo.
# Usar antes de cada ensayo y justo antes de presentar. Repetible, no interactivo; las claves salen de .env.
# Uso: .\scripts\reiniciar_demo.ps1 [-Archivo data\buk\01_original.xlsx] [-Modo auto|docker|nativo]
# Requiere python + openpyxl (como cargar_buk_prueba.ps1). No toca Blue Prism, PostgREST ni la web.
param(
    [string] $Archivo = 'data\buk\01_original.xlsx',
    [ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto'
)
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
$inicio = Get-Date

Write-Host '1/4 Limpieza: cargas BUK, dotación, plan, cuadratura, escenarios y parámetros de escenarios aplicados'
if ((Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'database\demo\reiniciar_demo.sql') -ne 0) {
    Write-Host 'ERROR en la limpieza (la base quedó como estaba)' -ForegroundColor Red; exit 1
}

Write-Host "2/4 Carga BUK inicial: $Archivo"
& (Join-Path $PSScriptRoot 'cargar_buk_prueba.ps1') -Archivo $Archivo -Forzar -Modo $modo
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR cargando la base BUK inicial' -ForegroundColor Red; exit 1 }

Write-Host '3/4 Plan mensual y cuadratura'
$codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Comando "SELECT set_config('planbot.motivo', 'reiniciar demo: carga inicial', false); SELECT * FROM api.recalcular(1);"
if ($codigo -ne 0) { Write-Host 'ERROR en recalcular(1)' -ForegroundColor Red; exit 1 }

Write-Host '4/4 Escenarios de ejemplo'
if ((Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'database\demo\escenarios_demo.sql') -ne 0) {
    Write-Host 'ERROR cargando los escenarios de ejemplo' -ForegroundColor Red; exit 1
}

$resumen = @"
SELECT (SELECT count(*) FROM stg.carga WHERE tipo = 'buk')            AS cargas_buk,
       (SELECT archivo FROM stg.carga WHERE tipo = 'buk')              AS archivo,
       (SELECT count(*) FROM calc.plan_mes)                            AS filas_plan,
       (SELECT atenciones_plan FROM api.v_kpi)                         AS atenciones,
       (SELECT meta FROM api.v_kpi)                                    AS meta,
       (SELECT count(*) FROM api.v_cuadratura)                         AS diferencias_cuadratura,
       (SELECT string_agg(estado, ', ' ORDER BY escenario_id) FROM calc.escenario) AS escenarios;
"@
Invocar-Psql -Cfg $cfg -Modo $modo -Comando $resumen | Out-Null
$seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)
Write-Host "Demo lista en $seg s: Blue Prism ya puede cargar 02_cambios." -ForegroundColor Green
