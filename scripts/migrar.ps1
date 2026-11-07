# Corre database\migrations, functions, views y seed en orden (psql -f, ON_ERROR_STOP).
# Uso: .\scripts\migrar.ps1 [-Modo auto|docker|nativo]
param([ValidateSet('auto', 'docker', 'nativo')] [string] $Modo = 'auto')
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$modo = Resolver-Modo $Modo
$vars = @{ bot_pwd = $cfg['BOT_CARGA_PASSWORD']; web_pwd = $cfg['WEB_LECTURA_PASSWORD'] }
Write-Host "PlanBot · migrar (modo $modo)"

$inicio = Get-Date
$env:PGOPTIONS = '-c client_min_messages=warning'   # oculta los NOTICE "ya existe, omitiendo"
foreach ($carpeta in 'migrations', 'functions', 'views', 'seed') {
    $dir = Join-Path (Join-Path $Raiz 'database') $carpeta
    if (-not (Test-Path $dir)) { continue }
    $archivos = Get-ChildItem $dir -Filter '*.sql' -File | Sort-Object Name
    foreach ($f in $archivos) {
        $rel = "database\$carpeta\$($f.Name)"
        Write-Host "  -> $rel"
        $codigo = Invocar-Psql -Cfg $cfg -Modo $modo -Archivo $rel -Vars $vars
        if ($codigo -ne 0) {
            Write-Host "ERROR en $rel (código $codigo)" -ForegroundColor Red
            Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
            exit 1
        }
    }
}
Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
Write-Host ("OK · migración completa en {0:N1} s" -f ((Get-Date) - $inicio).TotalSeconds) -ForegroundColor Green
