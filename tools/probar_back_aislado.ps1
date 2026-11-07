# Ensayo explícito y desechable: NO usa servicios, .env ni puertos de la demo.
# Requiere Git, PowerShell 7, Python/openpyxl y binarios PostgreSQL 16.
param(
    [string] $Referencia = 'origin/feat/B-05-semanal',
    [string] $PgBin = 'C:\Program Files\PostgreSQL\16\bin'
)
$ErrorActionPreference = 'Stop'
$raizEnsayo = Split-Path -Parent $PSScriptRoot
$shaEnsayo = (& git -C $raizEnsayo rev-parse --verify "$Referencia^{commit}").Trim()
if ($LASTEXITCODE -ne 0) { throw 'La referencia debe existir localmente; ejecutar git fetch origin antes.' }
$directorioEnsayo = Join-Path ([IO.Path]::GetTempPath()) ('PlanBot_Integracion_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directorioEnsayo | Out-Null
$fuenteEnsayo = Join-Path $directorioEnsayo 'fuente'
New-Item -ItemType Directory -Path $fuenteEnsayo | Out-Null
$archivoEnsayo = Join-Path $directorioEnsayo 'fuente.zip'
& git -C $raizEnsayo archive --format=zip "--output=$archivoEnsayo" $shaEnsayo database scripts tests/sql data/csv docker-compose.yml
if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener el snapshot del back.' }
Expand-Archive -LiteralPath $archivoEnsayo -DestinationPath $fuenteEnsayo
$pgDatosEnsayo = Join-Path $directorioEnsayo 'pgdata'
$pgControlEnsayo = Join-Path $PgBin 'pg_ctl.exe'
$psqlEnsayo = Join-Path $PgBin 'psql.exe'
$listenerEnsayo = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listenerEnsayo.Start()
$puertoEnsayo = $listenerEnsayo.LocalEndpoint.Port
$listenerEnsayo.Stop()
if ($puertoEnsayo -in @(5432, 3000, 8080)) { throw 'No se utilizará un puerto del proyecto.' }
$iniciadoEnsayo = $false
$resultadoEnsayo = [ordered]@{ referencia = $Referencia; sha = $shaEnsayo; puerto = $puertoEnsayo; directorio = $directorioEnsayo; migrar = 'pendiente'; pruebas_db = 'pendiente'; cargar_original = 'pendiente'; pruebas_db_con_original = 'pendiente' }
try {
    & (Join-Path $PgBin 'initdb.exe') -D $pgDatosEnsayo -U integracion_admin --auth=trust --no-locale --encoding=UTF8 *> (Join-Path $directorioEnsayo 'initdb.log')
    if ($LASTEXITCODE -ne 0) { throw "Falló initdb; revisar $directorioEnsayo\initdb.log" }
    # Trust solo para este cluster temporal con datos de ensayo y escucha loopback.
    & $pgControlEnsayo -D $pgDatosEnsayo -l (Join-Path $directorioEnsayo 'postgres.log') -o "-h 127.0.0.1 -p $puertoEnsayo" -w -t 20 start
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la instancia aislada.' }
    $iniciadoEnsayo = $true
    $actual = & $psqlEnsayo -X -h 127.0.0.1 -p $puertoEnsayo -U integracion_admin -d postgres -At -c "SELECT current_setting('port');"
    if ($LASTEXITCODE -ne 0 -or [int]$actual -ne $puertoEnsayo) { throw 'No coincide el puerto aislado.' }
    & $psqlEnsayo -X -h 127.0.0.1 -p $puertoEnsayo -U integracion_admin -d postgres -v ON_ERROR_STOP=1 -v owner=owner_planbot -v owner_pwd=prueba_aislada -v db=planbot -f (Join-Path $fuenteEnsayo 'database\instalar\crear_base.sql') *> (Join-Path $directorioEnsayo 'crear_base.log')
    if ($LASTEXITCODE -ne 0) { throw 'Falló la creación de la base aislada.' }
    @(
        'POSTGRES_DB=planbot'; 'POSTGRES_USER=owner_planbot'; 'POSTGRES_PASSWORD=prueba_aislada'
        'BOT_CARGA_PASSWORD=bot_aislado'; 'WEB_LECTURA_PASSWORD=web_aislada'
        'PG_HOST=127.0.0.1'; "PG_PORT=$puertoEnsayo"; "PG_BIN=$PgBin"
    ) | Set-Content -LiteralPath (Join-Path $fuenteEnsayo '.env') -Encoding utf8
    & pwsh -NoProfile -File (Join-Path $fuenteEnsayo 'scripts\migrar.ps1') -Modo nativo *> (Join-Path $directorioEnsayo 'migrar.log')
    $resultadoEnsayo.migrar = $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) { throw 'Falló la migración; no se continúa la carga.' }
    & pwsh -NoProfile -File (Join-Path $fuenteEnsayo 'scripts\test.ps1') -Modulo db -Modo nativo *> (Join-Path $directorioEnsayo 'pruebas_db.log')
    $resultadoEnsayo.pruebas_db = $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron pruebas SQL previas; revisar pruebas_db.log.' }
    & pwsh -NoProfile -File (Join-Path $fuenteEnsayo 'scripts\cargar_buk_prueba.ps1') -Archivo (Join-Path $raizEnsayo 'data\buk\01_original.xlsx') -Modo nativo *> (Join-Path $directorioEnsayo 'cargar_original.log')
    $resultadoEnsayo.cargar_original = $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) { throw 'Falló carga original; revisar cargar_original.log.' }
    & pwsh -NoProfile -File (Join-Path $fuenteEnsayo 'scripts\test.ps1') -Modulo db -Modo nativo *> (Join-Path $directorioEnsayo 'pruebas_db_con_original.log')
    $resultadoEnsayo.pruebas_db_con_original = $LASTEXITCODE
    # Catálogo consultado como bot_carga: comprueba visibilidad/permisos reales.
    & $psqlEnsayo -X -h 127.0.0.1 -p $puertoEnsayo -U bot_carga -d planbot -At -v ON_ERROR_STOP=1 -f (Join-Path $raizEnsayo 'tests\e2e\inspeccionar_contrato.sql') > (Join-Path $directorioEnsayo 'catalogo_bot.json')
    if ($LASTEXITCODE -ne 0) { throw 'Falló la inspección del catálogo.' }
    & $psqlEnsayo -X -h 127.0.0.1 -p $puertoEnsayo -U integracion_admin -d planbot -At -c "SELECT json_build_object('version',version(),'stg_buk',(SELECT count(*) FROM stg.buk_fila),'dotacion',(SELECT count(*) FROM core.dotacion_mes),'semanal',(SELECT count(*) FROM calc.v_semanal),'plan_mes',(SELECT count(*) FROM calc.plan_mes));" > (Join-Path $directorioEnsayo 'conteos.json')
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron los conteos de la instancia aislada.' }
    # Sonda reversible de conteos: simula una fila rechazada por BP y otra válida.
    # Se usa únicamente este cluster, bot_carga y ROLLBACK; no cambia el fixture.
    @'
\set QUIET 1
BEGIN;
INSERT INTO stg.carga(tipo,archivo,hash) VALUES('buk','sonda_aislada','sonda:conteos') RETURNING carga_id \gset
INSERT INTO stg.buk_fila(carga_id,it,instituto,persona_id,periodo,fecha_ingreso,horas_semanales,cargo,dias_jornada,ndias)
VALUES(:carga_id,11,'Arica',999888001,'2026-01-01','2020-01-01',20,'KINESIOLOGO','lmwjv',5);
INSERT INTO stg.error_fila(carga_id,fila,persona_id,campo,valor,motivo)
VALUES(:carga_id,4,999888002,'horas_semanales','cuarenta','BP: horas no numéricas');
SELECT * FROM api.cargar_dotacion(:carga_id);
SELECT json_build_object('con_error_guardado',con_error,'errores_bp_presentes',
  (SELECT count(*) FROM stg.error_fila WHERE carga_id=:carga_id)) FROM stg.carga WHERE carga_id=:carga_id;
ROLLBACK;
'@ | & $psqlEnsayo -X -h 127.0.0.1 -p $puertoEnsayo -U bot_carga -d planbot -At -v ON_ERROR_STOP=1 > (Join-Path $directorioEnsayo 'sonda_conteos.log')
    if ($LASTEXITCODE -ne 0) { throw 'Falló la sonda de conteos aislada.' }
} catch {
    $resultadoEnsayo.error = $_.Exception.Message
    throw
} finally {
    if ($iniciadoEnsayo) {
        & $pgControlEnsayo -D $pgDatosEnsayo -m fast -w -t 20 stop
        $resultadoEnsayo.parada = $LASTEXITCODE
    }
    $resultadoEnsayo | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $directorioEnsayo 'resultado.json') -Encoding utf8
    Write-Host "Evidencia de ensayo aislado: $directorioEnsayo"
    Write-Host ($resultadoEnsayo | ConvertTo-Json -Compress)
}
if ($resultadoEnsayo.pruebas_db -ne 0 -or $resultadoEnsayo.cargar_original -ne 0 -or $resultadoEnsayo.pruebas_db_con_original -ne 0 -or $resultadoEnsayo.parada -ne 0) { exit 1 }
# Éxito del ensayo parcial no equivale a API/dashboard ni Blue Prism aprobados.
