#requires -Version 5.1
param([string]$DirectorioPlanBot='C:\PlanBot', [ValidateRange(1,65535)][int]$PuertoApi=3000, [ValidateRange(1,65535)][int]$PuertoWeb=8080)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'comun.ps1')
$script:fallosPlanBot=0
function Mostrar-PlanBot([string]$Nombre,[bool]$Ok,[string]$Detalle) {
    if ($Ok) { Write-Host ('[OK] {0}: {1}' -f $Nombre,$Detalle) -ForegroundColor Green }
    else { $script:fallosPlanBot++; Write-Host ('[FALTA] {0}: {1}' -f $Nombre,$Detalle) -ForegroundColor Red }
}
foreach ($rel in @('entrada\planificacion','entrada\buk','entrada\asignaciones','procesados','errores','logs','respaldo','preparar')) {
    $ruta=Join-Path $DirectorioPlanBot $rel
    Mostrar-PlanBot "Carpeta $rel" (Test-Path -LiteralPath $ruta -PathType Container) $ruta
}
# Registry64 explícito: no confundir con WOW6432Node aunque el host sea PowerShell x86.
$registro=$null; $claveOdbc=$null
try {
    $registro=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
    $claveOdbc=$registro.OpenSubKey('SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers')
    $driver=$null; if ($claveOdbc) { $driver=$claveOdbc.GetValue('PostgreSQL Unicode(x64)') }
    Mostrar-PlanBot 'ODBC 64 bits' ($driver -eq 'Installed') 'PostgreSQL Unicode(x64) en registro de 64 bits'
} catch { Mostrar-PlanBot 'ODBC 64 bits' $false 'No se pudo leer el registro de Windows.' }
finally { if ($claveOdbc) {$claveOdbc.Dispose()}; if ($registro) {$registro.Dispose()} }
$servidor=Get-PlanBotVariable 'PG_HOST' (Get-PlanBotVariable 'PGHOST' 'localhost')
$puerto=[int](Get-PlanBotVariable 'PG_PORT' (Get-PlanBotVariable 'PGPORT' '5432'))
$servicios=@(Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Where-Object Status -eq Running)
$escucha=Test-PlanBotPuerto $servidor $puerto
Mostrar-PlanBot 'PostgreSQL' $escucha ("{0}:{1}; servicios locales activos: {2}" -f $servidor,$puerto,$servicios.Count)
$psql=$null
try { $psql=Get-PlanBotPsql; Mostrar-PlanBot 'psql' $true $psql }
catch { Mostrar-PlanBot 'psql' $false $_.Exception.Message }
$base=Get-PlanBotVariable 'POSTGRES_DB' 'planbot'
$kpiSql=$null
if ($psql) {
    $logins=@{}
    foreach ($usuario in @('bot_carga','web_lectura')) {
        $variable='BOT_CARGA_PASSWORD'; if ($usuario -eq 'web_lectura') { $variable='WEB_LECTURA_PASSWORD' }
        $r=Invoke-PlanBotLectura $psql $usuario (Get-PlanBotVariable $variable) $base 'SELECT current_user;'
        $logins[$usuario]=$r.Ok -and $r.Texto -eq $usuario
        Mostrar-PlanBot "Login $usuario" ($r.Ok -and $r.Texto -eq $usuario) $r.Texto
    }
    $claveBot=Get-PlanBotVariable 'BOT_CARGA_PASSWORD'
    foreach ($firma in @('cargar_parametros(bigint)','cargar_dotacion(bigint)','detectar_cambios(bigint)',
        'mes_minimo_afectado(bigint)','recalcular(integer)','simular(bigint)','aplicar_escenario(bigint)','cuadratura()')) {
        $r=[pscustomobject]@{Ok=$false;Texto='Login previo fallido.'}
        if ($logins['bot_carga']) { $r=Invoke-PlanBotLectura $psql 'bot_carga' $claveBot $base ("SELECT to_regprocedure('api.$firma') IS NOT NULL;") }
        Mostrar-PlanBot "RPC api.$firma" ($r.Ok -and $r.Texto -eq 't') 'Existencia del Contrato 2 (no se ejecuta)'
    }
    foreach ($vista in @('v_kpi','v_nacional_mes','v_instituto_area_mes','v_profesional_mes','v_cambios',
        'v_errores_carga','v_parametros_vigentes','v_cuadratura')) {
        $r=[pscustomobject]@{Ok=$false;Texto='Login previo fallido.'}
        if ($logins['web_lectura']) { $r=Invoke-PlanBotLectura $psql 'web_lectura' (Get-PlanBotVariable 'WEB_LECTURA_PASSWORD') $base ("SELECT count(*) FROM api.$vista;") }
        Mostrar-PlanBot "Vista api.$vista" $r.Ok $r.Texto
    }
    if ($logins['web_lectura']) {
        $r=Invoke-PlanBotLectura $psql 'web_lectura' (Get-PlanBotVariable 'WEB_LECTURA_PASSWORD') $base 'SELECT row_to_json(v) FROM api.v_kpi v;'
        if ($r.Ok -and $r.Texto) { $kpiSql=$r.Texto | ConvertFrom-Json }
    }
    $r=Invoke-PlanBotLectura $psql (Get-PlanBotVariable 'POSTGRES_USER' 'owner_planbot') (Get-PlanBotVariable 'POSTGRES_PASSWORD') $base 'SELECT count(*) FROM calc.plan_mes;'
    $n=0L; $hayPlan=$r.Ok -and [long]::TryParse($r.Texto,[ref]$n) -and $n -gt 0
    Mostrar-PlanBot 'Filas calc.plan_mes' $hayPlan $r.Texto
}
try {
    $r=Invoke-WebRequest "http://localhost:$PuertoApi/v_kpi" -UseBasicParsing -TimeoutSec 4 -Headers @{Origin="http://localhost:$PuertoWeb"}
    $json=$r.Content | ConvertFrom-Json
    $filas=@($json)
    $cors=$r.Headers['Access-Control-Allow-Origin'] -join ','
    $ok=$r.StatusCode -eq 200 -and $r.Content.TrimStart().StartsWith('[') -and $filas.Count -gt 0 -and
        $null -ne $filas[0].PSObject.Properties['atenciones_plan'] -and ($cors -eq '*' -or $cors -eq "http://localhost:$PuertoWeb")
    if ($ok) {
        $ok=$null -ne $kpiSql
        foreach ($campo in @('atenciones_plan','meta','horas_contratadas')) {
            if ($null -eq $kpiSql -or $filas[0].$campo -ne $kpiSql.$campo) { $ok=$false }
        }
    }
    Mostrar-PlanBot 'PostgREST /v_kpi + CORS' $ok "http://localhost:$PuertoApi/v_kpi (JSON nacional con datos)"
} catch { Mostrar-PlanBot 'PostgREST /v_kpi + CORS' $false 'No responde con los datos requeridos.' }
try {
    $r=Invoke-WebRequest "http://localhost:$PuertoWeb/" -UseBasicParsing -TimeoutSec 4
    Mostrar-PlanBot 'Dashboard HTTP' ($r.StatusCode -eq 200 -and $r.Content -match 'PlanBot') "http://localhost:$PuertoWeb/?modo=api#nacional"
} catch { Mostrar-PlanBot 'Dashboard HTTP' $false "No responde http://localhost:$PuertoWeb." }
Write-Host "Resultado: $script:fallosPlanBot comprobaciones pendientes. No certifica BP ni lectura visual en vivo."
if ($script:fallosPlanBot) { exit 1 }
exit 0
