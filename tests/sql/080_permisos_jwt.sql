-- 080 · Permisos para PostgREST con JWT (C-01): web_lectura puede hacer SET ROLE planificador (lo hace PostgREST
-- con un token válido) pero no hereda sus permisos; planificador lee las vistas y decide escenarios.
DO $$
BEGIN
    IF NOT pg_has_role('web_lectura', 'planificador', 'SET') THEN
        RAISE EXCEPTION 'JWT: web_lectura no puede hacer SET ROLE planificador (PostgREST rechazaría el token)';
    END IF;
    IF pg_has_role('web_lectura', 'planificador', 'USAGE') THEN
        RAISE EXCEPTION 'JWT: web_lectura hereda los permisos de planificador (debe ser INHERIT FALSE)';
    END IF;
    IF has_function_privilege('web_lectura', 'api.decidir_escenario(bigint, text, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'JWT: sin token web_lectura no debe decidir escenarios';
    END IF;
    IF NOT has_table_privilege('planificador', 'api.v_kpi', 'SELECT')
       OR NOT has_table_privilege('planificador', 'api.v_cuadratura', 'SELECT')
       OR NOT has_function_privilege('planificador', 'api.listar_escenarios()', 'EXECUTE')
       OR NOT has_function_privilege('planificador', 'api.decidir_escenario(bigint, text, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'JWT: planificador sin lectura de api.* o sin decidir_escenario';
    END IF;
    RAISE NOTICE 'JWT OK (SET ROLE planificador sin herencia; planificador lee api.* y decide escenarios)';
END
$$;
