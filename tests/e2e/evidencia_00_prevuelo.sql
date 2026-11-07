-- Solo lectura: no llama cargas, recálculos ni escenarios.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SELECT current_database(),current_user,version(),now();
SELECT firma,to_regprocedure(firma) IS NOT NULL AS disponible
FROM (VALUES ('api.cargar_parametros(bigint)'),('api.cargar_dotacion(bigint)'),
 ('api.detectar_cambios(bigint)'),('api.mes_minimo_afectado(bigint)'),
 ('api.recalcular(integer)'),('api.simular(bigint)'),
 ('api.aplicar_escenario(bigint)'),('api.cuadratura()')) AS contrato(firma);
SELECT c.relname AS vista,array_agg(a.attname ORDER BY a.attnum) AS columnas,
       has_table_privilege('web_lectura',c.oid,'SELECT') AS lectura_web
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE n.nspname='api' AND c.relkind='v'
GROUP BY c.oid,c.relname ORDER BY c.relname;
SELECT (SELECT count(*) FROM stg.buk_fila) AS stg_buk,
       (SELECT count(*) FROM core.dotacion_mes) AS dotacion,
       (SELECT count(*) FROM calc.plan_mes) AS plan_mes;
SELECT * FROM api.v_kpi;
SELECT sum(atenciones_dir) AS atenciones_dir,sum(meta) AS meta,
       sum(horas_contratadas) AS horas_contratadas
FROM api.v_instituto_area_mes;
SELECT it,area,cargo,mes,horas_contratadas,horas_dir,horas_ind,horas_nas
FROM api.v_instituto_area_mes ORDER BY it,area,cargo,mes LIMIT 20;
COMMIT;
