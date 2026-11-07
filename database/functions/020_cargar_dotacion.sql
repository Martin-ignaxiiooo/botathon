-- Contrato 2 · cargar_dotacion(p_carga_id bigint) returns table(filas int, alertas int). Lo llama P02.
-- Pasa stg.buk_fila (carga tipo 'buk') a core.persona y core.dotacion_mes.
-- * mes = month(periodo); dias_semana = length(dias_jornada) o ndias; cargo -> param.cargo_homologado.
-- * Fila sin persona/IT/periodo, horas <= 0 o fecha_termino < fecha_ingreso -> stg.error_fila. Cargo sin homologar -> core.alerta y se omite.
--   Duplicado (persona, it, mes) en la misma carga -> core.alerta y se toma el de más horas.
--   area distinta a la sede de su IT (traslado sin actualizar area) -> se usa la del IT y core.alerta 'area_distinta_it'.
-- * Cada carga BUK es una foto completa: core.dotacion_mes queda igual a lo real de esta carga + proyección.
-- * Proyección ago-dic (docs\progreso-back.md): cada persona-IT presente en el último mes de la carga
--   mantiene las condiciones de ese mes hasta el mes de fecha_termino (incluido) o diciembre. origen = 'proyectado'.
CREATE OR REPLACE FUNCTION api.cargar_dotacion(p_carga_id bigint)
RETURNS TABLE (filas int, alertas int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
SET client_min_messages = warning
AS $$
DECLARE
    v_tipo     text;
    v_filas    int;
    v_alertas  int := 0;
    v_n        int;
    v_leidas   int;
    v_ult_mes  int;
    v_robot    int;
    v_base     int;
    v_repetidos int;
BEGIN
    SELECT c.tipo INTO v_tipo FROM stg.carga c WHERE c.carga_id = p_carga_id;
    IF v_tipo IS NULL THEN
        RAISE EXCEPTION 'cargar_dotacion: no existe la carga %', p_carga_id;
    END IF;
    IF v_tipo <> 'buk' THEN
        RAISE EXCEPTION 'cargar_dotacion: la carga % es de tipo % (se espera buk)', p_carga_id, v_tipo;
    END IF;

    -- Re-ejecutable: se limpian las alertas y errores propios de esta carga
    DELETE FROM core.alerta a WHERE a.carga_id = p_carga_id AND a.tipo IN ('cargo_sin_homologar', 'duplicado', 'area_distinta_it');
    DELETE FROM stg.error_fila e WHERE e.carga_id = p_carga_id AND e.motivo LIKE 'cargar_dotacion:%';

    DROP TABLE IF EXISTS t_fila, t_real, t_proy, t_sede;
    CREATE TEMP TABLE t_fila ON COMMIT DROP AS
    SELECT b.*, extract(month FROM b.periodo)::smallint AS mes, row_number() OVER () AS fila,
           upper(regexp_replace(trim(b.cargo), '\s+', ' ', 'g')) AS cargo_norm
    FROM stg.buk_fila b WHERE b.carga_id = p_carga_id;
    SELECT count(*) INTO v_leidas FROM t_fila;

    -- Filas inválidas
    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    SELECT p_carga_id, f.fila, f.persona_id,
           CASE WHEN f.persona_id IS NULL THEN 'persona_id' WHEN f.it IS NULL THEN 'it'
                WHEN f.periodo IS NULL THEN 'periodo'
                WHEN f.horas_semanales IS NULL OR f.horas_semanales <= 0 THEN 'horas_semanales'
                ELSE 'fecha_termino' END,
           CASE WHEN f.fecha_termino < f.fecha_ingreso THEN f.fecha_termino::text
                ELSE coalesce(f.horas_semanales::text, '') END,
           CASE WHEN f.fecha_termino < f.fecha_ingreso THEN 'cargar_dotacion: fecha término anterior a fecha ingreso'
                ELSE 'cargar_dotacion: fila sin persona, IT, periodo u horas > 0' END
    FROM t_fila f
    WHERE f.persona_id IS NULL OR f.it IS NULL OR f.periodo IS NULL
       OR f.horas_semanales IS NULL OR f.horas_semanales <= 0
       OR f.fecha_termino < f.fecha_ingreso;
    DELETE FROM t_fila f
    WHERE f.persona_id IS NULL OR f.it IS NULL OR f.periodo IS NULL
       OR f.horas_semanales IS NULL OR f.horas_semanales <= 0
       OR f.fecha_termino < f.fecha_ingreso;

    -- Cargos sin homologar: error por fila (stg.error_fila) y una alerta por persona-IT-cargo (core.alerta)
    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    SELECT p_carga_id, f.fila, f.persona_id, 'cargo', f.cargo, 'cargar_dotacion: cargo sin homologar'
    FROM t_fila f
    WHERE NOT EXISTS (SELECT 1 FROM param.cargo_homologado h WHERE upper(h.cargo_origen) = f.cargo_norm);
    INSERT INTO core.alerta (carga_id, tipo, persona_id, it, mes, detalle)
    SELECT p_carga_id, 'cargo_sin_homologar', f.persona_id, f.it, min(f.mes),
           jsonb_build_object('cargo', min(f.cargo), 'filas', count(*))
    FROM t_fila f
    WHERE NOT EXISTS (SELECT 1 FROM param.cargo_homologado h WHERE upper(h.cargo_origen) = f.cargo_norm)
    GROUP BY f.persona_id, f.it, f.cargo_norm;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_alertas := v_alertas + v_n;
    DELETE FROM t_fila f
    WHERE NOT EXISTS (SELECT 1 FROM param.cargo_homologado h WHERE upper(h.cargo_origen) = f.cargo_norm);

    -- Duplicados (persona, it, mes)
    INSERT INTO core.alerta (carga_id, tipo, persona_id, it, mes, detalle)
    SELECT p_carga_id, 'duplicado', f.persona_id, f.it, f.mes, jsonb_build_object('filas', count(*))
    FROM t_fila f GROUP BY f.persona_id, f.it, f.mes HAVING count(*) > 1;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_alertas := v_alertas + v_n;

    -- Filas duplicadas descartadas (se conserva la de más horas) -> stg.error_fila
    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    SELECT p_carga_id, x.fila, x.persona_id, 'persona_id', x.persona_id || '/' || x.it || '/' || x.periodo,
           'cargar_dotacion: fila duplicada (persona_id, it, periodo)'
    FROM (SELECT f.*, row_number() OVER (PARTITION BY f.persona_id, f.it, f.mes
                                         ORDER BY f.horas_semanales DESC, f.fila) AS rn FROM t_fila f) x
    WHERE x.rn > 1;

    CREATE TEMP TABLE t_real ON COMMIT DROP AS
    SELECT DISTINCT ON (f.persona_id, f.it, f.mes)
           f.persona_id, f.it, f.mes, f.periodo, f.instituto, f.area, f.sub_area, f.centro_costo, f.tipo_contrato,
           f.tipo_trabajador, f.fecha_ingreso, f.fecha_termino, f.horas_semanales, f.cargo AS cargo_origen,
           h.cargo, coalesce(nullif(trim(f.cod_esp), ''), h.cod_esp) AS cod_esp,
           coalesce(nullif(length(trim(f.dias_jornada)), 0), f.ndias)::smallint AS dias_semana
    FROM t_fila f
    JOIN param.cargo_homologado h ON upper(h.cargo_origen) = f.cargo_norm
    ORDER BY f.persona_id, f.it, f.mes, f.horas_semanales DESC, f.fila;
    SELECT count(*) INTO v_filas FROM t_real;

    -- Sede (area) coherente con el IT: en el BUK la area es la sede y depende solo del IT. Si una fila trae otra
    -- (p. ej. un traslado de IT que no actualizó la area), se usa la area más frecuente de ese IT en esta carga y
    -- queda una alerta 'area_distinta_it' por persona-IT (detalle: area del BUK, area usada, meses).
    CREATE TEMP TABLE t_sede ON COMMIT DROP AS
    SELECT DISTINCT ON (s.it) s.it, s.area
    FROM (SELECT r.it, r.area, count(*) AS n FROM t_real r WHERE nullif(trim(r.area), '') IS NOT NULL GROUP BY 1, 2) s
    ORDER BY s.it, s.n DESC, s.area;
    INSERT INTO core.alerta (carga_id, tipo, persona_id, it, mes, detalle)
    SELECT p_carga_id, 'area_distinta_it', r.persona_id, r.it, min(r.mes),
           jsonb_build_object('area_buk', r.area, 'area_usada', t.area, 'meses', array_agg(r.mes ORDER BY r.mes))
    FROM t_real r JOIN t_sede t ON t.it = r.it
    WHERE nullif(trim(r.area), '') IS NOT NULL AND r.area <> t.area
    GROUP BY r.persona_id, r.it, r.area, t.area;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_alertas := v_alertas + v_n;
    UPDATE t_real r SET area = t.area FROM t_sede t WHERE t.it = r.it AND r.area IS DISTINCT FROM t.area;

    -- Proyección: último mes de la carga -> hasta fecha_termino o diciembre
    SELECT max(r.mes) INTO v_ult_mes FROM t_real r;
    CREATE TEMP TABLE t_proy ON COMMIT DROP AS
    SELECT r.persona_id, r.it, m.mes::smallint AS mes, make_date(extract(year FROM r.periodo)::int, m.mes, 1) AS periodo,
           r.instituto, r.area, r.sub_area, r.centro_costo, r.tipo_contrato, r.tipo_trabajador, r.fecha_ingreso,
           r.fecha_termino, r.horas_semanales, r.cargo_origen, r.cargo, r.cod_esp, r.dias_semana
    FROM t_real r
    CROSS JOIN LATERAL generate_series(r.mes + 1,
        CASE WHEN r.fecha_termino IS NULL OR r.fecha_termino >= make_date(extract(year FROM r.periodo)::int + 1, 1, 1) THEN 12
             WHEN r.fecha_termino < date_trunc('year', r.periodo) THEN 0
             ELSE extract(month FROM r.fecha_termino)::int END) AS m(mes)
    WHERE r.mes = v_ult_mes;

    -- core.persona
    INSERT INTO core.persona AS p (persona_id, primera_carga, ultima_carga)
    SELECT DISTINCT r.persona_id, p_carga_id, p_carga_id FROM t_real r
    ON CONFLICT (persona_id) DO UPDATE SET ultima_carga = EXCLUDED.ultima_carga, actualizada_en = now();

    -- core.dotacion_mes = foto de esta carga (real + proyectado)
    DELETE FROM core.dotacion_mes d
    WHERE NOT EXISTS (SELECT 1 FROM t_real r WHERE (r.persona_id, r.it, r.mes) = (d.persona_id, d.it, d.mes))
      AND NOT EXISTS (SELECT 1 FROM t_proy r WHERE (r.persona_id, r.it, r.mes) = (d.persona_id, d.it, d.mes));

    INSERT INTO core.dotacion_mes AS d (persona_id, it, mes, periodo, instituto, area, sub_area, centro_costo,
        tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo_origen, cargo, cod_esp,
        dias_semana, origen, carga_id, actualizado_en)
    SELECT persona_id, it, mes, periodo, instituto, area, sub_area, centro_costo, tipo_contrato, tipo_trabajador,
           fecha_ingreso, fecha_termino, horas_semanales, cargo_origen, cargo, cod_esp, dias_semana, x.origen,
           p_carga_id, now()
    FROM (SELECT r.*, 'buk'::text AS origen FROM t_real r
          UNION ALL
          SELECT q.*, 'proyectado'::text FROM t_proy q) x
    ON CONFLICT (persona_id, it, mes) DO UPDATE SET
        periodo = EXCLUDED.periodo, instituto = EXCLUDED.instituto, area = EXCLUDED.area,
        sub_area = EXCLUDED.sub_area, centro_costo = EXCLUDED.centro_costo, tipo_contrato = EXCLUDED.tipo_contrato,
        tipo_trabajador = EXCLUDED.tipo_trabajador, fecha_ingreso = EXCLUDED.fecha_ingreso,
        fecha_termino = EXCLUDED.fecha_termino, horas_semanales = EXCLUDED.horas_semanales,
        cargo_origen = EXCLUDED.cargo_origen, cargo = EXCLUDED.cargo, cod_esp = EXCLUDED.cod_esp,
        dias_semana = EXCLUDED.dias_semana, origen = EXCLUDED.origen, carga_id = EXCLUDED.carga_id,
        actualizado_en = now();

    -- Conteos (regla en docs\progreso-back.md):
    --   robot = errores que Blue Prism dejó en stg.error_fila (motivo sin prefijo 'cargar_dotacion:')
    --   base  = errores que detectó esta función (prefijo 'cargar_dotacion:')
    --   repetidos = errores del robot con el mismo (persona_id, campo) que un error de la base: la fila llegó
    --               también a stg.buk_fila y ya está contada en base (y en las leídas de stg.buk_fila)
    --   con_error = robot + base − repetidos;  leidas = filas de stg.buk_fila + robot − repetidos
    SELECT count(*) FILTER (WHERE e.motivo NOT LIKE 'cargar_dotacion:%'),
           count(*) FILTER (WHERE e.motivo LIKE 'cargar_dotacion:%'),
           count(*) FILTER (WHERE e.motivo NOT LIKE 'cargar_dotacion:%' AND EXISTS (
               SELECT 1 FROM stg.error_fila d
               WHERE d.carga_id = p_carga_id AND d.motivo LIKE 'cargar_dotacion:%'
                 AND d.persona_id IS NOT DISTINCT FROM e.persona_id AND d.campo IS NOT DISTINCT FROM e.campo))
    INTO v_robot, v_base, v_repetidos
    FROM stg.error_fila e WHERE e.carga_id = p_carga_id;

    UPDATE stg.carga c
    SET estado = 'cargada',
        leidas = v_leidas + v_robot - v_repetidos,
        validas = v_filas,
        con_error = v_robot + v_base - v_repetidos
    WHERE c.carga_id = p_carga_id;

    filas := v_filas;
    alertas := v_alertas;
    RETURN NEXT;
END
$$;

REVOKE ALL ON FUNCTION api.cargar_dotacion(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.cargar_dotacion(bigint) TO bot_carga;
