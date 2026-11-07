#requires -Version 5.1
param([string]$DirectorioPlanBot='C:\PlanBot')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')
$estado=Join-Path $DirectorioPlanBot 'runtime\demo-procesos.json'
if (-not (Test-Path -LiteralPath $estado -PathType Leaf)) { Write-Host 'No hay procesos registrados por levantar_demo.ps1.'; return }
$pendientes=@()
$guardados=Get-Content -LiteralPath $estado -Raw | ConvertFrom-Json
foreach ($r in $guardados) {
    if (-not $r) { continue }
    if ($r.Tipo -notin @('Web','PostgREST')) { throw 'Registro de procesos no reconocido; no se detiene nada mas.' }
    $p=Test-PlanBotIdentidadProceso $r
    if (-not $p) { Write-Host "PID $($r.Id) ya no coincide con el proceso propio; no se toca."; continue }
    try { Stop-Process -Id $p.Id -ErrorAction Stop; Write-Host "Detenido $($r.Tipo), PID $($r.Id)." }
    catch { $pendientes+=$r; Write-Warning "No se pudo detener PID $($r.Id)." }
}
Save-PlanBotProcesos $estado $pendientes
Write-Host 'PostgreSQL, Blue Prism y procesos ajenos permanecen en su estado anterior.'
if ($pendientes.Count) { exit 1 }
