-- B-12 · Escenarios de parámetros (Contrato 2: simular P08, aplicar_escenario P09) + listar_escenarios() y
-- decidir_escenario() para la pantalla Parámetros del front (C-09).
-- Flujo: borrador -> simular() -> pendiente -> decidir_escenario() -> aprobado | rechazado -> aplicar_escenario() -> aplicado
-- calc.escenario.cambios = {"general": {"<clave de param.general>": <valor propuesto>, ...}} (MVP: solo param.general).

-- ---------------------------------------------------------------------------------------------------------------
-- simular(escenario_id): recalcula el plan completo con los valores propuestos SIN tocar param.* ni calc.plan_mes
-- (se aplican dentro de un subbloque que se deshace) y guarda el resultado en calc.plan_mes_escenario.
-- Deja en calc.escenario el impacto por instituto y el estado 'pendiente'. Devuelve la diferencia por IT y área.
CREATE OR REPLACE FUNCTION api.simular(p_escenario_id bigint)
RETURNS TABLE (it int, area text, atenciones_antes bigint, atenciones_despues bigint,
               meta_antes bigint, meta_despues bigint, diferencia_meta bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
#variable_conflict use_column
DECLARE
    v_e      calc.escenario;
    v_filas  calc.plan_mes[];
    v_clave  text;
    v_valor  jsonb;
    v_base   int;
BEGIN
    SELECT * INTO v_e FROM calc.escenario e WHERE e.escenario_id = p_escenario_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'simular: no existe el escenario %', p_escenario_id; END IF;
    IF v_e.estado NOT IN ('borrador', 'pendiente') THEN
        RAISE EXCEPTION 'simular: el escenario % está %, solo se simula en borrador o pendiente', p_escenario_id, v_e.estado;
    END IF;
    IF jsonb_typeof(v_e.cambios -> 'general') IS DISTINCT FROM 'object' OR v_e.cambios -> 'general' = '{}'::jsonb THEN
        RAISE EXCEPTION 'simular: el escenario % no trae cambios {"general": {clave: valor}}', p_escenario_id;
    END IF;
    FOR v_clave, v_valor IN SELECT key, value FROM jsonb_each(v_e.cambios -> 'general') LOOP
        IF NOT EXISTS (SELECT 1 FROM param.general g WHERE g.vigente_hasta IS NULL AND g.clave = v_clave) THEN
            RAISE EXCEPTION 'simular: la clave % no existe en param.general vigente', v_clave;
        END IF;
        IF jsonb_typeof(v_valor) <> 'number' AND (v_valor #>> '{}') !~ '^-?[0-9]+(\.[0-9]+)?$' THEN
            RAISE EXCEPTION 'simular: el valor de % no es numérico (%)', v_clave, v_valor;
        END IF;
    END LOOP;
    SELECT max(g.version) INTO v_base FROM param.general g WHERE g.vigente_hasta IS NULL;

    BEGIN   -- subbloque: se aplican los cambios, se calcula y se deshace todo (las variables sobreviven)
        FOR v_clave, v_valor IN SELECT key, value FROM jsonb_each(v_e.cambios -> 'general') LOOP
            UPDATE param.general g SET valor = (v_valor #>> '{}')::numeric WHERE g.vigente_hasta IS NULL AND g.clave = v_clave;
        END LOOP;
        PERFORM calc.calcular_plan(1);
        SELECT array_agg(p) INTO v_filas FROM calc.plan_mes p;
        RAISE EXCEPTION USING ERRCODE = 'PB001', MESSAGE = 'deshacer simulación';
    EXCEPTION WHEN SQLSTATE 'PB001' THEN NULL;
    END;

    DELETE FROM calc.plan_mes_escenario pe WHERE pe.escenario_id = p_escenario_id;
    INSERT INTO calc.plan_mes_escenario SELECT p_escenario_id, f.* FROM unnest(v_filas) f;

    IF coalesce(current_setting('planbot.motivo', true), '') = '' THEN
        PERFORM set_config('planbot.motivo', format('simular escenario %s', p_escenario_id), true);
    END IF;
    UPDATE calc.escenario e SET
        estado = 'pendiente', simulado_en = now(), version_base = v_base,
        impacto = (
            SELECT coalesce(jsonb_agg(jsonb_build_object(
                       'it', x.it, 'instituto', coalesce(i.nombre, x.it::text),
                       'atenciones_antes', x.aa, 'atenciones_despues', x.ad,
                       'meta_antes', x.ma, 'meta_despues', x.md, 'diferencia_meta', x.md - x.ma) ORDER BY x.it), '[]'::jsonb)
            FROM (SELECT coalesce(a.it, d.it) AS it, coalesce(a.ate, 0) AS aa, coalesce(d.ate, 0) AS ad,
                         coalesce(a.meta, 0) AS ma, coalesce(d.meta, 0) AS md
                  FROM (SELECT p.it, sum(p.ate_dir) ate, sum(p.meta) meta FROM calc.plan_mes p GROUP BY p.it) a
                  FULL JOIN (SELECT pe.it, sum(pe.ate_dir) ate, sum(pe.meta) meta FROM calc.plan_mes_escenario pe
                             WHERE pe.escenario_id = p_escenario_id GROUP BY pe.it) d ON d.it = a.it) x
            LEFT JOIN param.instituto i ON i.it = x.it)
    WHERE e.escenario_id = p_escenario_id;

    RETURN QUERY
    WITH a AS (SELECT p.it, dm.area, sum(p.ate_dir) ate, sum(p.meta) meta
               FROM calc.plan_mes p LEFT JOIN core.dotacion_mes dm USING (persona_id, it, mes) GROUP BY 1, 2),
         d AS (SELECT pe.it, dm.area, sum(pe.ate_dir) ate, sum(pe.meta) meta
               FROM calc.plan_mes_escenario pe LEFT JOIN core.dotacion_mes dm USING (persona_id, it, mes)
               WHERE pe.escenario_id = p_escenario_id GROUP BY 1, 2)
    SELECT coalesce(a.it, d.it), coalesce(a.area, d.area),
           coalesce(a.ate, 0)::bigint, coalesce(d.ate, 0)::bigint, coalesce(a.meta, 0)::bigint, coalesce(d.meta, 0)::bigint,
           (coalesce(d.meta, 0) - coalesce(a.meta, 0))::bigint
    FROM a FULL JOIN d ON d.it = a.it AND d.area IS NOT DISTINCT FROM a.area
    ORDER BY 1, 2;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- aplicar_escenario(escenario_id): solo 'aprobado'. Crea una versión nueva de param.* (copia de la vigente con los
-- cambios del escenario en param.general), cierra la anterior, recalcula el plan desde enero y marca 'aplicado'.
-- Devuelve la versión creada. Lo llama Blue Prism (P09).
CREATE OR REPLACE FUNCTION api.aplicar_escenario(p_escenario_id bigint) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_e     calc.escenario;
    v_hoy   date := current_date;
    v_nueva int;
    v_tabla text;
    v_clave text;
    v_valor jsonb;
BEGIN
    SELECT * INTO v_e FROM calc.escenario e WHERE e.escenario_id = p_escenario_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'aplicar_escenario: no existe el escenario %', p_escenario_id; END IF;
    IF v_e.estado <> 'aprobado' THEN
        RAISE EXCEPTION 'aplicar_escenario: el escenario % está %, solo se aplica uno aprobado', p_escenario_id, v_e.estado;
    END IF;
    IF coalesce(current_setting('planbot.motivo', true), '') = '' THEN
        PERFORM set_config('planbot.motivo', format('aplicar escenario %s: %s', p_escenario_id, v_e.nombre), true);
    END IF;

    INSERT INTO param.version (escenario_id, descripcion, vigente_desde)
    VALUES (p_escenario_id, format('Escenario %s: %s', p_escenario_id, v_e.nombre), v_hoy)
    RETURNING version INTO v_nueva;

    FOREACH v_tabla IN ARRAY ARRAY['param.cargo_distribucion', 'param.calendario_mes', 'param.grupal', 'param.general'] LOOP
        EXECUTE format(
            'INSERT INTO %1$s SELECT (jsonb_populate_record(NULL::%1$s, to_jsonb(t) || jsonb_build_object('
            '''version'', $1, ''vigente_desde'', $2, ''vigente_hasta'', NULL))).* FROM %1$s t WHERE t.vigente_hasta IS NULL',
            v_tabla) USING v_nueva, v_hoy;
        EXECUTE format('UPDATE %s SET vigente_hasta = $1 WHERE vigente_hasta IS NULL AND version <> $2', v_tabla)
            USING v_hoy, v_nueva;
    END LOOP;
    INSERT INTO param.asignacion_catalogo (version, vigente_desde, tipo, horas_semana, requiere_dmn, descripcion)
    SELECT v_nueva, v_hoy, tipo, horas_semana, requiere_dmn, descripcion FROM param.asignacion_catalogo
    WHERE vigente_hasta IS NULL;
    UPDATE param.asignacion_catalogo SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL AND version <> v_nueva;
    UPDATE param.version SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL AND version <> v_nueva;

    FOR v_clave, v_valor IN SELECT key, value FROM jsonb_each(coalesce(v_e.cambios -> 'general', '{}'::jsonb)) LOOP
        UPDATE param.general SET valor = (v_valor #>> '{}')::numeric WHERE version = v_nueva AND clave = v_clave;
        IF NOT FOUND THEN RAISE EXCEPTION 'aplicar_escenario: la clave % no existe en param.general', v_clave; END IF;
    END LOOP;

    UPDATE calc.escenario SET estado = 'aplicado', version_creada = v_nueva, aplicado_en = now()
    WHERE escenario_id = p_escenario_id;
    PERFORM * FROM api.recalcular(1);
    RETURN v_nueva;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- listar_escenarios(): una fila por escenario con las columnas que espera el front (docs\progreso-front.md, C-09).
-- valor_actual = valor en la versión sobre la que se simuló (o la vigente si aún no se simula).
CREATE OR REPLACE FUNCTION api.listar_escenarios()
RETURNS TABLE (escenario_id bigint, descripcion text, parametro text, valor_actual text, valor_propuesto text,
               estado text, creado_por text, creado_en timestamptz, decision_motivo text, impacto jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$
    SELECT e.escenario_id, coalesce(e.descripcion, e.nombre),
           c.parametro, c.valor_actual, c.valor_propuesto,
           e.estado, e.creado_por, e.creado_en, e.decision_motivo, coalesce(e.impacto, '[]'::jsonb)
    FROM calc.escenario e
    LEFT JOIN LATERAL (
        SELECT string_agg('param.general.' || k.key, ', ' ORDER BY k.key) AS parametro,
               string_agg(coalesce(g.valor::text, '—'), ', ' ORDER BY k.key) AS valor_actual,
               string_agg(k.value #>> '{}', ', ' ORDER BY k.key) AS valor_propuesto
        FROM jsonb_each(CASE WHEN jsonb_typeof(e.cambios -> 'general') = 'object' THEN e.cambios -> 'general'
                             ELSE '{}'::jsonb END) k
        LEFT JOIN param.general g ON g.clave = k.key
             AND g.version = coalesce(e.version_base, (SELECT max(version) FROM param.general WHERE vigente_hasta IS NULL))
    ) c ON true
    ORDER BY e.creado_en DESC, e.escenario_id DESC
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- decidir_escenario(escenario_id, decision, motivo): decision 'aprobar' | 'rechazar' sobre un escenario pendiente o
-- borrador. Fija planbot.motivo con el motivo (queda en audit.log por el trigger de calc.escenario, B-11).
-- Aprobar SOLO cambia el estado: aplicar_escenario() lo llama Blue Prism. Devuelve el estado nuevo.
-- Parámetros sin prefijo p_ porque PostgREST los recibe por nombre: {"escenario_id", "decision", "motivo"}.
CREATE OR REPLACE FUNCTION api.decidir_escenario(escenario_id bigint, decision text, motivo text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
#variable_conflict use_column
DECLARE
    v_estado text;
    v_nuevo  text;
BEGIN
    IF decidir_escenario.decision NOT IN ('aprobar', 'rechazar') OR decidir_escenario.decision IS NULL THEN
        RAISE EXCEPTION 'decidir_escenario: la decisión debe ser aprobar o rechazar';
    END IF;
    IF coalesce(btrim(decidir_escenario.motivo), '') = '' THEN
        RAISE EXCEPTION 'decidir_escenario: falta el motivo';
    END IF;
    SELECT e.estado INTO v_estado FROM calc.escenario e WHERE e.escenario_id = decidir_escenario.escenario_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'decidir_escenario: no existe el escenario %', decidir_escenario.escenario_id; END IF;
    IF v_estado NOT IN ('pendiente', 'borrador') THEN
        RAISE EXCEPTION 'decidir_escenario: el escenario % ya está %', decidir_escenario.escenario_id, v_estado;
    END IF;
    v_nuevo := CASE decidir_escenario.decision WHEN 'aprobar' THEN 'aprobado' ELSE 'rechazado' END;
    PERFORM set_config('planbot.motivo', btrim(decidir_escenario.motivo), true);
    UPDATE calc.escenario e SET
        estado = v_nuevo, decision_motivo = btrim(decidir_escenario.motivo), decidido_por = session_user,
        decidido_en = now(), aprobado_en = CASE WHEN v_nuevo = 'aprobado' THEN now() END
    WHERE e.escenario_id = decidir_escenario.escenario_id;
    RETURN v_nuevo;
END $$;

REVOKE ALL ON FUNCTION api.simular(bigint), api.aplicar_escenario(bigint), api.listar_escenarios(),
                       api.decidir_escenario(bigint, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.listar_escenarios() TO web_lectura, planificador, bot_carga;
GRANT EXECUTE ON FUNCTION api.simular(bigint) TO bot_carga, planificador;
GRANT EXECUTE ON FUNCTION api.aplicar_escenario(bigint) TO bot_carga;
GRANT EXECUTE ON FUNCTION api.decidir_escenario(bigint, text, text) TO planificador;
