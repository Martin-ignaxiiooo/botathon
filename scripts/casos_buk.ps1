# SOLO PRUEBAS: carga en orden los casos D-04 (01_original, 02_cambios, 03_errores) y al final la base real,
# guardando métricas de cada carga en database\evidencia\b05\casos_*.txt. Deja cargada la base real.
# Uso: .\scripts\casos_buk.ps1
param([ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto')
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
$casos = [ordered]@{
    '01_original' = 'data\buk\01_original.xlsx'
    '02_cambios'  = 'data\buk\02_cambios.xlsx'
    '03_errores'  = 'data\buk\03_errores.xlsx'
    '99_base_real' = 'data\excel\Nac - Base contratos x mes.xlsx'
}
foreach ($nombre in $casos.Keys) {
    Write-Host "== $nombre"
    & (Join-Path $PSScriptRoot 'cargar_buk_prueba.ps1') -Archivo $casos[$nombre] -Forzar -Modo $modo
    if ($LASTEXITCODE -ne 0) { Write-Host "ERROR cargando $nombre" -ForegroundColor Red; exit 1 }
    $salida = "database/evidencia/b05/casos_$nombre.txt"
    $codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo 'database\evidencia\metricas_carga.sql' -Vars @{ salida = $salida }
    if ($codigo -ne 0) { Write-Host "ERROR en métricas de $nombre" -ForegroundColor Red; exit 1 }
}
Write-Host 'OK · métricas en database\evidencia\b05\casos_*.txt' -ForegroundColor Green
