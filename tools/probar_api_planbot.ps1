# Solo GET, sin RPC ni cargas. Ejecutar en VM/red coordinada con el equipo.
param(
    [Parameter(Mandatory)] [uri] $ApiUrl,
    [string] $Origen = 'http://localhost:8080',
    [string] $Salida = (Join-Path $PSScriptRoot 'resultados\api_integracion.json')
)
$ErrorActionPreference = 'Stop'
if ($ApiUrl.Scheme -notin @('http','https') -or $ApiUrl.UserInfo -or $ApiUrl.Query) { throw 'Usar URL base HTTP(S), sin credenciales ni query.' }
$contrato = Get-Content (Join-Path $PSScriptRoot '..\tests\e2e\contrato_v1_1.json') -Raw -Encoding utf8 | ConvertFrom-Json
$cabeceras = @{ Accept='application/json'; Origin=$Origen }
if ($env:PLANBOT_TEST_TOKEN) { $cabeceras.Authorization = 'Bearer ' + $env:PLANBOT_TEST_TOKEN }
$resultados = @()
foreach ($vista in $contrato.vistas.PSObject.Properties) {
    $select = [uri]::EscapeDataString(($vista.Value -join ','))
    $uri = $ApiUrl.AbsoluteUri.TrimEnd('/') + '/' + $vista.Name + '?select=' + $select + '&limit=1'
    try {
        $r = Invoke-WebRequest -Uri $uri -Headers $cabeceras -TimeoutSec 5 -UseBasicParsing
        if (-not $r.Content.TrimStart().StartsWith('[')) { throw 'Se esperaba un array JSON, no HTML u objeto.' }
        $filas = @($r.Content | ConvertFrom-Json)
        if ($filas.Count) {
            foreach ($columna in $vista.Value) {
                if ($columna -notin $filas[0].PSObject.Properties.Name) { throw "Falta $columna" }
            }
        }
        $cors = $r.Headers['Access-Control-Allow-Origin'] -join ','
        if ($cors -ne '*' -and $cors -ne $Origen) { throw 'La respuesta no permite el origen del dashboard (CORS).' }
        $resultados += [pscustomobject]@{ vista=$vista.Name; estado='CONTRATO_HTTP_OK'; filas_muestra=$filas.Count; cors=$cors }
    } catch {
        $resultados += [pscustomobject]@{ vista=$vista.Name; estado='FALLA'; detalle=$_.Exception.Message }
    }
}
$dir = Split-Path -Parent $Salida
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
@{ api=$ApiUrl.AbsoluteUri; origen=$Origen; contrato=$contrato.git_ref; resultados=$resultados; recorrido_real='Pendiente: cotejar carga_id, conteos y pantalla tras Blue Prism' } |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Salida -Encoding utf8
$resultados | Format-Table -AutoSize
Write-Host "Evidencia sin datos personales ni token: $Salida"
if (@($resultados | Where-Object estado -eq 'FALLA').Count) { exit 1 }
