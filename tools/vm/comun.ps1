# Compatible con Windows PowerShell 5.1. Funciones sin efectos al importarlas.
function Get-PlanBotVariable([string]$Nombre, [string]$Defecto = '') {
    $valor = [Environment]::GetEnvironmentVariable($Nombre, 'Process')
    if ([string]::IsNullOrWhiteSpace($valor)) { return $Defecto }
    return $valor
}

function Get-PlanBotPsql {
    $bin = Get-PlanBotVariable 'PG_BIN' 'C:\Program Files\PostgreSQL\16\bin'
    $exe = Join-Path $bin 'psql.exe'
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
    $cmd = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'No se encuentra psql.exe. Instalar el cliente PostgreSQL 16 o definir PG_BIN.'
}

function Invoke-PlanBotLectura {
    param([string]$Psql, [string]$Usuario, [string]$Clave, [string]$Base, [string]$Sql)
    if ([string]::IsNullOrEmpty($Clave) -or $Clave -eq 'cambiar') {
        return [pscustomobject]@{ Ok=$false; Texto='Falta clave en entorno (o sigue en cambiar).' }
    }
    $anteriores = @{}
    foreach ($k in @('PGPASSWORD','PGCONNECT_TIMEOUT','PGOPTIONS','PGCLIENTENCODING')) {
        $anteriores[$k] = [Environment]::GetEnvironmentVariable($k,'Process')
    }
    try {
        $env:PGPASSWORD = $Clave
        $env:PGCONNECT_TIMEOUT = '3'
        $env:PGCLIENTENCODING = 'UTF8'
        $env:PGOPTIONS = '-c default_transaction_read_only=on -c statement_timeout=5000'
        $servidor = Get-PlanBotVariable 'PG_HOST' (Get-PlanBotVariable 'PGHOST' 'localhost')
        $puerto = Get-PlanBotVariable 'PG_PORT' (Get-PlanBotVariable 'PGPORT' '5432')
        # Solo consultas constantes controladas por estos scripts, sin contraseñas en argv.
        $preferenciaAnterior=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue' # Windows PowerShell 5.1: stderr nativo no debe abortar el informe.
            $salida = @(& $Psql -X -w -At -h $servidor -p $puerto -U $Usuario -d $Base -v ON_ERROR_STOP=1 -c $Sql 2>&1)
            $ok = $LASTEXITCODE -eq 0
        } finally { $ErrorActionPreference=$preferenciaAnterior }
        if ($ok) { return [pscustomobject]@{ Ok=$true; Texto=($salida -join "`n").Trim() } }
        # No propagar stderr: puede contener detalles de conexión del proveedor.
        return [pscustomobject]@{ Ok=$false; Texto='psql rechazó conexión/consulta. Revisar usuario, clave, permisos, host y puerto.' }
    } finally {
        foreach ($k in $anteriores.Keys) { [Environment]::SetEnvironmentVariable($k,$anteriores[$k],'Process') }
    }
}

function Test-PlanBotPuerto([string]$Servidor,[int]$Puerto) {
    $cliente = New-Object System.Net.Sockets.TcpClient
    try {
        $tarea = $cliente.ConnectAsync($Servidor,$Puerto)
        if (-not $tarea.Wait(1500)) { return $false }
        return $cliente.Connected
    } catch { return $false } finally { $cliente.Dispose() }
}

function Get-PlanBotProcesoPuerto([int]$Puerto) {
    $c = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue }
    return $null
}

function New-PlanBotRegistroProceso($Proceso,[string]$Tipo) {
    # El objeto que retorna Start-Process puede cachear Path vacio antes de cargar
    # el modulo. Obtener identidad fresca del SO; nunca registrar un Path nulo.
    $inicio=$Proceso.StartTime.ToUniversalTime().Ticks
    for($i=0;$i -lt 20;$i++) {
        $actual=Get-Process -Id $Proceso.Id -ErrorAction Stop
        if($actual.StartTime.ToUniversalTime().Ticks -ne $inicio) { throw 'PID reutilizado durante el arranque.' }
        if($actual.Path) { return [pscustomobject]@{Tipo=$Tipo;Id=$actual.Id;InicioUtc=$actual.StartTime.ToUniversalTime().ToString('o');Ejecutable=$actual.Path} }
        Start-Sleep -Milliseconds 50
    }
    throw 'No se pudo identificar el ejecutable del proceso propio.'
}

function Test-PlanBotIdentidadProceso($Registro) {
    $p = Get-Process -Id $Registro.Id -ErrorAction SilentlyContinue
    if (-not $p) { return $null }
    # ConvertFrom-Json puede materializar ISO como DateTime; comparar ticks UTC,
    # no el formato regional que toma un DateTime al convertirse a string.
    try { $inicio=[datetime]$Registro.InicioUtc } catch { return $null }
    if ($p.StartTime.ToUniversalTime().Ticks -ne $inicio.ToUniversalTime().Ticks -or $p.Path -ne $Registro.Ejecutable) { return $null }
    return $p
}

function Save-PlanBotProcesos([string]$Ruta,$Procesos) {
    # No contiene credenciales; nunca se adopta un proceso solo por ocupar el puerto.
    ConvertTo-Json -InputObject @($Procesos) -Depth 4 | Set-Content -LiteralPath $Ruta -Encoding UTF8
}
