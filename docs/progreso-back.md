# Progreso BACK (Andrés · Claude Code)
Última actualización: 2026-11-07 · por: Claude Code
Rama actual: feat/B-01-B-02-base (push a origin; PR pendiente: gh no está instalado en el PC de laboratorio)

## Hecho
- B-01 · docker-compose.yml, V000__roles.sql, .env.example, scripts\_comun.ps1 (elige docker/nativo),
  migrar.ps1, test.ps1, instalar_sin_docker.ps1, database\instalar\crear_base.sql. Probado en nativo.
- B-02 · V001 esquemas, V002 stg.* (Contrato 1 exacto), V003 param.* y core.*, V004 calc.* y audit.log,
  tests\sql\000_humo.sql. instalar_sin_docker.ps1 corrido 2 veces sin error; test.ps1 -Modulo db y todo en verde.

## En curso
- —

## Siguiente
- B-03 (parámetros y CSV), B-04 (dotación + proyección ago-dic), B-05, B-06; prioridad B-09 (vistas api.* para César).

## Cómo correr en este PC (laboratorio Duoc, sin admin, NO reiniciar)
- Repo en `C:\dev\botathon`. Servicio `postgresql-x64-16` (puerto 5432) ya está en Running; superusuario `postgres`.
- `.env` (no versionado): copiar `.env.example`, poner claves y `PG_SUPER_PASSWORD`; `PG_HOST`/`PG_PORT`/`PG_BIN`
  por defecto localhost, 5432, `C:\Program Files\PostgreSQL\16\bin`.
- `.\scripts\instalar_sin_docker.ps1` (crea rol owner_planbot y base planbot, luego migra) · `.\scripts\test.ps1 -Modulo db`.
- Plan B sin servicio: instancia propia en `C:\dev\pgdata` (initdb -U postgres -A trust -E UTF8 --locale=C, port 5433),
  `pg_ctl -D C:\dev\pgdata -l C:\dev\pgdata\log.txt start`; en `.env` poner `PG_PORT=5433`. Ya está creada (detenida).
  Ojo: lanzar pg_ctl start desde PowerShell, no desde Git Bash (bash queda esperando).

## Errores conocidos / decisiones
- **Proyección ago-dic (regla de negocio, 6-nov):** stg.buk_fila solo trae ene-jul 2026 (corte de mitad de año).
  En B-04, `cargar_dotacion` genera los meses siguientes al último mes real de cada persona-IT, copiando sus
  condiciones (horas, cargo, área, contrato, días), hasta el mes de `fecha_termino` (incluido) o diciembre si no tiene.
  `core.dotacion_mes.origen` = 'buk' (real) | 'proyectado'. Un mes real posterior reemplaza al proyectado.
  Supuesto pendiente de confirmar: el mes de fecha_termino se proyecta completo (sin prorrateo).
  En B-07, `detectar_cambios` compara solo los (persona_id, it, mes) presentes en stg.buk_fila de ambas cargas.
- PC de laboratorio con PowerShell 5.1 (sin pwsh 7): .ps1 en UTF-8 con BOM, sin operadores de PS7. Rutas armadas
  con Join-Path y separador del sistema para que el CI (ubuntu + pwsh) también corra.
- Los scripts leen PG_HOST/PG_PORT y aceptan PGHOST/PGPORT o POSTGRES_HOST/POSTGRES_PORT (nombres del CI).
- Funciones del Contrato 2 irán en el esquema `api`; bot_carga tiene search_path `api, stg, public`
  para llamarlas sin prefijo. EXECUTE se revoca de PUBLIC por defecto y se da explícito por historia.
- Versionadas: cargo_distribucion, asignacion_catalogo, calendario_mes, grupal, general (version + vigencia).
  Catálogos sin versión: instituto, cargo_homologado.
- cargo_distribucion pk (version, cargo, tramo): 57 cargos vienen sin cod_esp. asignacion_catalogo con id propio
  (tipo se repite 2 veces en el CSV).
- PostgREST se conecta como web_lectura y usa el mismo rol como anónimo.
- No hay pandas en este PC (para B-04 hará falta `pip install --user pandas openpyxl` o usar csv/openpyxl).
