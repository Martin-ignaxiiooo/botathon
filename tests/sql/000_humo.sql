-- 000 · Humo: existen roles, esquemas, tablas, y stg.* calza EXACTO (columnas y orden) con el Contrato 1.
DO $$
DECLARE
    r       record;
    real    text;
    faltan  text[] := '{}';
BEGIN
    -- Roles
    FOR r IN SELECT unnest(ARRAY['owner_planbot', 'bot_carga', 'web_lectura', 'planificador']) AS x LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.x) THEN faltan := faltan || ('rol ' || r.x); END IF;
    END LOOP;

    -- Esquemas
    FOR r IN SELECT unnest(ARRAY['param', 'stg', 'core', 'calc', 'audit', 'api']) AS x LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = r.x) THEN
            faltan := faltan || ('esquema ' || r.x);
        END IF;
    END LOOP;

    -- Tablas
    FOR r IN SELECT unnest(ARRAY[
        'stg.carga', 'stg.buk_fila', 'stg.error_fila', 'stg.param_cargo', 'stg.param_asignacion',
        'stg.param_calendario', 'stg.param_grupal', 'stg.excepcion', 'stg.asignacion', 'stg.esperado',
        'param.version', 'param.cargo_distribucion', 'param.asignacion_catalogo', 'param.calendario_mes',
        'param.grupal', 'param.general', 'param.instituto', 'param.cargo_homologado',
        'core.persona', 'core.dotacion_mes', 'core.asignacion', 'core.excepcion_multi_it', 'core.cambios', 'core.alerta',
        'calc.plan_mes', 'calc.escenario', 'calc.plan_mes_escenario', 'calc.cuadratura', 'audit.log']) AS x LOOP
        IF to_regclass(r.x) IS NULL THEN faltan := faltan || ('tabla ' || r.x); END IF;
    END LOOP;

    IF cardinality(faltan) > 0 THEN
        RAISE EXCEPTION 'HUMO: faltan %', array_to_string(faltan, ', ');
    END IF;

    -- Contrato 1: columnas exactas y en orden
    FOR r IN SELECT * FROM (VALUES
        ('carga',            'carga_id,tipo,archivo,hash,recibido_en,estado,leidas,validas,con_error'),
        ('buk_fila',         'carga_id,it,instituto,persona_id,area,sub_area,centro_costo,periodo,tipo_contrato,tipo_trabajador,fecha_ingreso,fecha_termino,horas_semanales,cargo,dias_jornada,ndias,cod_esp'),
        ('error_fila',       'carga_id,fila,persona_id,campo,valor,motivo'),
        ('param_cargo',      'carga_id,cod_esp,cargo,unidad,min_directa,min_indirecta,tramo,pct_dir,pct_ind,pct_nas'),
        ('param_asignacion', 'carga_id,tipo,horas_semana,requiere_dmn,descripcion'),
        ('param_calendario', 'carga_id,mes,zona,dias,inhabiles,dias_habiles,semanas'),
        ('param_grupal',     'carga_id,cod_esp,grupo_it,pct_grupal,pacientes_grupo'),
        ('excepcion',        'carga_id,persona_id,it,mes,horas'),
        ('asignacion',       'carga_id,persona_id,it,tipo,horas,desde,hasta,solicitante,motivo,estado'),
        ('esperado',         'carga_id,persona_id,it,campo,mes,valor')
    ) AS t(tabla, esperado) LOOP
        SELECT string_agg(column_name, ',' ORDER BY ordinal_position) INTO real
        FROM information_schema.columns WHERE table_schema = 'stg' AND table_name = r.tabla;
        IF real IS DISTINCT FROM r.esperado THEN
            RAISE EXCEPTION 'HUMO: stg.% no calza con Contrato 1. Esperado: % | Real: %', r.tabla, r.esperado, real;
        END IF;
    END LOOP;

    -- calc.plan_mes con las columnas del cálculo
    SELECT string_agg(column_name, ',' ORDER BY ordinal_position) INTO real
    FROM information_schema.columns WHERE table_schema = 'calc' AND table_name = 'plan_mes';
    IF real IS DISTINCT FROM 'persona_id,it,mes,periodo,horas_contratadas,horas_dir,horas_ind,horas_nas,pct_dir_final,pct_ind_final,ate_dir_semana,ate_ind_semana,semanas_habiles,ate_dir,ate_dir_ind,meta,foja,version_param,calculado_en' THEN
        RAISE EXCEPTION 'HUMO: calc.plan_mes con columnas inesperadas: %', real;
    END IF;

    -- core.dotacion_mes tiene origen (proyección ago-dic)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'core' AND table_name = 'dotacion_mes' AND column_name = 'origen') THEN
        RAISE EXCEPTION 'HUMO: falta core.dotacion_mes.origen';
    END IF;

    -- bot_carga puede insertar en stg
    IF NOT has_table_privilege('bot_carga', 'stg.buk_fila', 'INSERT') THEN
        RAISE EXCEPTION 'HUMO: bot_carga sin INSERT en stg.buk_fila';
    END IF;

    RAISE NOTICE 'HUMO OK';
END
$$;
