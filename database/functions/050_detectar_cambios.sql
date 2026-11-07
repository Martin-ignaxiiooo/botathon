-- B-07 · Detección de cambios entre una carga BUK y la carga BUK anterior (Contrato 2).
-- Reglas (docs\progreso-back.md):
--   * Se compara contra la carga 'buk' anterior con filas en stg.buk_fila (mayor carga_id < p_carga_id).
--     Sin carga anterior no hay cambios (primera carga).
--   * Filas válidas: persona_id, it y periodo presentes y horas > 0; duplicado (persona, it, mes) -> la de más horas
--     (igual que cargar_dotacion). Solo meses reales del BUK (no se comparan meses proyectados).
--   * cambio_jornada / cambio_cargo: solo en (persona_id, it, mes) presentes en AMBAS cargas; mes_vigencia = primer
--     mes con diferencia; antes/despues = valores de ese mes.
--   * cambio_it: la persona está en el mismo mes en ambas cargas pero en otro IT; it = IT nuevo.
--   * alta: persona que no estaba en la carga anterior (en ningún IT); mes_vigencia = su primer mes.
--   * baja: persona-IT que pierde meses al final (o desaparece) y no se explica por un cambio_it;
--     mes_vigencia = primer mes que ya no viene.
--   * cambio_vigencia: cambia fecha_ingreso o fecha_termino en el último mes común; mes_vigencia = mes de la fecha
--     más temprana entre la anterior y la nueva (acotado a 1-12).
-- Reemplaza los cambios ya registrados de esa carga (re-ejecutable) y los devuelve.
CREATE OR REPLACE FUNCTION core.f_buk_filas(p_carga_id bigint)
RETURNS TABLE (persona_id bigint, it int, mes int, horas numeric, cargo text, fecha_ingreso date, fecha_termino date,
               anio int)
LANGUAGE sql STABLE
SET search_path = pg_catalog, public
AS $$
    SELECT DISTINCT ON (b.persona_id, b.it, extract(month FROM b.periodo)::int)
           b.persona_id, b.it, extract(month FROM b.periodo)::int, b.horas_semanales,
           upper(trim(b.cargo)), b.fecha_ingreso, b.fecha_termino, extract(year FROM b.periodo)::int
    FROM stg.buk_fila b
    -- mismas filas válidas que cargar_dotacion: un error de la carga (cargo sin homologar, fechas incoherentes)
    -- no es un cambio de la persona
    JOIN param.cargo_homologado h ON upper(h.cargo_origen) = upper(regexp_replace(trim(b.cargo), '\s+', ' ', 'g'))
    WHERE b.carga_id = p_carga_id AND b.persona_id IS NOT NULL AND b.it IS NOT NULL AND b.periodo IS NOT NULL
      AND b.horas_semanales > 0 AND NOT coalesce(b.fecha_termino < b.fecha_ingreso, false)
    ORDER BY b.persona_id, b.it, extract(month FROM b.periodo)::int, b.horas_semanales DESC
$$;

CREATE OR REPLACE FUNCTION api.detectar_cambios(p_carga_id bigint)
RETURNS TABLE (tipo text, persona_id bigint, it int, mes_vigencia int, antes jsonb, despues jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
    v_ant bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stg.carga c WHERE c.carga_id = p_carga_id AND c.tipo = 'buk') THEN
        RAISE EXCEPTION 'detectar_cambios: la carga % no existe o no es tipo buk', p_carga_id;
    END IF;
    SELECT max(c.carga_id) INTO v_ant
    FROM stg.carga c
    WHERE c.tipo = 'buk' AND c.carga_id < p_carga_id
      AND EXISTS (SELECT 1 FROM stg.buk_fila b WHERE b.carga_id = c.carga_id);

    DELETE FROM core.cambios c WHERE c.carga_id = p_carga_id;

    IF v_ant IS NOT NULL THEN
        INSERT INTO core.cambios (carga_id, carga_anterior, tipo, persona_id, it, mes_vigencia, antes, despues)
        WITH o AS (SELECT * FROM core.f_buk_filas(v_ant)),
             n AS (SELECT * FROM core.f_buk_filas(p_carga_id)),
        comun AS (
            SELECT o.persona_id, o.it, o.mes, o.horas AS h_o, n.horas AS h_n, o.cargo AS c_o, n.cargo AS c_n,
                   o.fecha_ingreso AS fi_o, n.fecha_ingreso AS fi_n, o.fecha_termino AS ft_o, n.fecha_termino AS ft_n, o.anio
            FROM o JOIN n USING (persona_id, it, mes)
        ),
        jornada AS (
            SELECT DISTINCT ON (persona_id, it) 'cambio_jornada' AS tipo, persona_id, it, mes,
                   jsonb_build_object('horas_semanales', h_o) AS antes, jsonb_build_object('horas_semanales', h_n) AS despues
            FROM comun WHERE h_o <> h_n ORDER BY persona_id, it, mes
        ),
        cargo AS (
            SELECT DISTINCT ON (persona_id, it) 'cambio_cargo', persona_id, it, mes,
                   jsonb_build_object('cargo', c_o), jsonb_build_object('cargo', c_n)
            FROM comun WHERE c_o IS DISTINCT FROM c_n ORDER BY persona_id, it, mes
        ),
        it_cambio AS (       -- mismo mes en ambas cargas, en un IT que la otra carga no tiene ese mes
            SELECT DISTINCT ON (n.persona_id, n.it) 'cambio_it', n.persona_id, n.it, n.mes,
                   jsonb_build_object('it', o.it), jsonb_build_object('it', n.it)
            FROM n JOIN o ON o.persona_id = n.persona_id AND o.mes = n.mes AND o.it <> n.it
            WHERE NOT EXISTS (SELECT 1 FROM o o2 WHERE (o2.persona_id, o2.it, o2.mes) = (n.persona_id, n.it, n.mes))
              AND NOT EXISTS (SELECT 1 FROM n n2 WHERE (n2.persona_id, n2.it, n2.mes) = (o.persona_id, o.it, o.mes))
            ORDER BY n.persona_id, n.it, n.mes
        ),
        alta AS (
            SELECT 'alta', n.persona_id, min(n.it), min(n.mes),
                   NULL::jsonb, jsonb_build_object('horas_semanales', (array_agg(n.horas ORDER BY n.mes))[1],
                                                   'cargo', (array_agg(n.cargo ORDER BY n.mes))[1],
                                                   'fecha_ingreso', min(n.fecha_ingreso))
            FROM n WHERE NOT EXISTS (SELECT 1 FROM o WHERE o.persona_id = n.persona_id)
            GROUP BY n.persona_id
        ),
        perdidos AS (        -- meses de la carga anterior que ya no vienen para esa persona-IT
            SELECT o.persona_id, o.it, o.mes, o.horas, o.cargo
            FROM o WHERE NOT EXISTS (SELECT 1 FROM n WHERE (n.persona_id, n.it, n.mes) = (o.persona_id, o.it, o.mes))
              AND NOT EXISTS (SELECT 1 FROM n WHERE n.persona_id = o.persona_id AND n.mes = o.mes)  -- no es cambio_it
        ),
        baja AS (
            SELECT DISTINCT ON (p.persona_id, p.it) 'baja', p.persona_id, p.it, p.mes,
                   jsonb_build_object('horas_semanales', p.horas, 'cargo', p.cargo), NULL::jsonb
            FROM perdidos p
            WHERE NOT EXISTS (SELECT 1 FROM n WHERE n.persona_id = p.persona_id AND n.it = p.it AND n.mes > p.mes)
            ORDER BY p.persona_id, p.it, p.mes
        ),
        ultimo AS (
            SELECT DISTINCT ON (persona_id, it) * FROM comun ORDER BY persona_id, it, mes DESC
        ),
        vigencia AS (
            SELECT 'cambio_vigencia', u.persona_id, u.it,
                   -- least() ignora NULL: fecha más temprana entre la anterior y la nueva; meses fuera de 2026 -> 1 o 12
                   greatest(1, least(12, (
                       SELECT (extract(year FROM f) - u.anio) * 12 + extract(month FROM f)
                       FROM (SELECT CASE WHEN u.ft_o IS DISTINCT FROM u.ft_n THEN least(u.ft_o, u.ft_n)
                                         ELSE least(u.fi_o, u.fi_n) END AS f) z)))::int,
                   jsonb_build_object('fecha_ingreso', u.fi_o, 'fecha_termino', u.ft_o),
                   jsonb_build_object('fecha_ingreso', u.fi_n, 'fecha_termino', u.ft_n)
            FROM ultimo u
            WHERE u.ft_o IS DISTINCT FROM u.ft_n OR u.fi_o IS DISTINCT FROM u.fi_n
        )
        SELECT p_carga_id, v_ant, x.* FROM (
            SELECT * FROM jornada UNION ALL SELECT * FROM cargo UNION ALL SELECT * FROM it_cambio
            UNION ALL SELECT * FROM alta UNION ALL SELECT * FROM baja UNION ALL SELECT * FROM vigencia) x;
    END IF;

    RETURN QUERY
    SELECT c.tipo, c.persona_id, c.it, c.mes_vigencia, c.antes, c.despues
    FROM core.cambios c WHERE c.carga_id = p_carga_id
    ORDER BY c.mes_vigencia, c.persona_id, c.tipo;
END
$$;

-- Primer mes que hay que recalcular por esa carga: el menor mes_vigencia de sus cambios.
-- Primera carga BUK (sin anterior) -> 1. Carga sin cambios -> NULL (no hay nada que recalcular).
-- Si detectar_cambios aún no corrió para la carga, lo ejecuta.
CREATE OR REPLACE FUNCTION api.mes_minimo_afectado(p_carga_id bigint)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_mes int;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stg.carga c WHERE c.carga_id = p_carga_id AND c.tipo = 'buk') THEN
        RAISE EXCEPTION 'mes_minimo_afectado: la carga % no existe o no es tipo buk', p_carga_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM stg.carga c WHERE c.tipo = 'buk' AND c.carga_id < p_carga_id
                   AND EXISTS (SELECT 1 FROM stg.buk_fila b WHERE b.carga_id = c.carga_id)) THEN
        RETURN 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM core.cambios c WHERE c.carga_id = p_carga_id) THEN
        PERFORM api.detectar_cambios(p_carga_id);
    END IF;
    SELECT min(c.mes_vigencia) INTO v_mes FROM core.cambios c WHERE c.carga_id = p_carga_id;
    RETURN v_mes;
END
$$;

REVOKE ALL ON FUNCTION core.f_buk_filas(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.detectar_cambios(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.mes_minimo_afectado(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.detectar_cambios(bigint) TO bot_carga;
GRANT EXECUTE ON FUNCTION api.mes_minimo_afectado(bigint) TO bot_carga;
