-- cargar_asignaciones(p_carga_id bigint) returns int · stg.asignacion (carga tipo 'asignaciones') -> core.asignacion.
-- Función interna (no está en el Contrato 2); la usa el seed y la podrá usar P10. Re-ejecutable por carga.
-- Filas sin persona, IT o con horas <= 0 -> stg.error_fila. Estado por defecto 'vigente'.
CREATE OR REPLACE FUNCTION api.cargar_asignaciones(p_carga_id bigint)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_tipo text;
    v_n    int;
    v_err  int;
BEGIN
    SELECT c.tipo INTO v_tipo FROM stg.carga c WHERE c.carga_id = p_carga_id;
    IF v_tipo IS DISTINCT FROM 'asignaciones' THEN
        RAISE EXCEPTION 'cargar_asignaciones: la carga % no existe o no es de tipo asignaciones', p_carga_id;
    END IF;

    DELETE FROM core.asignacion a WHERE a.carga_id = p_carga_id;
    DELETE FROM stg.error_fila e WHERE e.carga_id = p_carga_id AND e.motivo LIKE 'cargar_asignaciones:%';

    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    SELECT p_carga_id, s.n, s.persona_id, 'horas', coalesce(s.horas::text, ''),
           'cargar_asignaciones: fila sin persona, IT, tipo u horas > 0'
    FROM (SELECT x.*, row_number() OVER () AS n FROM stg.asignacion x WHERE x.carga_id = p_carga_id) s
    WHERE s.persona_id IS NULL OR s.it IS NULL OR s.tipo IS NULL OR s.horas IS NULL OR s.horas <= 0;
    GET DIAGNOSTICS v_err = ROW_COUNT;

    INSERT INTO core.asignacion (persona_id, it, tipo, horas, desde, hasta, solicitante, motivo, estado, carga_id)
    SELECT s.persona_id, s.it, trim(s.tipo), s.horas, s.desde, s.hasta, s.solicitante, s.motivo,
           coalesce(nullif(trim(s.estado), ''), 'vigente'), p_carga_id
    FROM stg.asignacion s
    WHERE s.carga_id = p_carga_id AND s.persona_id IS NOT NULL AND s.it IS NOT NULL
      AND s.tipo IS NOT NULL AND s.horas > 0;
    GET DIAGNOSTICS v_n = ROW_COUNT;

    UPDATE stg.carga c SET estado = 'cargada', leidas = v_n + v_err, validas = v_n, con_error = v_err
    WHERE c.carga_id = p_carga_id;
    RETURN v_n;
END
$$;

REVOKE ALL ON FUNCTION api.cargar_asignaciones(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.cargar_asignaciones(bigint) TO bot_carga;
