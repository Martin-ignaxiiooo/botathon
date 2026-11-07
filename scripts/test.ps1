# Pruebas de PlanBot. db: cada tests\sql\*.sql con ON_ERROR_STOP (falla si alguno lanza excepción).
# web: tests\e2e\*.ps1 si existen. Uso: .\scripts\test.ps1 -Modulo db|web|todo [-Modo auto|docker|nativo]
param(
    [ValidateSet('db', 'web', 'todo')] [string] $Modulo = 'todo',
    [ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto'
)
. "$PSScriptRoot\_comun.ps1"

$fallas = @()

if ($Modulo -in 'db', 'todo') {
    $cfg = Leer-Env
    $modo = Resolver-Modo $Modo
    Write-Host "PlanBot · pruebas db (modo $modo)"
    $archivos = Get-ChildItem (Join-Path (Join-Path $Raiz 'tests') 'sql') -Filter '*.sql' -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $archivos) { Write-Host '  (sin pruebas en tests\sql)' }
    foreach ($f in $archivos) {
        $rel = "tests\sql\$($f.Name)"
        $t = Get-Date
        $codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo $rel
        $s = ((Get-Date) - $t).TotalSeconds
        if ($codigo -eq 0) { Write-Host ("  OK    {0} ({1:N1} s)" -f $rel, $s) -ForegroundColor Green }
        else { Write-Host ("  FALLA {0}" -f $rel) -ForegroundColor Red; $fallas += $rel }
    }
}

if ($Modulo -in 'web', 'todo') {
    Write-Host 'PlanBot · pruebas web'
    $e2e = Get-ChildItem (Join-Path (Join-Path $Raiz 'tests') 'e2e') -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $e2e) { Write-Host '  (sin pruebas en tests\e2e)' }
    foreach ($f in $e2e) {
        $ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        & $ps -NoProfile -File $f.FullName
        if ($LASTEXITCODE -eq 0) { Write-Host "  OK    tests\e2e\$($f.Name)" -ForegroundColor Green }
        else { Write-Host "  FALLA tests\e2e\$($f.Name)" -ForegroundColor Red; $fallas += "tests\e2e\$($f.Name)" }
    }
}

if ($fallas.Count -gt 0) {
    Write-Host "FALLARON $($fallas.Count): $($fallas -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host 'Todo en verde.' -ForegroundColor Green
