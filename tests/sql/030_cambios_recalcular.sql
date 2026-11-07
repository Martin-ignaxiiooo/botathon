-- 030 · B-07 detectar_cambios / mes_minimo_afectado y B-08 recalcular (sintético, corre en CI).
-- Dos cargas BUK dentro de una transacción que se revierte: A (original) y B (con un evento de cada tipo).
BEGIN;
DO $$
DECLARE v_a bigint; v_b bigint; v_c bigint; r record; v_n int; v_antes text; v_despues text; v_log bigint;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 030 A', 'test:030:a:' || clock_timestamp())
    RETURNING carga_id INTO v_a;
    -- Carga A: 6 personas ene-jul en IT 11 (KINESIOLOGO 44 h); 910006 termina en 2026-09-30
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada)
    SELECT v_a, 11, p, make_date(2026, m, 1), DATE '2020-01-01',
           CASE WHEN p = 910006 THEN DATE '2026-09-30' END, 44, 'KINESIOLOGO', 'lmwjv'
    FROM generate_series(910001, 910006) p, generate_series(1, 7) m;
    PERFORM api.cargar_dotacion(v_a);

    -- Primera comparación posible: A no tiene cambios contra la carga anterior (si existe) que importen aquí;
    -- B se compara contra A.
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 030 B', 'test:030:b:' || clock_timestamp())
    RETURNING carga_id INTO v_b;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada)
    SELECT v_b, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada
    FROM stg.buk_fila WHERE carga_id = v_a;
    UPDATE stg.buk_fila SET horas_semanales = 30 WHERE carga_id = v_b AND persona_id = 910001 AND periodo >= DATE '2026-05-01';  -- jornada desde 5
    UPDATE stg.buk_fila SET cargo = 'PSICOLOGO' WHERE carga_id = v_b AND persona_id = 910002 AND periodo >= DATE '2026-03-01'; -- cargo desde 3
    UPDATE stg.buk_fila SET it = 12 WHERE carga_id = v_b AND persona_id = 910003 AND periodo >= DATE '2026-07-01';             -- IT desde 7
    DELETE FROM stg.buk_fila WHERE carga_id = v_b AND persona_id = 910004 AND periodo >= DATE '2026-06-01';                    -- baja desde 6
    UPDATE stg.buk_fila SET fecha_termino = DATE '2026-08-31' WHERE carga_id = v_b AND persona_id = 910006;                    -- vigencia: 8
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, horas_semanales, cargo, dias_jornada)          -- alta desde 4
    SELECT v_b, 11, 910007, make_date(2026, m, 1), DATE '2026-04-01', 44, 'KINESIOLOGO', 'lmwjv' FROM generate_series(4, 7) m;
    PERFORM api.cargar_dotacion(v_b);

    CREATE TEMP TABLE t_cam ON COMMIT DROP AS SELECT * FROM api.detectar_cambios(v_b);
    SELECT count(*) INTO v_n FROM t_cam;
    IF v_n <> 6 THEN RAISE EXCEPTION 'CAMBIOS: % cambios (se esperan 6)', v_n; END IF;
    FOR r IN SELECT * FROM (VALUES ('cambio_jornada', 910001::bigint, 11, 5), ('cambio_cargo', 910002, 11, 3),
                                   ('cambio_it', 910003, 12, 7), ('baja', 910004, 11, 6),
                                   ('cambio_vigencia', 910006, 11, 8), ('alta', 910007, 11, 4)) e (tipo, persona_id, it, mes)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM t_cam c WHERE (c.tipo, c.persona_id, c.it, c.mes_vigencia) = (r.tipo, r.persona_id, r.it, r.mes)) THEN
            RAISE EXCEPTION 'CAMBIOS: falta % de % (IT %, mes %)', r.tipo, r.persona_id, r.it, r.mes;
        END IF;
    END LOOP;
    SELECT * INTO r FROM t_cam WHERE tipo = 'cambio_jornada';
    IF r.antes ->> 'horas_semanales' <> '44' OR r.despues ->> 'horas_semanales' <> '30' THEN
        RAISE EXCEPTION 'CAMBIOS: antes/despues de jornada = % / %', r.antes, r.despues;
    END IF;
    -- Re-ejecutable: no duplica en core.cambios
    PERFORM api.detectar_cambios(v_b);
    SELECT count(*) INTO v_n FROM core.cambios WHERE carga_id = v_b;
    IF v_n <> 6 THEN RAISE EXCEPTION 'CAMBIOS: % filas en core.cambios tras repetir (se esperan 6)', v_n; END IF;

    IF api.mes_minimo_afectado(v_b) <> 3 THEN
        RAISE EXCEPTION 'CAMBIOS: mes_minimo_afectado = % (se espera 3)', api.mes_minimo_afectado(v_b);
    END IF;
    -- Carga idéntica a la anterior: sin cambios -> NULL
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 030 C', 'test:030:c:' || clock_timestamp())
    RETURNING carga_id INTO v_c;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada)
    SELECT v_c, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada
    FROM stg.buk_fila WHERE carga_id = v_b;
    IF api.mes_minimo_afectado(v_c) IS NOT NULL THEN
        RAISE EXCEPTION 'CAMBIOS: carga sin cambios devuelve mes %', api.mes_minimo_afectado(v_c);
    END IF;

    -- B-08: recalcular desde el mes mínimo; meses anteriores intactos; audit.log con motivo
    PERFORM api.recalcular(1);
    SELECT string_agg(concat_ws('|', persona_id, it, mes, ate_dir, meta, foja, calculado_en), ';' ORDER BY persona_id, it, mes)
    INTO v_antes FROM calc.plan_mes WHERE mes < 3;
    PERFORM set_config('planbot.motivo', 'prueba 030', true);
    SELECT max(log_id) INTO v_log FROM audit.log;
    SELECT * INTO r FROM api.recalcular(api.mes_minimo_afectado(v_b));
    IF r.filas <= 0 OR r.ms < 0 OR r.ms > 10000 THEN RAISE EXCEPTION 'RECALCULAR: filas % ms %', r.filas, r.ms; END IF;
    SELECT string_agg(concat_ws('|', persona_id, it, mes, ate_dir, meta, foja, calculado_en), ';' ORDER BY persona_id, it, mes)
    INTO v_despues FROM calc.plan_mes WHERE mes < 3;
    IF v_antes IS DISTINCT FROM v_despues THEN RAISE EXCEPTION 'RECALCULAR: cambiaron los meses 1-2'; END IF;
    SELECT count(*) INTO v_n FROM audit.log
    WHERE log_id > v_log AND tabla = 'calc.plan_mes' AND operacion = 'recalcular' AND motivo = 'prueba 030'
      AND (despues ->> 'desde_mes')::int = 3 AND (despues ->> 'filas')::int = r.filas;
    IF v_n <> 1 THEN RAISE EXCEPTION 'RECALCULAR: falta registro en audit.log'; END IF;
    BEGIN
        PERFORM api.recalcular(13);
        RAISE EXCEPTION 'RECALCULAR: aceptó desde_mes 13';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM NOT LIKE 'recalcular: desde_mes%' THEN RAISE; END IF;
    END;

    -- Permisos del Contrato 2
    IF NOT has_function_privilege('bot_carga', 'api.detectar_cambios(bigint)', 'EXECUTE')
       OR NOT has_function_privilege('bot_carga', 'api.mes_minimo_afectado(bigint)', 'EXECUTE')
       OR NOT has_function_privilege('bot_carga', 'api.recalcular(int)', 'EXECUTE')
       OR has_function_privilege('web_lectura', 'api.recalcular(int)', 'EXECUTE') THEN
        RAISE EXCEPTION 'CAMBIOS: permisos EXECUTE incorrectos';
    END IF;
    RAISE NOTICE 'CAMBIOS/RECALCULAR OK (6 tipos, mes mínimo 3, sin cambios -> NULL, meses anteriores intactos, audit)';
END
$$;
ROLLBACK;
