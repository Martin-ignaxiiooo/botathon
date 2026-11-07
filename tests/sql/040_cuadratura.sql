-- 040 · Cuadratura Excel vs sistema (B-10): api.cuadratura() -> calc.cuadratura / api.v_cuadratura.
-- Parte 1 (solo con la base BUK real cargada): % de coincidencia plan_ate_dir may-dic >= 95,5 % (nivel 95,55 %),
--   los 20 casos semanales de B-05 = 19 ajuste_individual + 134744/11 diferencia_explicada, vista poblada.
--   Deja calc.cuadratura calculada con la base real (la pantalla de cuadratura la lee).
-- Parte 2 (sintético, corre en CI, ROLLBACK): una diferencia por cada causa y el % devuelto.
DO $$
DECLARE v_pct numeric; v_n int;
BEGIN
    IF (SELECT count(*) FROM core.dotacion_mes WHERE origen = 'buk') < 3000
       OR NOT EXISTS (SELECT 1 FROM stg.esperado WHERE campo = 'plan_ate_dir') THEN
        RAISE NOTICE 'CUADRATURA: base BUK real o Excel no cargados; se omite la parte real';
        RETURN;
    END IF;
    PERFORM calc.calcular_plan(1);
    v_pct := api.cuadratura();
    RAISE NOTICE 'CUADRATURA real: plan_ate_dir may-dic % %% · % diferencias en api.v_cuadratura',
        v_pct, (SELECT count(*) FROM api.v_cuadratura);
    IF v_pct < 95.5 THEN RAISE EXCEPTION 'CUADRATURA: regresión, coincidencia % %% (< 95,5)', v_pct; END IF;
    IF NOT EXISTS (SELECT 1 FROM api.v_cuadratura) THEN RAISE EXCEPTION 'CUADRATURA: api.v_cuadratura vacía'; END IF;
    IF EXISTS (SELECT 1 FROM calc.cuadratura WHERE persona_id = 134744 AND it = 11 AND causa <> 'diferencia_explicada') THEN
        RAISE EXCEPTION 'CUADRATURA: 134744/11 debe quedar como diferencia_explicada';
    END IF;
    SELECT count(DISTINCT (persona_id, it)) INTO v_n FROM calc.cuadratura
    WHERE causa IN ('ajuste_individual', 'diferencia_explicada');
    IF v_n <> 20 THEN RAISE EXCEPTION 'CUADRATURA: se esperan 20 persona-IT con ajuste o explicadas, hay %', v_n; END IF;
END
$$;

BEGIN;
DO $$
DECLARE v_buk bigint; v_plan bigint; v_pct numeric; r record; v_n int;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 040', 'test:040:buk:' || clock_timestamp())
    RETURNING carga_id INTO v_buk;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, 11, p, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv'
    FROM unnest(ARRAY[900137, 900140, 900141, 900142]) p, generate_series(1, 12) m;
    PERFORM api.cargar_dotacion(v_buk);

    -- Excel con semhab 4,2 en todos los meses -> plan del sistema
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('planificacion', 'prueba 040', 'test:040:plan1:' || clock_timestamp())
    RETURNING carga_id INTO v_plan;
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor)
    SELECT v_plan, p, 11, 'semhab', m, 4.2 FROM unnest(ARRAY[900137, 900140, 900141, 900142]) p, generate_series(1, 12) m;
    PERFORM calc.calcular_plan(1);

    -- Nuevo Excel (última carga): copia exacta del sistema y luego una diferencia por causa
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('planificacion', 'prueba 040', 'test:040:plan2:' || clock_timestamp())
    RETURNING carga_id INTO v_plan;
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor)
    SELECT v_plan, p.persona_id, p.it, x.campo, p.mes, x.valor
    FROM calc.plan_mes p
    CROSS JOIN LATERAL (VALUES ('semhab', p.semanas_habiles), ('plan_ate_dir', p.ate_dir::numeric),
                               ('plan_ate_dir_ind', p.ate_dir_ind::numeric), ('meta', p.meta::numeric)) x(campo, valor)
    WHERE p.persona_id IN (900137, 900140, 900141, 900142);
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor)
    SELECT v_plan, s.persona_id, s.it, x.campo, NULL, x.valor
    FROM calc.v_semanal s
    CROSS JOIN LATERAL (VALUES ('ate_dir_semana', s.ate_dir_semana::numeric), ('ate_ind_semana', s.ate_ind_semana::numeric),
                               ('pct_dir_final', s.pct_dir_final + 1e-12)) x(campo, valor)   -- ruido de coma flotante
    WHERE s.periodo = 'may_dic' AND s.persona_id IN (900137, 900140, 900141, 900142);

    -- periodo_ene_abr: 900137 febrero
    UPDATE stg.esperado SET valor = valor + 5 WHERE carga_id = v_plan AND persona_id = 900137 AND campo = 'plan_ate_dir' AND mes = 2;
    -- dias_adicionales: 900137 junio con otras semanas hábiles en el Excel
    UPDATE stg.esperado SET valor = 4.0 WHERE carga_id = v_plan AND persona_id = 900137 AND campo = 'semhab' AND mes = 6;
    UPDATE stg.esperado SET valor = valor + 3 WHERE carga_id = v_plan AND persona_id = 900137 AND campo = 'plan_ate_dir' AND mes = 6;
    -- ajuste_individual: 900140 semanal distinto y julio distinto
    UPDATE stg.esperado SET valor = valor + 2 WHERE carga_id = v_plan AND persona_id = 900140 AND campo = 'ate_dir_semana';
    UPDATE stg.esperado SET valor = valor + 8 WHERE carga_id = v_plan AND persona_id = 900140 AND campo = 'plan_ate_dir' AND mes = 7;
    -- multi_it: 900141 aparece en el Excel también en IT 81 (mayo 50; junio 0 = coincide con "sin plan")
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor)
    VALUES (v_plan, 900141, 81, 'plan_ate_dir', 5, 50), (v_plan, 900141, 81, 'plan_ate_dir', 6, 0);
    -- diferencia_explicada: 900142 agosto, ya analizada
    INSERT INTO param.cuadratura_explicada (persona_id, it, nota) VALUES (900142, 11, 'prueba 040');
    UPDATE stg.esperado SET valor = valor + 1 WHERE carga_id = v_plan AND persona_id = 900142 AND campo = 'plan_ate_dir' AND mes = 8;
    -- otra: persona del Excel que no está en el BUK
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor) VALUES (v_plan, 999901, 11, 'plan_ate_dir', 5, 10);

    v_pct := api.cuadratura();
    -- may-dic con plan en el sistema: 4 personas × 8 meses = 32; difieren 900137/6, 900140/7, 900142/8
    IF v_pct <> round(100.0 * 29 / 32, 2) THEN RAISE EXCEPTION 'CUADRATURA: %% = %, se espera %', v_pct, round(100.0 * 29 / 32, 2); END IF;

    SELECT count(*) INTO v_n FROM api.v_cuadratura;
    IF v_n <> 8 THEN RAISE EXCEPTION 'CUADRATURA: % diferencias, se esperan 8', v_n; END IF;
    FOR r IN SELECT * FROM (VALUES
            (900137::bigint, 'plan_ate_dir', 2, 'periodo_ene_abr'),
            (900137, 'semhab', 6, 'dias_adicionales'),
            (900137, 'plan_ate_dir', 6, 'dias_adicionales'),
            (900140, 'ate_dir_semana', NULL, 'ajuste_individual'),
            (900140, 'plan_ate_dir', 7, 'ajuste_individual'),
            (900141, 'plan_ate_dir', 5, 'multi_it'),
            (900142, 'plan_ate_dir', 8, 'diferencia_explicada'),
            (999901, 'plan_ate_dir', 5, 'otra')) e(persona_id, campo, mes, causa)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM api.v_cuadratura v WHERE v.persona_id = r.persona_id AND v.campo = r.campo
                       AND v.mes IS NOT DISTINCT FROM r.mes::smallint AND v.causa = r.causa) THEN
            RAISE EXCEPTION 'CUADRATURA: falta % % mes % con causa %', r.persona_id, r.campo, r.mes, r.causa;
        END IF;
    END LOOP;
    SELECT * INTO r FROM api.v_cuadratura WHERE persona_id = 900140 AND campo = 'plan_ate_dir';
    IF r.diferencia <> -8 OR r.sistema - r.excel <> r.diferencia THEN
        RAISE EXCEPTION 'CUADRATURA: diferencia = sistema - excel (se espera -8, hay %)', r.diferencia;
    END IF;
    SELECT * INTO r FROM api.v_cuadratura WHERE persona_id = 999901;
    IF r.sistema IS NOT NULL THEN RAISE EXCEPTION 'CUADRATURA: sin plan el sistema debe ir NULL'; END IF;

    -- permisos
    IF NOT has_function_privilege('bot_carga', 'api.cuadratura()', 'EXECUTE')
       OR has_function_privilege('web_lectura', 'api.cuadratura()', 'EXECUTE')
       OR NOT has_table_privilege('web_lectura', 'api.v_cuadratura', 'SELECT') THEN
        RAISE EXCEPTION 'CUADRATURA: permisos incorrectos';
    END IF;
    RAISE NOTICE 'CUADRATURA sintética OK: % %%, 8 diferencias con sus causas', v_pct;
END
$$;
ROLLBACK;
