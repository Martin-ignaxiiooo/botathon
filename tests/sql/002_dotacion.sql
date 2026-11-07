-- 002 · Dotación (B-04): cargar_dotacion, proyección ago-dic, alertas y calc.v_promedio_horas.
-- Parte 1 (solo si ya se cargó la base BUK real con scripts\cargar_buk_prueba.ps1): promedio vs Excel >= 95 %.
-- Parte 2: carga sintética dentro de una transacción que se revierte (corre también en CI).
DO $$
DECLARE v_total int; v_ok int;
BEGIN
    IF (SELECT count(*) FROM core.dotacion_mes WHERE origen = 'buk') < 3000 THEN
        RAISE NOTICE 'DOTACION: base BUK real no cargada; se omite la comparación con el Excel';
        RETURN;
    END IF;
    SELECT count(*), count(*) FILTER (WHERE e.valor = v.promedio_ponderado) INTO v_total, v_ok
    FROM calc.v_promedio_horas v
    JOIN stg.esperado e ON e.persona_id = v.persona_id AND e.it = v.it AND e.campo = 'prom_pond_horas';
    RAISE NOTICE 'DOTACION: promedio ponderado igual al Excel en % de % (% %%)', v_ok, v_total, round(100.0 * v_ok / v_total, 1);
    IF v_ok < 0.95 * v_total THEN
        RAISE EXCEPTION 'DOTACION: promedio ponderado calza solo en % de %', v_ok, v_total;
    END IF;
END
$$;

BEGIN;
DO $$
DECLARE
    v_carga bigint;
    r       record;
    v_n     int;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 002', 'test:002:' || clock_timestamp())
    RETURNING carga_id INTO v_carga;

    -- 900001: KINESIOLOGO IT 11, ene-abr 44 h, may-jul 42 h, sin término -> proyecta ago-dic
    INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, periodo, tipo_contrato, fecha_ingreso,
                              fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp)
    SELECT v_carga, 11, 'Ari', 900001, 'Arica', make_date(2026, m, 1), 'Indefinido', DATE '2020-01-01', NULL,
           CASE WHEN m <= 4 THEN 44 ELSE 42 END, 'KINESIOLOGO', 'lmwjv', 5, 'KI'
    FROM generate_series(1, 7) m;
    -- duplicado de marzo (debe generar alerta y quedarse con el de más horas)
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    VALUES (v_carga, 11, 900001, DATE '2026-03-01', 20, 'KINESIOLOGO', 'lm');
    -- 900002: PSICOLOGO IT 131, termina 2026-09-15 -> proyecta ago-sep; dias por ndias
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, area, periodo, fecha_termino, horas_semanales, cargo, dias_jornada, ndias)
    SELECT v_carga, 131, 900002, 'Santiago', make_date(2026, m, 1), DATE '2026-09-15', 22, 'psicologo ', NULL, 3
    FROM generate_series(1, 7) m;
    -- 900003: sale en mayo (no está en julio) -> no se proyecta
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_carga, 12, 900003, make_date(2026, m, 1), 40, 'ENFERMERA', 'lmwjv' FROM generate_series(1, 5) m;
    -- 900004: cargo inexistente -> alerta y se omite; 900005: horas 0 -> error de fila
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo)
    VALUES (v_carga, 21, 900004, DATE '2026-07-01', 40, 'CARGO INEXISTENTE'),
           (v_carga, 21, 900005, DATE '2026-07-01', 0, 'KINESIOLOGO');
    -- 900006: fecha de término anterior al ingreso -> error de fila
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo)
    VALUES (v_carga, 21, 900006, DATE '2026-07-01', DATE '2020-01-01', DATE '2015-03-31', 40, 'KINESIOLOGO');
    -- error que ya dejó el robot (fila ilegible que no llegó a stg.buk_fila)
    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    VALUES (v_carga, 99, 900007, 'horas_semanales', 'cuarenta', 'horas_semanales no es numérico'),
    -- el robot también marcó 900005 (horas 0) pero la fila llegó a stg.buk_fila: la base lo detecta igual y
    -- debe contarse UNA vez (ni en con_error ni en leidas se duplica)
           (v_carga, 98, 900005, 'horas_semanales', '0', 'horas_semanales debe ser mayor que cero');

    SELECT * INTO r FROM api.cargar_dotacion(v_carga);
    IF r.filas <> 19 THEN RAISE EXCEPTION 'DOTACION: filas = % (se esperan 19)', r.filas; END IF;
    IF r.alertas <> 2 THEN RAISE EXCEPTION 'DOTACION: alertas = % (se esperan 2: cargo y duplicado)', r.alertas; END IF;

    SELECT count(*) INTO v_n FROM core.alerta WHERE carga_id = v_carga AND tipo = 'cargo_sin_homologar' AND persona_id = 900004;
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: falta alerta de cargo sin homologar'; END IF;
    SELECT count(*) INTO v_n FROM stg.error_fila WHERE carga_id = v_carga AND persona_id = 900005
      AND motivo LIKE 'cargar_dotacion:%';
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: falta error de fila por horas 0'; END IF;
    SELECT count(*) INTO v_n FROM stg.error_fila WHERE carga_id = v_carga AND persona_id = 900006 AND campo = 'fecha_termino';
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: falta error de fila por fecha término < ingreso'; END IF;
    SELECT count(*) INTO v_n FROM stg.error_fila WHERE carga_id = v_carga AND persona_id = 900004 AND campo = 'cargo';
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: falta error de fila por cargo sin homologar'; END IF;
    SELECT count(*) INTO v_n FROM stg.error_fila WHERE carga_id = v_carga AND persona_id = 900001 AND campo = 'persona_id';
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: falta error de fila por duplicado'; END IF;
    -- conteos: 23 filas en stg + 1 rechazada por el robot (900007); 19 válidas; 5 con error
    -- (4 de la función + 1 del robot; el error del robot sobre 900005 repite uno de la función y no suma)
    SELECT leidas, validas, con_error INTO r FROM stg.carga WHERE carga_id = v_carga;
    IF r.leidas <> 24 OR r.validas <> 19 OR r.con_error <> 5 THEN
        RAISE EXCEPTION 'DOTACION: conteos de stg.carga leidas/validas/con_error = %/%/% (se esperan 24/19/5)', r.leidas, r.validas, r.con_error;
    END IF;

    -- Foto completa: solo quedan las personas de esta carga
    SELECT count(DISTINCT persona_id) INTO v_n FROM core.dotacion_mes;
    IF v_n <> 3 THEN RAISE EXCEPTION 'DOTACION: % personas en core.dotacion_mes (se esperan 3)', v_n; END IF;

    -- 900001: 7 reales + 5 proyectados a 42 h; marzo con 44 h (el duplicado de 20 h se descarta); 5 días
    SELECT count(*) FILTER (WHERE origen = 'buk'), count(*) FILTER (WHERE origen = 'proyectado' AND horas_semanales = 42)
    INTO r FROM core.dotacion_mes WHERE persona_id = 900001;
    IF r.count <> 7 THEN RAISE EXCEPTION 'DOTACION: 900001 con % meses reales', r.count; END IF;
    SELECT count(*) INTO v_n FROM core.dotacion_mes WHERE persona_id = 900001 AND origen = 'proyectado' AND horas_semanales = 42;
    IF v_n <> 5 THEN RAISE EXCEPTION 'DOTACION: 900001 con % meses proyectados a 42 h (se esperan 5)', v_n; END IF;
    SELECT count(*) INTO v_n FROM core.dotacion_mes
    WHERE persona_id = 900001 AND mes = 3 AND horas_semanales = 44 AND dias_semana = 5 AND cargo = 'KINESIOLOGO';
    IF v_n <> 1 THEN RAISE EXCEPTION 'DOTACION: 900001 marzo mal resuelto (duplicado/días/cargo)'; END IF;

    -- 900002: proyecta solo ago-sep; dias_semana desde ndias; cargo normalizado
    SELECT count(*) INTO v_n FROM core.dotacion_mes WHERE persona_id = 900002 AND origen = 'proyectado';
    IF v_n <> 2 THEN RAISE EXCEPTION 'DOTACION: 900002 con % meses proyectados (se esperan 2: ago-sep)', v_n; END IF;
    SELECT count(*) INTO v_n FROM core.dotacion_mes WHERE persona_id = 900002 AND dias_semana = 3 AND cargo = 'PSICOLOGO';
    IF v_n <> 9 THEN RAISE EXCEPTION 'DOTACION: 900002 sin dias por ndias o sin cargo homologado'; END IF;

    -- 900003: no se proyecta
    SELECT count(*) INTO v_n FROM core.dotacion_mes WHERE persona_id = 900003;
    IF v_n <> 5 THEN RAISE EXCEPTION 'DOTACION: 900003 con % meses (se esperan 5, sin proyección)', v_n; END IF;

    -- Promedio ponderado: (44*4 + 42*8) / 12 = 42,67 -> 42; flag disminucion
    SELECT * INTO r FROM calc.v_promedio_horas WHERE persona_id = 900001;
    IF r.promedio_ponderado <> 42 OR r.flag <> 'disminucion' OR r.meses <> 12 THEN
        RAISE EXCEPTION 'DOTACION: v_promedio_horas 900001 = % / % / % meses', r.promedio_ponderado, r.flag, r.meses;
    END IF;
    SELECT * INTO r FROM calc.v_promedio_horas WHERE persona_id = 900002;
    IF r.promedio_ponderado <> 22 OR r.flag <> 'sin_cambio' OR r.meses <> 9 THEN
        RAISE EXCEPTION 'DOTACION: v_promedio_horas 900002 = % / % / % meses', r.promedio_ponderado, r.flag, r.meses;
    END IF;

    -- Re-ejecutable con la misma carga
    SELECT * INTO r FROM api.cargar_dotacion(v_carga);
    IF r.filas <> 19 OR r.alertas <> 2 THEN RAISE EXCEPTION 'DOTACION: segunda ejecución distinta (% / %)', r.filas, r.alertas; END IF;

    RAISE NOTICE 'DOTACION OK';
END
$$;
ROLLBACK;
