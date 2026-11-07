-- Solo lectura; ejecutar con psql -X -At -v ON_ERROR_STOP=1 -f este_archivo.
-- No invoca RPC ni crea/migra objetos. Guardar salida JSON para revisión.
\set QUIET 1
BEGIN READ ONLY;
SET LOCAL statement_timeout = '5s';
SELECT json_build_object(
  'database', current_database(), 'usuario', current_user,
  'tablas_stg', (
    SELECT coalesce(json_agg(t ORDER BY t.tabla), '[]'::json) FROM (
      SELECT c.relname AS tabla,
        (SELECT json_agg(json_build_object('columna', a.attname, 'tipo', format_type(a.atttypid,a.atttypmod)) ORDER BY a.attnum)
         FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped) AS columnas,
        has_table_privilege(current_user,c.oid,'SELECT') AS puede_leer,
        has_table_privilege(current_user,c.oid,'INSERT') AS puede_insertar
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='stg' AND c.relkind IN ('r','p')
    ) t
  ),
  'funciones_api', (
    SELECT coalesce(json_agg(t ORDER BY t.funcion), '[]'::json) FROM (
      SELECT p.proname AS funcion, pg_get_function_identity_arguments(p.oid) AS argumentos,
        pg_get_function_result(p.oid) AS resultado,
        has_function_privilege(current_user,p.oid,'EXECUTE') AS puede_ejecutar
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='api'
    ) t
  ),
  'vistas_api', (
    SELECT coalesce(json_agg(t ORDER BY t.vista), '[]'::json) FROM (
      SELECT c.relname AS vista,
        (SELECT json_agg(a.attname ORDER BY a.attnum) FROM pg_attribute a
         WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped) AS columnas,
        has_table_privilege(current_user,c.oid,'SELECT') AS puede_leer,
        CASE WHEN EXISTS(SELECT 1 FROM pg_roles WHERE rolname='web_lectura')
          THEN has_table_privilege('web_lectura',c.oid,'SELECT') ELSE false END AS lectura_web
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='api' AND c.relkind IN ('v','m')
    ) t
  )
);
COMMIT;
