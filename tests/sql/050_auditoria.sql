-- 050 · Auditoría con triggers (B-11): param.*, core.asignacion y calc.escenario -> audit.log
-- (sintético, corre en CI, ROLLBACK).
BEGIN;
DO $$
DECLARE v_log bigint; v_n int; v_id bigint; r record; t text;
BEGIN
    -- todas las tablas de param.* + core.asignacion + calc.escenario tienen el trigger
    FOR t IN SELECT c.oid::regclass::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE c.relkind = 'r' AND n.nspname = 'param'
             UNION ALL SELECT 'core.asignacion' UNION ALL SELECT 'calc.escenario' LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = t::regclass AND tgname = 'auditar') THEN
            RAISE EXCEPTION 'AUDITORIA: % sin trigger auditar', t;
        END IF;
    END LOOP;

    SELECT coalesce(max(log_id), 0) INTO v_log FROM audit.log;
    PERFORM set_config('planbot.motivo', 'prueba 050', true);

    -- param: insert, update real, update sin cambios (no se registra), delete
    INSERT INTO param.cuadratura_explicada (persona_id, it, nota) VALUES (900150, 11, 'a');
    UPDATE param.cuadratura_explicada SET nota = 'b' WHERE persona_id = 900150;
    UPDATE param.cuadratura_explicada SET nota = 'b' WHERE persona_id = 900150;
    DELETE FROM param.cuadratura_explicada WHERE persona_id = 900150;
    SELECT count(*) INTO v_n FROM audit.log WHERE log_id > v_log AND tabla = 'param.cuadratura_explicada';
    IF v_n <> 3 THEN RAISE EXCEPTION 'AUDITORIA param: % filas, se esperan 3 (insert, update, delete)', v_n; END IF;
    SELECT * INTO r FROM audit.log WHERE log_id > v_log AND tabla = 'param.cuadratura_explicada' AND operacion = 'update';
    IF r.antes ->> 'nota' <> 'a' OR r.despues ->> 'nota' <> 'b' OR r.motivo <> 'prueba 050' OR r.usuario <> session_user THEN
        RAISE EXCEPTION 'AUDITORIA param update: antes %, despues %, motivo %, usuario %', r.antes, r.despues, r.motivo, r.usuario;
    END IF;
    SELECT * INTO r FROM audit.log WHERE log_id > v_log AND tabla = 'param.cuadratura_explicada' AND operacion = 'delete';
    IF r.despues IS NOT NULL OR r.antes ->> 'persona_id' <> '900150' THEN RAISE EXCEPTION 'AUDITORIA param delete'; END IF;

    -- core.asignacion
    INSERT INTO core.asignacion (persona_id, it, tipo, horas) VALUES (900150, 11, 'Líder Equipo', 2) RETURNING asignacion_id INTO v_id;
    UPDATE core.asignacion SET horas = 3 WHERE asignacion_id = v_id;
    SELECT count(*) INTO v_n FROM audit.log WHERE log_id > v_log AND tabla = 'core.asignacion' AND motivo = 'prueba 050';
    IF v_n <> 2 THEN RAISE EXCEPTION 'AUDITORIA core.asignacion: % filas, se esperan 2', v_n; END IF;

    -- calc.escenario, sin motivo -> NULL
    PERFORM set_config('planbot.motivo', '', true);
    INSERT INTO calc.escenario (nombre) VALUES ('prueba 050') RETURNING escenario_id INTO v_id;
    UPDATE calc.escenario SET estado = 'descartado' WHERE escenario_id = v_id;
    SELECT count(*) INTO v_n FROM audit.log WHERE log_id > v_log AND tabla = 'calc.escenario' AND motivo IS NULL;
    IF v_n <> 2 THEN RAISE EXCEPTION 'AUDITORIA calc.escenario: % filas, se esperan 2 sin motivo', v_n; END IF;

    -- tablas no auditadas: calc.plan_mes (lo registra recalcular() con una sola fila, B-08)
    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'calc.plan_mes'::regclass AND tgname = 'auditar') THEN
        RAISE EXCEPTION 'AUDITORIA: calc.plan_mes no debe tener trigger fila a fila';
    END IF;
    -- nadie más que el dueño escribe directo en audit.log
    IF has_table_privilege('bot_carga', 'audit.log', 'INSERT') OR has_table_privilege('web_lectura', 'audit.log', 'INSERT')
       OR has_table_privilege('planificador', 'audit.log', 'INSERT') THEN
        RAISE EXCEPTION 'AUDITORIA: audit.log no debe ser escribible por roles de uso';
    END IF;
    RAISE NOTICE 'AUDITORIA OK (param insert/update/delete, update sin cambios omitido, asignacion, escenario, motivo)';
END
$$;
ROLLBACK;
