-- B-09: contrato v1.1, lectura real con web_lectura e invariantes de agregación.
-- Ejecutar con owner_planbot/psql; todo fixture queda en ROLLBACK.
-- Datos sintéticos solo prueban las vistas: NO certifican el cálculo mensual B-06.
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    r record;
    reales text[];
    v_objeto regclass;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('v_kpi', ARRAY['atenciones_plan','meta','foja','horas_contratadas','dotacion','ultima_carga']),
        ('v_nacional_mes', ARRAY['mes','atenciones_dir','atenciones_ind','meta','horas_dir','horas_ind','horas_nas','foja']),
        ('v_instituto_area_mes', ARRAY['it','instituto','area','cargo','mes','atenciones_dir','meta','foja','dotacion','horas_contratadas','horas_dir','horas_ind','horas_nas']),
        ('v_profesional_mes', ARRAY['persona_id','it','cargo','area','mes','horas_contratadas','pct_dir_final','atenciones_dir','atenciones_dir_ind','meta','foja']),
        ('v_cambios', ARRAY['carga_id','tipo','persona_id','it','mes_vigencia','antes','despues','detectado_en']),
        ('v_errores_carga', ARRAY['carga_id','archivo','fila','persona_id','campo','motivo']),
        ('v_parametros_vigentes', ARRAY['tabla','clave','valor','version','vigente_desde']),
        ('v_cuadratura', ARRAY['persona_id','campo','mes','excel','sistema','diferencia','causa'])
    ) AS contrato(vista, columnas)
    LOOP
        v_objeto := to_regclass('api.' || r.vista);
        IF v_objeto IS NULL OR NOT EXISTS (
            SELECT 1 FROM pg_class WHERE oid=v_objeto AND relkind='v'
        ) THEN
            RAISE EXCEPTION 'VISTAS: falta vista api.%', r.vista;
        END IF;
        SELECT array_agg(attname::text ORDER BY attnum) INTO reales
        FROM pg_attribute WHERE attrelid=v_objeto AND attnum>0 AND NOT attisdropped;
        IF reales IS DISTINCT FROM r.columnas THEN
            RAISE EXCEPTION 'VISTAS: api.% columnas/orden %, esperado %', r.vista, reales, r.columnas;
        END IF;
        IF NOT has_schema_privilege('web_lectura','api','USAGE') OR
           NOT has_table_privilege('web_lectura',v_objeto,'SELECT') THEN
            RAISE EXCEPTION 'VISTAS: falta permiso web_lectura para api.%', r.vista;
        END IF;
    END LOOP;
    RAISE NOTICE 'VISTAS: 8 contratos exactos, orden v1.1 y permisos OK';
END $$;

DO $$
DECLARE
    fase int;
    v_persona bigint;
    v_it int;
    v_carga bigint;
    v_ate numeric; v_meta numeric; v_horas numeric;
    k record; a record; b record;
BEGIN
    -- Fase 1 verifica el estado recibido (vacío o B-06 real).
    -- Fase 2 agrega un fixture reversible: multi-IT, meses, NULL y denominador cero.
    FOR fase IN 1..2 LOOP
        IF EXISTS (SELECT 1 FROM calc.plan_mes) THEN
            SELECT sum(ate_dir) AS ate, sum(meta) AS meta, sum(horas_contratadas) AS horas
              INTO b FROM calc.plan_mes;
            SELECT atenciones_plan AS ate, meta, horas_contratadas AS horas INTO STRICT k FROM api.v_kpi;
            SELECT sum(atenciones_dir) AS ate, sum(meta) AS meta, sum(horas_contratadas) AS horas
              INTO a FROM api.v_instituto_area_mes;
            IF ROW(k.ate,k.meta,k.horas) IS DISTINCT FROM ROW(a.ate,a.meta,a.horas)
               OR ROW(k.ate,k.meta,k.horas) IS DISTINCT FROM ROW(b.ate,b.meta,b.horas) THEN
                RAISE EXCEPTION 'VISTAS: fase % totales plan % / KPI % / instituto %', fase,b,k,a;
            END IF;
            IF (SELECT count(*) FROM api.v_profesional_mes) <> (SELECT count(*) FROM calc.plan_mes) THEN
                RAISE EXCEPTION 'VISTAS: se perdieron o multiplicaron filas del plan';
            END IF;
            IF (SELECT dotacion FROM api.v_kpi) IS DISTINCT FROM (
                SELECT count(DISTINCT persona_id) FROM calc.plan_mes
                WHERE mes=(SELECT max(mes) FROM calc.plan_mes)
            ) THEN
                RAISE EXCEPTION 'VISTAS: dotación nacional debe contar personas del último mes';
            END IF;
            IF (SELECT foja FROM api.v_kpi) IS DISTINCT FROM (
                SELECT sum(horas_dir)/nullif(sum(horas_contratadas),0) FROM calc.plan_mes
            ) THEN
                RAISE EXCEPTION 'VISTAS: FOJA nacional debe ser cociente de sumas';
            END IF;
            RAISE NOTICE 'VISTAS fase %: plan con % filas, totales KPI/instituto/plan iguales',
                fase, (SELECT count(*) FROM calc.plan_mes);
        ELSE
            IF EXISTS (SELECT 1 FROM api.v_kpi) OR EXISTS (SELECT 1 FROM api.v_nacional_mes)
               OR EXISTS (SELECT 1 FROM api.v_instituto_area_mes)
               OR EXISTS (SELECT 1 FROM api.v_profesional_mes) THEN
                RAISE EXCEPTION 'VISTAS: hay filas de planificación sin calc.plan_mes';
            END IF;
            RAISE NOTICE 'VISTAS fase %: plan vacío, cuatro vistas de planificación vacías OK', fase;
        END IF;

        IF fase=1 THEN
            SELECT least(coalesce((SELECT min(persona_id) FROM core.persona),0),
                         coalesce((SELECT min(persona_id) FROM calc.plan_mes),0))-2 INTO v_persona;
            SELECT least(coalesce((SELECT min(it) FROM param.instituto),0),
                         coalesce((SELECT min(it) FROM core.dotacion_mes),0),
                         coalesce((SELECT min(it) FROM calc.plan_mes),0))-2 INTO v_it;
            INSERT INTO param.instituto(it,nombre) VALUES(v_it,'Ensayo B09 A'),(v_it+1,'Ensayo B09 B');
            INSERT INTO stg.carga(tipo,archivo,hash,estado)
            VALUES('buk','fixture_b09.xlsx','b09:' || txid_current(),'cargada') RETURNING carga_id INTO v_carga;
            INSERT INTO core.persona(persona_id) VALUES(v_persona),(v_persona+1);
            INSERT INTO core.dotacion_mes(persona_id,it,mes,horas_semanales,cargo,area,carga_id)
            VALUES(v_persona,v_it,5,10,'Cargo A','Area A',v_carga),
                  (v_persona,v_it+1,5,30,'Cargo B','Area B',v_carga);
            INSERT INTO calc.plan_mes(persona_id,it,mes,periodo,horas_contratadas,
                horas_dir,horas_ind,horas_nas,pct_dir_final,ate_dir,ate_dir_ind,meta,foja)
            VALUES(v_persona,v_it,5,'may_dic',10,2,3,5,0.2,10,14,9,0.2),
                  (v_persona,v_it+1,5,'may_dic',30,18,6,6,0.6,30,36,27,0.6),
                  (v_persona+1,v_it,6,'may_dic',0,0,0,0,NULL,0,0,0,NULL),
                  (v_persona+1,v_it,5,'may_dic',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
            -- Dos planes sin core.dotacion_mes: deben conservarse con dimensiones NULL.
            SELECT sum(atenciones_dir),sum(meta),sum(horas_contratadas)
                INTO v_ate,v_meta,v_horas FROM api.v_instituto_area_mes WHERE it IN(v_it,v_it+1);
            IF ROW(v_ate,v_meta,v_horas) IS DISTINCT FROM ROW(40::numeric,36::numeric,40::numeric) THEN
                RAISE EXCEPTION 'VISTAS: fixture perdió o multiplicó valores';
            END IF;
            IF (SELECT foja FROM api.v_instituto_area_mes WHERE it=v_it AND mes=6) IS NOT NULL THEN
                RAISE EXCEPTION 'VISTAS: FOJA con denominador cero debe ser NULL';
            END IF;
            IF (SELECT foja FROM api.v_instituto_area_mes WHERE it=v_it AND mes=5 AND cargo='Cargo A') <> 0.2 THEN
                RAISE EXCEPTION 'VISTAS: FOJA no corresponde a horas directas/contratadas';
            END IF;
            IF (SELECT ultima_carga FROM api.v_kpi) IS NULL THEN
                RAISE EXCEPTION 'VISTAS: no se enlaza la carga fuente';
            END IF;
        END IF;
    END LOOP;
END $$;

-- SELECT real con el rol de PostgREST; no basta con comprobar el GRANT.
-- En PG16 CREATEROLE no permite SET ROLE automáticamente. Membresía de prueba
-- transaccional para el ejecutor; NO otorga SELECT adicional a web_lectura y
-- desaparece con el ROLLBACK final, junto con los fixtures.
GRANT web_lectura TO CURRENT_USER;
SET LOCAL ROLE web_lectura;
DO $$
DECLARE v text;
BEGIN
    FOREACH v IN ARRAY ARRAY['v_kpi','v_nacional_mes','v_instituto_area_mes','v_profesional_mes',
                            'v_cambios','v_errores_carga','v_parametros_vigentes','v_cuadratura'] LOOP
        EXECUTE format('SELECT * FROM api.%I LIMIT 1',v);
    END LOOP;
    RAISE NOTICE 'VISTAS: lectura real de las ocho vistas como % OK',current_user;
END $$;
RESET ROLE;
ROLLBACK;
