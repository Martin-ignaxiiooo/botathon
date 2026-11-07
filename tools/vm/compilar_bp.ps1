#requires -Version 5.1
# Compila referencias; no importa ni publica un release de Blue Prism.
param(
    [string]$Salida=(Join-Path ([IO.Path]::GetTempPath()) ('PlanBot_BP_'+[Guid]::NewGuid().ToString('N'))),
    [string]$Csc='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Csc)) { throw 'Falta csc.exe de .NET Framework 4 de 64 bits.' }
if (Test-Path -LiteralPath $Salida) { throw 'Salida debe ser una carpeta nueva.' }
$null=New-Item -ItemType Directory -Path $Salida
$Salida=(Resolve-Path -LiteralPath $Salida).Path
$raiz=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fuentes=@(Get-ChildItem -LiteralPath (Join-Path $raiz 'bluePrism\codigo') -Filter 'PlanBot_*.cs' | ForEach-Object FullName)
if ($fuentes.Count -ne 5) { throw 'Se esperaban cinco objetos PlanBot_*.cs.' }
# /noconfig impide que csc.rsp agregue System.Core u otras referencias implícitas.
# El compilador instalado admite C# 5: es un subconjunto de C# 7.3.
$opciones=@('/nologo','/noconfig','/langversion:5','/warnaserror','/r:System.dll','/r:System.Data.dll','/r:System.Xml.dll')
function Compilar-BP([string[]]$Argumentos) {
    & $Csc @opciones @Argumentos
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de compilacion; no se certifica Check Code de BP.' }
}
foreach($fuente in $fuentes) {
    Compilar-BP (@('/target:library',('/out:'+(Join-Path $Salida ([IO.Path]::GetFileNameWithoutExtension($fuente)+'.dll'))),$fuente))
}
foreach($vuelta in 1,2) {
    Compilar-BP (@('/target:library',('/out:'+(Join-Path $Salida ('PlanBot_'+$vuelta+'.dll'))))+$fuentes)
}
# Microsoft.VisualBasic se usa SOLO en la consola lectora de CSV, nunca en el BO.
$vb=Join-Path (Split-Path -Parent $Csc) 'Microsoft.VisualBasic.dll'
if (-not (Test-Path -LiteralPath $vb)) { throw 'Falta Microsoft.VisualBasic.dll para la consola de pruebas.' }
Compilar-BP @('/target:exe',('/out:'+(Join-Path $Salida 'Probar_CodeStages.exe')),('/r:'+(Join-Path $Salida 'PlanBot_2.dll')),('/r:'+$vb),(Join-Path $raiz 'bluePrism\codigo\Probar_CodeStages.cs'))
Write-Host 'OK: cinco objetos individuales, dos compilaciones conjuntas y consola; referencias BP sin System.Core.' -ForegroundColor Green
Write-Host ('Artefactos: '+$Salida)
