-- Tras 01_original/P01-P05, antes de tomar dump y entregar 02.
-- Requiere C:\PlanBot\respaldo existente. CSV escrito en el PC que ejecuta psql.
\set ON_ERROR_STOP on
\if :{?carga_id}
\else
\prompt 'carga_id observado de 01_original: ' carga_id
\endif
BEGIN READ ONLY;
SELECT now(),current_database(),current_user;
SELECT * FROM stg.carga WHERE carga_id=:'carga_id'::bigint;
SELECT count(*) AS filas_buk FROM stg.buk_fila WHERE carga_id=:'carga_id'::bigint;
SELECT * FROM api.v_kpi;
SELECT * FROM api.v_nacional_mes ORDER BY mes;
SELECT * FROM api.v_errores_carga WHERE carga_id=:'carga_id'::bigint ORDER BY fila,campo;
\copy (SELECT persona_id,it,mes,to_jsonb(p)-'calculado_en' AS estado,calculado_en FROM calc.plan_mes p ORDER BY persona_id,it,mes) TO 'C:/PlanBot/respaldo/01_plan_comparable.csv' WITH (FORMAT csv,HEADER true,ENCODING 'UTF8')
\copy (SELECT * FROM api.v_instituto_area_mes ORDER BY it,area,cargo,mes) TO 'C:/PlanBot/respaldo/01_instituto_area_mes.csv' WITH (FORMAT csv,HEADER true,ENCODING 'UTF8')
COMMIT;
-- El CSV no es un respaldo restaurable. Crear pg_dump después, en ventana acordada.
