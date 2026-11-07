-- Guía SQL para Blue Prism (Lucas): sentencias exactas que el robot ejecuta por ODBC (psqlODBC, driver
-- "PostgreSQL Unicode(x64)"), en orden, como usuario bot_carga. Contrato v1.1 (docs\contratos.md).
--
-- Parámetros ODBC: marcadores ? posicionales (nunca concatenar valores en el texto SQL).
--   * Number de Blue Prism llega como decimal (.NET) -> OdbcType.Decimal: en las llamadas a funciones va SIEMPRE
--     CAST(? AS bigint) para carga_id/persona_id y CAST(? AS integer) para meses. Sin el CAST, PostgreSQL busca
--     api.cargar_dotacion(numeric) y responde "la función no existe".
--   * Text -> OdbcType.NVarChar.  Fechas -> DateTime (OdbcType.DateTime); un DBNull real, no el texto "NULL".
--   * En los INSERT de la Carga Masiva (PlanBot_PostgreSQL) no hace falta CAST: PostgreSQL convierte al tipo de la
--     columna (decimal -> bigint/integer/numeric, DateTime -> date).
--   * Una sentencia por llamada; set_config del motivo va en la MISMA sentencia que recalcular (paso 7).
--
-- Este archivo también es un ENSAYO ejecutable con psql: cada paso repite la sentencia ODBC con variables de psql
-- en lugar de ?, dentro de una transacción como bot_carga y con ROLLBACK al final (no deja datos).
-- Lo corre tests\sql\100_llamadas_robot.sql. A mano:
--   psql -X -h localhost -U owner_planbot -d planbot -v ON_ERROR_STOP=1 -f database\demo\llamadas_robot.sql
\set ON_ERROR_STOP on
\set QUIET on
BEGIN;
-- PG16: el ejecutor (owner_planbot o postgres) necesita membresía para SET ROLE; se deshace con el ROLLBACK.
GRANT bot_carga TO CURRENT_USER;
SET LOCAL ROLE bot_carga;
SELECT 'ensayo-llamadas-robot-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS') AS hash \gset
\set archivo '02_cambios.xlsx'
\set QUIET off

-- 1 · ¿Ya se cargó este archivo? (P01, T1 hash) -> si devuelve fila, es duplicado: no seguir.
--   ODBC: SELECT carga_id FROM stg.carga WHERE hash = ?;
SELECT carga_id FROM stg.carga WHERE hash = :'hash';

-- 2 · Registrar la carga y obtener su id (P01, T2 archivo, hash). Sin fila devuelta = otro proceso la registró.
--   ODBC: INSERT INTO stg.carga (tipo, archivo, hash, estado) VALUES ('buk', ?, ?, 'recibida')
--         ON CONFLICT (hash) DO NOTHING RETURNING carga_id;
INSERT INTO stg.carga (tipo, archivo, hash, estado) VALUES ('buk', :'archivo', :'hash', 'recibida')
ON CONFLICT (hash) DO NOTHING RETURNING carga_id \gset

-- 3 · Filas válidas (P02, Carga Masiva, lotes de 500). 17 columnas, en este orden y con estos tipos:
--   carga_id bigint, it integer, instituto text, persona_id bigint, area text, sub_area text, centro_costo text,
--   periodo date, tipo_contrato text, tipo_trabajador text, fecha_ingreso date, fecha_termino date (NULL si no
--   tiene), horas_semanales numeric, cargo text, dias_jornada text, ndias integer, cod_esp text
--   ODBC: INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo,
--           tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada,
--           ndias, cod_esp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
-- Ensayo: dos filas reales de 02_cambios.xlsx (traslado de 71146 a IT 101 en julio; 71555 con 30 h desde mayo).
INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo,
    tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp)
VALUES (:carga_id, 101, 'PMo', 71146, 'Puerto Montt', 'Psicología', '300513', DATE '2026-07-01', 'Indefinido',
        'Titular', DATE '2000-06-20', NULL, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
       (:carga_id, 131, 'San', 71555, 'Santiago', 'Terapia Ocupacional', '300503', DATE '2026-07-01', 'Indefinido',
        'Titular', DATE '1995-02-27', NULL, 30, 'TERAPEUTA OCUPACIONAL', 'lmwj', 4, 'TO');

-- 4 · Filas rechazadas por el robot (P02, Carga Masiva): carga_id bigint, fila integer (fila del Excel),
--   persona_id bigint (NULL si no se pudo leer), campo text, valor text, motivo text (texto libre, SIN el prefijo
--   'cargar_dotacion:', que es de la base). Si la base también rechaza esa fila, se cuenta una sola vez.
--   ODBC: INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo) VALUES (?, ?, ?, ?, ?, ?);
INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
VALUES (:carga_id, 45, 71247, 'horas_semanales', 'cuarenta', 'horas_semanales no es numérico');

-- 5 · Pasar la carga a la dotación (P02). Devuelve filas (válidas pasadas a core) y alertas. Deja en stg.carga
--   estado='cargada' y los contadores leidas / validas / con_error: el robot NO los actualiza.
--   ODBC: SELECT * FROM api.cargar_dotacion(CAST(? AS bigint));
SELECT * FROM api.cargar_dotacion(CAST(:carga_id AS bigint));
--   Contadores para el informe y la cola:
--   ODBC: SELECT leidas, validas, con_error, estado FROM stg.carga WHERE carga_id = CAST(? AS bigint);
SELECT leidas, validas, con_error, estado FROM stg.carga WHERE carga_id = CAST(:carga_id AS bigint);

-- 6 · Cambios y mes mínimo (P03). mes_minimo_afectado ejecuta detectar_cambios si hace falta; NULL = sin cambios
--   (no recalcular). Primera carga BUK = 1. La lista de cambios es opcional (para el informe):
--   ODBC: SELECT * FROM api.detectar_cambios(CAST(? AS bigint));
--   ODBC: SELECT api.mes_minimo_afectado(CAST(? AS bigint)) AS mes_minimo;
SELECT m AS mes_minimo, (m IS NOT NULL) AS hay_cambios FROM api.mes_minimo_afectado(CAST(:carga_id AS bigint)) m \gset
SELECT :'mes_minimo' AS mes_minimo, :'hay_cambios' AS hay_cambios;

-- 7 · Recalcular desde ese mes (P04), SOLO si mes_minimo no es NULL; nunca recalcular(NULL) ni (0).
--   El motivo queda en audit.log; set_config en la misma sentencia (local a su transacción). Devuelve filas, ms.
--   Al final recalcular también rehace la cuadratura.
--   ODBC (N2: carga_id, mes_minimo):
--   WITH contexto AS MATERIALIZED (
--     SELECT set_config('planbot.motivo', 'PlanBot Ciclo BUK; carga=' || CAST(CAST(? AS bigint) AS text), true) AS motivo)
--   SELECT r.filas, r.ms FROM contexto c
--   CROSS JOIN LATERAL api.recalcular(CASE WHEN c.motivo IS NOT NULL THEN CAST(? AS integer) END) r;
\if :hay_cambios
WITH contexto AS MATERIALIZED (
    SELECT set_config('planbot.motivo', 'PlanBot Ciclo BUK; carga=' || CAST(CAST(:carga_id AS bigint) AS text), true) AS motivo)
SELECT r.filas, r.ms FROM contexto c
CROSS JOIN LATERAL api.recalcular(CASE WHEN c.motivo IS NOT NULL THEN CAST(:mes_minimo AS integer) END) r;
\endif

-- 8 · % de coincidencia con el Excel (P06). Opcional: recalcular ya la rehizo; sirve para el informe.
--   ODBC: SELECT api.cuadratura() AS pct_coincidencia;
SELECT api.cuadratura() AS pct_coincidencia;

-- 9 · Solo en la recuperación de error (P05/maestro, Q09): marcar la carga. El robot solo puede cambiar estado.
--   ODBC: UPDATE stg.carga SET estado = 'error' WHERE carga_id = CAST(? AS bigint);
UPDATE stg.carga SET estado = 'error' WHERE carga_id = CAST(:carga_id AS bigint);

\echo 'Ensayo de llamadas del robot OK (se deshace con ROLLBACK)'
ROLLBACK;
