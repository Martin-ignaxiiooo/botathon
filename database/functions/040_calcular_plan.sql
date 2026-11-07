-- B-06 · Plan mensual, meta y FOJA (versión simplificada acordada el 7-nov).
-- Semanas hábiles SH(p, m): semhab de stg.esperado (Excel de planificación, última carga con semhab) para esa
-- persona-IT-mes; si no hay valor para esa persona, regla general = semanas del mes de param.calendario_mes (zona del
-- IT; si la zona no tiene calendario, 'general'). La fuente queda en calc.plan_mes_traza.
-- Mejora pendiente (no implementada): calcular SH desde ausencias/beneficios, ver database\evidencia\b06\formulas.md.
--   ate_dir     = floor(directas+grupal por semana × SH + 1e-9)
--   ate_dir_ind = floor((directas+grupal + indirectas) por semana × SH + 1e-9)
--   meta        = floor(ate_dir × param meta + 1e-9)
--   horas [h/mes]: contratadas = h × S;  dir/ind/nas = (h − colación) × %final × SH;  foja = horas_dir / horas_contratadas
CREATE OR REPLACE FUNCTION calc.f_ate_mes(p_semanal numeric, p_semanas numeric) RETURNS int
LANGUAGE sql IMMUTABLE AS $$ SELECT floor(p_semanal * p_semanas + 1e-9)::int $$;

CREATE OR REPLACE FUNCTION calc.f_meta(p_ate numeric, p_meta numeric) RETURNS int
LANGUAGE sql IMMUTABLE AS $$ SELECT floor(p_ate * p_meta + 1e-9)::int $$;

-- Reescribe calc.plan_mes y calc.plan_mes_traza SOLO para mes >= p_desde_mes (los meses anteriores no se tocan).
CREATE OR REPLACE FUNCTION calc.calcular_plan(p_desde_mes int DEFAULT 1)
RETURNS int
LANGUAGE plpgsql
SET search_path = pg_catalog, public
SET client_min_messages = warning
AS $$
DECLARE
    v_filas int;
    v_meta  numeric;
    v_carga bigint;
BEGIN
    IF p_desde_mes IS NULL OR p_desde_mes NOT BETWEEN 1 AND 12 THEN
        RAISE EXCEPTION 'calcular_plan: desde_mes debe estar entre 1 y 12 (llegó %)', p_desde_mes;
    END IF;
    SELECT valor INTO v_meta FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta';
    IF v_meta IS NULL THEN RAISE EXCEPTION 'calcular_plan: falta param.general meta'; END IF;
    SELECT max(carga_id) INTO v_carga FROM stg.esperado WHERE campo = 'semhab';

    DROP TABLE IF EXISTS t_plan;
    CREATE TEMP TABLE t_plan ON COMMIT DROP AS
    WITH sh_excel AS (       -- persona-IT repetida en el Excel (2 contratos): vale la fila con semanas ese mes
        SELECT persona_id, it, mes, max(valor) AS semanas
        FROM stg.esperado WHERE carga_id = v_carga AND campo = 'semhab' AND mes IS NOT NULL
        GROUP BY persona_id, it, mes
    ), b AS (
        SELECT d.persona_id, d.it, d.mes, d.horas_semanales AS h,
               CASE WHEN d.mes <= 4 THEN 'ene_abr' ELSE 'may_dic' END AS periodo,
               coalesce(cz.semanas, cg.semanas) AS semanas_mes,
               CASE WHEN cz.semanas IS NOT NULL THEN i.zona ELSE 'general' END AS zona_calendario,
               x.semanas AS semanas_excel
        FROM core.dotacion_mes d
        LEFT JOIN param.instituto i ON i.it = d.it
        LEFT JOIN param.calendario_mes cz ON cz.vigente_hasta IS NULL AND cz.mes = d.mes AND cz.zona = i.zona
        LEFT JOIN param.calendario_mes cg ON cg.vigente_hasta IS NULL AND cg.mes = d.mes AND cg.zona = 'general'
        LEFT JOIN sh_excel x ON x.persona_id = d.persona_id AND x.it = d.it AND x.mes = d.mes
        WHERE d.mes >= p_desde_mes
    ), c AS (
        SELECT b.*, coalesce(b.semanas_excel, b.semanas_mes) AS sh,
               CASE WHEN b.semanas_excel IS NOT NULL THEN 'excel' ELSE 'calendario' END AS fuente_semanas,
               s.colacion_h, s.pct_dir_final, s.pct_ind_final, s.pct_nas_asig, s.ate_dir_semana, s.ate_ind_semana,
               s.ate_dir_grupal_semana, s.version_param
        FROM b
        LEFT JOIN calc.v_semanal s ON s.persona_id = b.persona_id AND s.it = b.it AND s.periodo = b.periodo
    )
    SELECT c.*,
           c.h * c.semanas_mes                                              AS horas_contratadas,
           (c.h - c.colacion_h) * c.pct_dir_final * c.sh                    AS horas_dir,
           (c.h - c.colacion_h) * c.pct_ind_final * c.sh                    AS horas_ind,
           (c.h - c.colacion_h) * c.pct_nas_asig  * c.sh                    AS horas_nas,
           calc.f_ate_mes(c.ate_dir_grupal_semana, c.sh)                    AS ate_dir,
           calc.f_ate_mes(c.ate_dir_grupal_semana + c.ate_ind_semana, c.sh) AS ate_dir_ind
    FROM c;

    DELETE FROM calc.plan_mes WHERE mes >= p_desde_mes;
    DELETE FROM calc.plan_mes_traza WHERE mes >= p_desde_mes;

    INSERT INTO calc.plan_mes (persona_id, it, mes, periodo, horas_contratadas, horas_dir, horas_ind, horas_nas,
        pct_dir_final, pct_ind_final, ate_dir_semana, ate_ind_semana, semanas_habiles, ate_dir, ate_dir_ind, meta,
        foja, version_param, calculado_en)
    SELECT persona_id, it, mes, periodo, horas_contratadas, horas_dir, horas_ind, horas_nas,
           pct_dir_final, pct_ind_final, ate_dir_semana, ate_ind_semana, sh, ate_dir, ate_dir_ind,
           calc.f_meta(ate_dir, v_meta), horas_dir / nullif(horas_contratadas, 0), version_param, now()
    FROM t_plan;
    GET DIAGNOSTICS v_filas = ROW_COUNT;

    INSERT INTO calc.plan_mes_traza (persona_id, it, mes, fuente_semanas, semanas_excel, semanas_mes, zona_calendario)
    SELECT persona_id, it, mes, fuente_semanas, semanas_excel, semanas_mes, zona_calendario FROM t_plan;

    DROP TABLE t_plan;
    RETURN v_filas;
END
$$;
REVOKE ALL ON FUNCTION calc.calcular_plan(int) FROM PUBLIC;
