-- Tras 02/P01-P05 sobre el snapshot de 01. Solo escribe tablas TEMP de esta sesión.
-- Ejecutar desde la raíz del repo (CSV esperado relativo); nunca carga datos productivos.
\set ON_ERROR_STOP on
\if :{?carga_id}
\else
\prompt 'carga_id observado de 02_cambios: ' carga_id
\endif
BEGIN;
CREATE TEMP TABLE b09_antes(persona_id bigint,it int,mes smallint,estado jsonb,calculado_en timestamptz) ON COMMIT DROP;
CREATE TEMP TABLE b09_esperados(tipo text,persona_id bigint,it int,mes_vigencia int) ON COMMIT DROP;
\copy b09_antes FROM 'C:/PlanBot/respaldo/01_plan_comparable.csv' CSV HEADER
\copy b09_esperados FROM 'data/buk/esperado_cambios.csv' CSV HEADER
SELECT now(),* FROM stg.carga WHERE carga_id=:'carga_id'::bigint;
SELECT * FROM api.v_cambios WHERE carga_id=:'carga_id'::bigint ORDER BY persona_id,mes_vigencia;
-- CERO filas: igualdad exacta del multiconjunto, también detecta duplicados.
WITH reales AS (
 SELECT tipo,persona_id,it,mes_vigencia FROM api.v_cambios WHERE carga_id=:'carga_id'::bigint
)
SELECT 'faltante' AS diferencia,f.* FROM (TABLE b09_esperados EXCEPT ALL TABLE reales) f
UNION ALL SELECT 'sobrante',s.* FROM (TABLE reales EXCEPT ALL TABLE b09_esperados) s;
-- CERO filas: no cambia negocio antes de cada vigencia ni personas ajenas.
-- Excluye solo calculado_en del estado comparable; version_param sí se compara.
WITH cortes AS (SELECT persona_id,min(mes_vigencia) AS desde FROM b09_esperados GROUP BY persona_id),
dif AS (
 SELECT coalesce(a.persona_id,p.persona_id) AS persona_id,coalesce(a.it,p.it) AS it,
        coalesce(a.mes,p.mes) AS mes,a.estado AS antes,to_jsonb(p)-'calculado_en' AS despues
 FROM b09_antes a FULL JOIN calc.plan_mes p USING(persona_id,it,mes)
 WHERE a.estado IS DISTINCT FROM (to_jsonb(p)-'calculado_en')
)
SELECT dif.* FROM dif LEFT JOIN cortes USING(persona_id) WHERE desde IS NULL OR mes<desde;
-- Guardar también los meses afectados: el chequeo anterior no prueba que se recalculó.
SELECT p.* FROM calc.plan_mes p JOIN b09_esperados e USING(persona_id)
WHERE p.mes>=e.mes_vigencia ORDER BY p.persona_id,p.it,p.mes;
SELECT * FROM api.v_kpi;
SELECT * FROM audit.log ORDER BY log_id DESC LIMIT 50;
ROLLBACK;
