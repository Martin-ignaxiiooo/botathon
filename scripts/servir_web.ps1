<#
.SYNOPSIS
  Levanta la web de PlanBot (carpeta web\) en segundo plano, sin quedarse abierto.
.DESCRIPTION
  Usa python -m http.server con Start-Process oculto. Si el puerto ya responde, solo muestra la URL.
  Modo de datos: por defecto 'mock'; agregue ?modo=api a la URL para usar PostgREST (config.js).
.EXAMPLE
  .\scripts\servir_web.ps1              # sirve en http://localhost:8080
  .\scripts\servir_web.ps1 -Puerto 8081
  .\scripts\servir_web.ps1 -Detener     # detiene el servidor que levantó este script
#>
param(
    [int]$Puerto = 8080,
    [switch]$Detener
)

$ErrorActionPreference = 'Stop'
$url = "http://localhost:$Puerto"
$web = (Resolve-Path (Join-Path $PSScriptRoot '..\web')).Path

function Responde {
    try { (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $false }
}

if ($Detener) {
    $procesos = Get-CimInstance Win32_Process -Filter "Name like 'python%'" |
        Where-Object { $_.CommandLine -match "http\.server $Puerto" }
    if (-not $procesos) { Write-Host "No hay un servidor de la web en el puerto $Puerto."; return }
    $procesos | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Write-Host "Servidor detenido (puerto $Puerto)."
    return
}

if (Responde) {
    Write-Host "Ya hay un servidor respondiendo en $url (no se levantó otro)."
    Write-Host $url
    return
}

$python = (Get-Command python -ErrorAction SilentlyContinue)?.Source
if (-not $python) { throw 'No se encontró python en el PATH. Instale Python 3 o use docker compose up -d (nginx en :8080).' }

Start-Process -WindowStyle Hidden -FilePath $python -ArgumentList '-m', 'http.server', $Puerto -WorkingDirectory $web

for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 500
    if (Responde) {
        Write-Host "Web lista: $url  (datos de prueba; agregue ?modo=api para usar PostgREST)"
        Write-Host "Para detenerla: .\scripts\servir_web.ps1 -Detener -Puerto $Puerto"
        return
    }
}
throw "El servidor no respondió en $url. Revise que el puerto $Puerto esté libre."
