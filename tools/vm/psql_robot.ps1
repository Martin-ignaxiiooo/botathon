# Auxiliares de psql no interactivos. No importa .env ni cambia credenciales persistentes.
function Invoke-RobotPsql {
    param([string]$Psql,[string]$Servidor,[int]$Puerto,[string]$Base,[string]$Usuario,
        [string]$VariableClave,[string]$ArchivoSql,[hashtable]$Variables=@{})
    $anterior=@{}
    foreach($k in @('PGPASSWORD','PGCONNECT_TIMEOUT','PGCLIENTENCODING','PGOPTIONS')) { $anterior[$k]=[Environment]::GetEnvironmentVariable($k,'Process') }
    $clave=[Environment]::GetEnvironmentVariable($VariableClave,'Process')
    if (-not $clave -or $clave -eq 'cambiar') { throw "Falta clave valida en variable de entorno $VariableClave (no usar argumentos con claves)." }
    try {
        $env:PGPASSWORD=$clave; $env:PGCONNECT_TIMEOUT='3'; $env:PGCLIENTENCODING='UTF8'
        $env:PGOPTIONS='-c client_min_messages=warning -c statement_timeout=30000 -c lock_timeout=5000'
        $argumentos=@('-X','-w','-qAt','-h',$Servidor,'-p',[string]$Puerto,'-U',$Usuario,'-d',$Base,'-v','ON_ERROR_STOP=1')
        foreach($k in $Variables.Keys) { $argumentos+=@('-v',($k+'='+[string]$Variables[$k])) }
        $argumentos+=@('-f',$ArchivoSql)
        $preferencia=$ErrorActionPreference
        try { $ErrorActionPreference='Continue'; $salida=@(& $Psql @argumentos 2>&1); $codigo=$LASTEXITCODE }
        finally { $ErrorActionPreference=$preferencia }
        $texto=($salida -join "`n").Trim()
        if ($codigo -ne 0) { throw ('psql: '+$texto.Replace($clave,'[CLAVE OMITIDA]')) }
        return $texto
    } finally { foreach($k in $anterior.Keys) { [Environment]::SetEnvironmentVariable($k,$anterior[$k],'Process') } }
}

function Write-RobotSql([string]$Ruta,[string]$Sql) {
    [IO.File]::WriteAllText($Ruta,$Sql,(New-Object Text.UTF8Encoding($false)))
    return $Ruta
}
