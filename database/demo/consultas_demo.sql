-- Demo · 5 consultas para mostrar en vivo después de que Blue Prism cargue el BUK. Solo lectura.
-- Uso (no interactivo; antes: $env:PGPASSWORD = clave de owner_planbot en .env):
--   & 'C:\Program Files\PostgreSQL\16\bin\psql.exe' -X -h localhost -U owner_planbot -d planbot -f database\demo\consultas_demo.sql
-- Para ver solo una: copiar el bloque y ejecutarlo con psql -c "...".
\set QUIET on
\pset border 2
\pset null '—'
\pset footer off
\pset linestyle unicode
\set QUIET off

\echo
\echo '1 · Últimas cargas recibidas'
SELECT carga_id                         AS "carga",
       tipo,
       archivo,
       estado,
       to_char(recibido_en, 'DD-MM HH24:MI') AS "recibida",
       leidas                           AS "leídas",
       validas                          AS "válidas",
       con_error                        AS "con error"
FROM stg.carga
ORDER BY carga_id DESC
LIMIT 5;

\echo '2 · Cambios detectados en la última carga BUK (desde qué mes rigen)'
SELECT c.tipo                           AS "cambio",
       c.persona_id                     AS "persona",
       c.it                             AS "IT",
       c.mes_vigencia                   AS "desde mes",
       coalesce(c.antes::text, '—')     AS "antes",
       coalesce(c.despues::text, '—')   AS "después"
FROM core.cambios c
WHERE c.carga_id = (SELECT max(carga_id) FROM stg.carga WHERE tipo = 'buk')
ORDER BY c.mes_vigencia, c.tipo;

\echo '3 · Errores de la última carga BUK (fila, persona, campo y motivo)'
SELECT e.fila,
       e.persona_id                     AS "persona",
       e.campo,
       left(e.valor, 20)                AS "valor",
       left(regexp_replace(e.motivo, '^cargar_dotacion: ', ''), 60) AS "motivo"
FROM stg.error_fila e
WHERE e.carga_id = (SELECT max(carga_id) FROM stg.carga WHERE tipo = 'buk')
ORDER BY e.fila NULLS LAST;

\echo '4 · Último recálculo del plan y % de cuadratura con el Excel (audit.log)'
SELECT to_char(registrado_en, 'DD-MM HH24:MI:SS') AS "cuándo",
       usuario                          AS "quién",
       coalesce(motivo, '—')            AS "motivo",
       despues ->> 'desde_mes'          AS "desde mes",
       despues ->> 'filas'              AS "filas",
       despues ->> 'ms'                 AS "ms",
       coalesce(despues ->> 'cuadratura_pct' || ' %', '—') AS "cuadratura"
FROM audit.log
WHERE operacion = 'recalcular'
ORDER BY log_id DESC
LIMIT 1;

\echo '5 · Diferencias con el Excel por causa probable (api.v_cuadratura)'
SELECT causa,
       count(*)                         AS "diferencias",
       count(DISTINCT persona_id)       AS "personas"
FROM calc.cuadratura
GROUP BY causa
ORDER BY count(*) DESC;
