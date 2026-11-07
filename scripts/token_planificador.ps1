# Genera un JWT HS256 {"role":"planificador","exp":...} firmado con PGRST_JWT_SECRET de .env y lo imprime.
# Con ese token PostgREST ejecuta como planificador (puede aprobar o rechazar escenarios con decidir_escenario).
# Uso:  .\scripts\token_planificador.ps1 [-Horas 24]
#       $t = .\scripts\token_planificador.ps1        (la salida estándar es solo el token)
# El token NO se guarda en ningún archivo. No lo subas al repositorio ni lo pegues en el chat del equipo.
# Compatible con Windows PowerShell 5.1 y 7. Guardar en UTF-8 con BOM.
param([ValidateRange(1, 168)] [int] $Horas = 24)
. "$PSScriptRoot\_comun.ps1"

$cfg = Leer-Env
$secreto = [string] $cfg['PGRST_JWT_SECRET']
if (-not $secreto -or $secreto -like 'cambiar*' -or $secreto.Length -lt 32) {
    throw 'PGRST_JWT_SECRET falta en .env, es el valor de ejemplo o tiene menos de 32 caracteres. Corre .\scripts\instalar_sin_docker.ps1 (lo genera) y reinicia PostgREST.'
}

function Base64Url([byte[]] $bytes) {
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$exp = [int64](([DateTime]::UtcNow.AddHours($Horas)) - [DateTime]'1970-01-01').TotalSeconds
$cabecera = Base64Url $utf8.GetBytes('{"alg":"HS256","typ":"JWT"}')
$cuerpo = Base64Url $utf8.GetBytes('{"role":"planificador","exp":' + $exp + '}')
$hmac = New-Object System.Security.Cryptography.HMACSHA256 (, $utf8.GetBytes($secreto))
try {
    $firma = Base64Url $hmac.ComputeHash($utf8.GetBytes("$cabecera.$cuerpo"))
} finally { $hmac.Dispose() }

$vence = [DateTime]::Now.AddHours($Horas).ToString('yyyy-MM-dd HH:mm')
[Console]::Error.WriteLine("Token de planificador (vence $vence). Header: Authorization: Bearer <token>")
Write-Output "$cabecera.$cuerpo.$firma"
