-- B-08 · api.recalcular(desde_mes) (Contrato 2): recalcula calc.plan_mes desde ese mes en una sola transacción
-- (la de la llamada) usando calc.calcular_plan; los meses anteriores no se tocan. Registra en audit.log quién,
-- desde qué mes, cuántas filas, cuánto tardó y el motivo (set_config('planbot.motivo', ...) antes de llamar).
-- Al final rehace la cuadratura (api.cuadratura, B-10) si hay Excel en stg.esperado, para que api.v_cuadratura
-- nunca mezcle el plan nuevo con diferencias del plan anterior (~0,5 s; queda en audit.log como cuadratura_pct).
CREATE OR REPLACE FUNCTION api.recalcular(p_desde_mes int)
RETURNS TABLE (filas int, ms int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_ini   timestamptz := clock_timestamp();
    v_filas int;
    v_ms    int;
    v_pct   numeric;
BEGIN
    IF p_desde_mes IS NULL OR p_desde_mes NOT BETWEEN 1 AND 12 THEN
        RAISE EXCEPTION 'recalcular: desde_mes debe estar entre 1 y 12 (llegó %)', p_desde_mes;
    END IF;
    v_filas := calc.calcular_plan(p_desde_mes);
    IF EXISTS (SELECT 1 FROM stg.esperado WHERE campo = 'plan_ate_dir') THEN
        v_pct := api.cuadratura();
    END IF;
    v_ms := ceil(extract(epoch FROM clock_timestamp() - v_ini) * 1000)::int;

    INSERT INTO audit.log (tabla, operacion, usuario, motivo, antes, despues)
    VALUES ('calc.plan_mes', 'recalcular', session_user, nullif(current_setting('planbot.motivo', true), ''),
            NULL, jsonb_build_object('desde_mes', p_desde_mes, 'filas', v_filas, 'ms', v_ms, 'cuadratura_pct', v_pct));

    RETURN QUERY SELECT v_filas, v_ms;
END
$$;
REVOKE ALL ON FUNCTION api.recalcular(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.recalcular(int) TO bot_carga;
