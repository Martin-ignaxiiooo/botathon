-- 090 · Correcciones del front (sintético, ROLLBACK):
--   1. area sigue al IT: un traslado de IT cuya fila trae la area (sede) del IT anterior queda con la del IT nuevo,
--      también en los meses proyectados, y deja la alerta area_distinta_it.
--   2. recalcular() rehace la cuadratura: api.v_cuadratura no conserva diferencias del plan anterior.
BEGIN;
DO $$
DECLARE v_buk bigint; v_plan bigint; r record; v_n int; v_log bigint;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 090', 'test:090:buk:' || clock_timestamp())
    RETURNING carga_id INTO v_buk;
    -- 900190 y 900191 viven en IT 11 (Sede Norte) y IT 131 (Sede Centro); 900192 se traslada de 131 a 11 en julio
    -- pero el BUK le deja la area 'Sede Centro'
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, area, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, x.it, x.p, x.area, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv'
    FROM (VALUES (11, 900190, 'Sede Norte'), (131, 900191, 'Sede Centro')) x(it, p, area), generate_series(1, 7) m;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, area, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, CASE WHEN m >= 7 THEN 11 ELSE 131 END, 900192, 'Sede Centro', make_date(2026, m, 1), 40,
           'MEDICO FISIATRA', 'lmwjv'
    FROM generate_series(1, 7) m;
    PERFORM api.cargar_dotacion(v_buk);

    SELECT count(*) INTO v_n FROM core.dotacion_mes WHERE persona_id = 900192 AND it = 11 AND area = 'Sede Norte';
    IF v_n <> 6 THEN RAISE EXCEPTION 'AREA: 900192 en IT 11 debe quedar en Sede Norte jul-dic (6 meses), hay %', v_n; END IF;
    IF EXISTS (SELECT 1 FROM core.dotacion_mes WHERE persona_id = 900192 AND it = 131 AND area <> 'Sede Centro') THEN
        RAISE EXCEPTION 'AREA: los meses en IT 131 deben seguir en Sede Centro';
    END IF;
    SELECT * INTO r FROM core.alerta WHERE carga_id = v_buk AND tipo = 'area_distinta_it';
    IF r.persona_id IS DISTINCT FROM 900192 OR r.it <> 11 OR r.detalle ->> 'area_buk' <> 'Sede Centro'
       OR r.detalle ->> 'area_usada' <> 'Sede Norte' THEN
        RAISE EXCEPTION 'AREA: falta la alerta area_distinta_it de 900192 (%)', row_to_json(r);
    END IF;

    -- 2. cuadratura vieja + recalcular -> se rehace
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('planificacion', 'prueba 090', 'test:090:plan:' || clock_timestamp())
    RETURNING carga_id INTO v_plan;
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor) VALUES (v_plan, 900190, 11, 'plan_ate_dir', 5, 1);
    DELETE FROM calc.cuadratura;
    INSERT INTO calc.cuadratura (persona_id, it, campo, mes, excel, sistema, diferencia, causa)
    VALUES (123, 11, 'plan_ate_dir', 5, 1, 2, 1, 'otra');      -- diferencia vieja de un plan anterior
    SELECT coalesce(max(log_id), 0) INTO v_log FROM audit.log;
    PERFORM api.recalcular(1);
    IF EXISTS (SELECT 1 FROM api.v_cuadratura WHERE persona_id = 123) THEN
        RAISE EXCEPTION 'CUADRATURA: recalcular dejó diferencias del plan anterior';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM api.v_cuadratura WHERE persona_id = 900190 AND campo = 'plan_ate_dir' AND mes = 5) THEN
        RAISE EXCEPTION 'CUADRATURA: recalcular no rehizo la cuadratura con el plan nuevo';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM audit.log WHERE log_id > v_log AND operacion = 'recalcular' AND despues ? 'cuadratura_pct') THEN
        RAISE EXCEPTION 'CUADRATURA: audit.log de recalcular sin cuadratura_pct';
    END IF;
    RAISE NOTICE 'AREA/CUADRATURA OK (area sigue al IT con alerta; recalcular rehace la cuadratura)';
END
$$;
ROLLBACK;
