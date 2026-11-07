# Captura una pantalla del dashboard a escala 2 con Edge sin ventana (herramienta de desarrollo).
# Requiere la web servida (scripts\servir_web.ps1) y, para -Modo api, el back local con PostgREST en :3000.
# Guarda el PNG en docs\capturas.
# Uso: .\web\dev\capturar.ps1 -Nombre 01-nacional -Ruta '#nacional' [-Modo api|mock] [-Paso ninguno|efecto|profesionales|dialogo|impresion]
#                             [-Ancho 1440] [-Alto 0 (0 = mide la pantalla)] [-Prev '<json del KPI anterior>' (solo -Paso efecto)]
param(
    [Parameter(Mandatory)] [string] $Nombre,
    [Parameter(Mandatory)] [string] $Ruta,
    [string] $Modo = 'api',
    [string] $Paso = 'ninguno',
    [int] $Ancho = 1440,
    [int] $Alto = 0,
    [string] $Prev = ''
)
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$destino = Join-Path $raiz 'docs\capturas'
New-Item -ItemType Directory -Force $destino | Out-Null
$perfil = Join-Path $env:TEMP ('edge-cap-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

function Url([int] $alto) {
    $q = "r=$([uri]::EscapeDataString($Ruta))&modo=$Modo&paso=$Paso&ancho=$Ancho&alto=$alto"
    if ($Prev) { $q += "&prev=$([uri]::EscapeDataString($Prev))" }
    "http://localhost:8080/dev/captura.html?$q"
}

# Pasada 1: medir el alto real de la pantalla (si no se fijó uno)
if ($Alto -eq 0) {
    $out = & $edge --headless=new --disable-gpu --user-data-dir="$perfil-m" --virtual-time-budget=40000 --dump-dom (Url 0) 2>&1 | Out-String
    $m = [regex]::Matches($out, '<pre id="salida">(.*?)</pre>', 'Singleline')
    $info = [System.Net.WebUtility]::HtmlDecode($m[$m.Count - 1].Groups[1].Value) | ConvertFrom-Json
    if ($info.error) { throw "Error midiendo: $($info.error)" }
    $Alto = [int]$info.alto
}
# Pasada 2: captura a escala 2
$archivo = Join-Path $destino "$Nombre.png"
& $edge --headless=new --disable-gpu --user-data-dir="$perfil-c" --force-device-scale-factor=2 --window-size="$Ancho,$Alto" --virtual-time-budget=40000 --screenshot="$archivo" (Url $Alto) 2>&1 | Out-Null
$f = Get-Item $archivo
"{0}: {1}x{2} css -> {3:N0} KB" -f $Nombre, $Ancho, $Alto, ($f.Length / 1KB)
