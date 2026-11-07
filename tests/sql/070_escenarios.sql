-- 070 · Escenarios (B-12): simular, listar_escenarios, decidir_escenario, aplicar_escenario (sintético, ROLLBACK).
BEGIN;
DO $$
DECLARE v_buk bigint; v_e1 bigint; v_e2 bigint; v_n int; v_meta_antes bigint; v_ver int; v_ver_antes int;
        v_log bigint; r record; v_ok boolean;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 070', 'test:070:buk:' || clock_timestamp())
    RETURNING carga_id INTO v_buk;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, it, p, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv'
    FROM (VALUES (900170, 11), (900171, 131)) x(p, it), generate_series(1, 12) m;
    PERFORM api.cargar_dotacion(v_buk);
    PERFORM calc.calcular_plan(1);
    SELECT sum(meta) INTO v_meta_antes FROM calc.plan_mes;
    SELECT max(version) INTO v_ver_antes FROM param.version WHERE vigente_hasta IS NULL;

    INSERT INTO calc.escenario (nombre, descripcion, cambios) VALUES ('t070_meta', 'Meta 95 %', '{"general": {"meta": 0.95}}')
    RETURNING escenario_id INTO v_e1;
    INSERT INTO calc.escenario (nombre, cambios) VALUES ('t070_meta_b', '{"general": {"meta": 0.8}}')
    RETURNING escenario_id INTO v_e2;

    -- simular: devuelve diferencia por IT y área, no toca param ni plan_mes, guarda plan_mes_escenario e impacto
    SELECT count(*) INTO v_n FROM api.simular(v_e1);
    IF v_n < 2 THEN RAISE EXCEPTION 'ESCENARIOS: simular devolvió % filas (se esperan >= 2 IT)', v_n; END IF;
    IF (SELECT sum(meta) FROM calc.plan_mes) <> v_meta_antes
       OR (SELECT valor FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta') <> 0.9 THEN
        RAISE EXCEPTION 'ESCENARIOS: simular modificó el plan o los parámetros vigentes';
    END IF;
    SELECT count(*) INTO v_n FROM calc.plan_mes_escenario pe JOIN calc.plan_mes p USING (persona_id, it, mes)
    WHERE pe.escenario_id = v_e1 AND pe.ate_dir = p.ate_dir AND pe.meta = floor(pe.ate_dir * 0.95 + 1e-9);
    IF v_n <> (SELECT count(*) FROM calc.plan_mes) THEN
        RAISE EXCEPTION 'ESCENARIOS: plan_mes_escenario no es el plan con meta 0,95 (% de % filas)', v_n, (SELECT count(*) FROM calc.plan_mes);
    END IF;
    SELECT * INTO r FROM api.listar_escenarios() WHERE escenario_id = v_e1;
    IF r.estado <> 'pendiente' OR r.parametro <> 'param.general.meta' OR r.valor_actual <> '0.9'
       OR r.valor_propuesto <> '0.95' OR r.descripcion <> 'Meta 95 %' OR jsonb_typeof(r.impacto) <> 'array' THEN
        RAISE EXCEPTION 'ESCENARIOS: listar_escenarios devolvió %', row_to_json(r);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r.impacto) x WHERE (x ->> 'it')::int = 11
                   AND (x ->> 'meta_despues')::int - (x ->> 'meta_antes')::int = (x ->> 'diferencia_meta')::int
                   AND (x ->> 'diferencia_meta')::int > 0 AND x ? 'instituto' AND x ? 'atenciones_antes' AND x ? 'atenciones_despues') THEN
        RAISE EXCEPTION 'ESCENARIOS: impacto sin las claves del front o sin alza de meta: %', r.impacto;
    END IF;

    -- decidir: validaciones
    BEGIN PERFORM api.decidir_escenario(v_e1, 'aplicar', 'x'); v_ok := false;
    EXCEPTION WHEN raise_exception THEN v_ok := true; END;
    IF NOT v_ok THEN RAISE EXCEPTION 'ESCENARIOS: decidir aceptó una decisión inválida'; END IF;
    BEGIN PERFORM api.decidir_escenario(v_e1, 'aprobar', '  '); v_ok := false;
    EXCEPTION WHEN raise_exception THEN v_ok := true; END;
    IF NOT v_ok THEN RAISE EXCEPTION 'ESCENARIOS: decidir aceptó un motivo vacío'; END IF;
    BEGIN PERFORM api.aplicar_escenario(v_e1); v_ok := false;
    EXCEPTION WHEN raise_exception THEN v_ok := true; END;
    IF NOT v_ok THEN RAISE EXCEPTION 'ESCENARIOS: aplicar_escenario aceptó un escenario pendiente'; END IF;

    -- decidir: aprobar solo cambia el estado; el motivo queda en audit.log
    SELECT coalesce(max(log_id), 0) INTO v_log FROM audit.log;
    IF api.decidir_escenario(v_e1, 'aprobar', 'Motivo de prueba 070') <> 'aprobado' THEN RAISE EXCEPTION 'ESCENARIOS: aprobar'; END IF;
    IF (SELECT valor FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta') <> 0.9 THEN
        RAISE EXCEPTION 'ESCENARIOS: aprobar no debe aplicar los parámetros';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM audit.log WHERE log_id > v_log AND tabla = 'calc.escenario' AND operacion = 'update'
                   AND motivo = 'Motivo de prueba 070' AND despues ->> 'estado' = 'aprobado') THEN
        RAISE EXCEPTION 'ESCENARIOS: la decisión no quedó en audit.log con su motivo';
    END IF;
    SELECT * INTO r FROM api.listar_escenarios() WHERE escenario_id = v_e1;
    IF r.decision_motivo <> 'Motivo de prueba 070' THEN RAISE EXCEPTION 'ESCENARIOS: falta decision_motivo'; END IF;
    BEGIN PERFORM api.decidir_escenario(v_e1, 'rechazar', 'otra vez'); v_ok := false;
    EXCEPTION WHEN raise_exception THEN v_ok := true; END;
    IF NOT v_ok THEN RAISE EXCEPTION 'ESCENARIOS: se pudo decidir dos veces'; END IF;

    -- rechazar (sin simular, desde borrador)
    IF api.decidir_escenario(v_e2, 'rechazar', 'No') <> 'rechazado' THEN RAISE EXCEPTION 'ESCENARIOS: rechazar'; END IF;

    -- aplicar: versión nueva con meta 0,95, plan recalculado, estado aplicado
    v_ver := api.aplicar_escenario(v_e1);
    IF v_ver <= v_ver_antes OR (SELECT max(version) FROM param.version WHERE vigente_hasta IS NULL) <> v_ver
       OR (SELECT escenario_id FROM param.version WHERE version = v_ver) <> v_e1 THEN
        RAISE EXCEPTION 'ESCENARIOS: aplicar no dejó la versión % vigente', v_ver;
    END IF;
    IF (SELECT valor FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta') <> 0.95
       OR (SELECT count(*) FROM param.general WHERE vigente_hasta IS NULL) <> (SELECT count(*) FROM param.general WHERE version = v_ver_antes)
       OR (SELECT count(*) FROM param.cargo_distribucion WHERE vigente_hasta IS NULL AND version = v_ver) = 0 THEN
        RAISE EXCEPTION 'ESCENARIOS: la versión % no copia los parámetros con el cambio', v_ver;
    END IF;
    IF (SELECT sum(meta) FROM calc.plan_mes) <> (SELECT sum(meta) FROM calc.plan_mes_escenario WHERE escenario_id = v_e1) THEN
        RAISE EXCEPTION 'ESCENARIOS: el plan aplicado no es el simulado';
    END IF;
    IF (SELECT estado FROM calc.escenario WHERE escenario_id = v_e1) <> 'aplicado' THEN RAISE EXCEPTION 'ESCENARIOS: estado'; END IF;

    -- permisos: lectura a web_lectura; decidir solo planificador; simular/aplicar a bot_carga
    IF NOT has_function_privilege('web_lectura', 'api.listar_escenarios()', 'EXECUTE')
       OR has_function_privilege('web_lectura', 'api.decidir_escenario(bigint, text, text)', 'EXECUTE')
       OR has_function_privilege('bot_carga', 'api.decidir_escenario(bigint, text, text)', 'EXECUTE')
       OR NOT has_function_privilege('planificador', 'api.decidir_escenario(bigint, text, text)', 'EXECUTE')
       OR has_function_privilege('web_lectura', 'api.simular(bigint)', 'EXECUTE')
       OR NOT has_function_privilege('bot_carga', 'api.simular(bigint)', 'EXECUTE')
       OR NOT has_function_privilege('bot_carga', 'api.aplicar_escenario(bigint)', 'EXECUTE')
       OR has_function_privilege('planificador', 'api.aplicar_escenario(bigint)', 'EXECUTE') THEN
        RAISE EXCEPTION 'ESCENARIOS: permisos incorrectos';
    END IF;
    RAISE NOTICE 'ESCENARIOS OK (simular sin efectos, listar, decidir con motivo auditado, aplicar versión %, permisos)', v_ver;
END
$$;
ROLLBACK;
