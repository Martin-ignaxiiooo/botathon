-- B-10 · Cuadratura Excel vs sistema (Contrato 2: cuadratura() → numeric % de coincidencia).
-- Compara la última carga de stg.esperado (valores del Excel) con lo que calcula PlanBot:
--   semanales (mes NULL, periodo may_dic) contra calc.v_semanal:
--     pct_dir_final, pct_ind_final, ate_dir_semana, ate_ind_semana, ate_semana_total (dir + ind),
--     horas_semana_dic (horas_fin), prom_pond_horas (promedio_ponderado)
--   mensuales contra calc.plan_mes:
--     semhab (semanas_habiles), plan_ate_dir (ate_dir), plan_ate_dir_ind (ate_dir_ind), meta,
--     meta_dir_ind (floor(ate_dir_ind × meta de param.general))
-- Coincide si |excel − sistema| < 1e-6 (los porcentajes del Excel traen ruido de coma flotante).
-- Sin fila en el sistema (persona-IT o mes sin dotación) cuenta como 0: coincide si el Excel también dice 0.
-- Si el Excel repite una persona-IT, basta que una de sus filas coincida.
-- calc.cuadratura guarda SOLO las diferencias (la pantalla de cuadratura cuenta como coincidentes al resto).
-- Causa probable (la primera que aplica, por persona-IT):
--   diferencia_explicada  persona-IT de param.cuadratura_explicada (diferencia ya analizada, con nota)
--   ajuste_individual     el semanal may-dic del sistema (ate_dir_semana o ate_ind_semana) no es el del Excel, o
--                         plan_ate_dir may-dic difiere con las mismas semanas hábiles: la planilla tiene un ajuste
--                         por persona que el BUK no trae (los 20 casos de B-05)
--   periodo_ene_abr       mes 1-4: el Excel aplica otra regla en ene-abr (B-06)
--   dias_adicionales      el Excel usa otras semanas hábiles que el sistema para ese mes
--   multi_it              la persona tiene más de un IT en la dotación
--   grupal                la persona tiene atención grupal (pct_grupal > 0)
--   otra                  sin causa conocida
-- Filas del Excel sin valor en el sistema y distintas de 0: multi_it si la persona tiene otro IT (en la dotación o
-- en el Excel), si no otra.
-- Devuelve el % de coincidencia de plan_ate_dir en may-dic sobre las persona-IT-mes que existen en el Excel y en
-- el plan del sistema (las que el BUK no trae quedan igual en calc.cuadratura como multi_it u otra; ene-abr usa
-- otra regla, ver B-06). calc.cuadratura guarda las diferencias de los 12 meses.
-- Requiere calc.plan_mes calculado (api.recalcular) y stg.esperado cargado.
CREATE OR REPLACE FUNCTION api.cuadratura() RETURNS numeric
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_carga bigint;
    v_meta  numeric;
    v_pct   numeric;
BEGIN
    SELECT max(carga_id) INTO v_carga FROM stg.esperado;
    IF v_carga IS NULL THEN RAISE EXCEPTION 'cuadratura: stg.esperado está vacío'; END IF;
    SELECT valor INTO v_meta FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta';
    IF v_meta IS NULL THEN RAISE EXCEPTION 'cuadratura: falta param.general meta'; END IF;

    IF to_regclass('pg_temp.cuad_cmp') IS NOT NULL THEN DROP TABLE pg_temp.cuad_cmp; END IF;
    CREATE TEMP TABLE cuad_cmp ON COMMIT DROP AS
    WITH esp AS (
        SELECT e.persona_id, e.it, e.campo, e.mes, e.valor
        FROM stg.esperado e
        WHERE e.carga_id = v_carga AND e.persona_id IS NOT NULL AND e.campo IS NOT NULL
    ), sem AS (
        SELECT s.persona_id, s.it, x.campo, x.valor
        FROM calc.v_semanal s
        CROSS JOIN LATERAL (VALUES
            ('pct_dir_final',    s.pct_dir_final),
            ('pct_ind_final',    s.pct_ind_final),
            ('ate_dir_semana',   s.ate_dir_semana::numeric),
            ('ate_ind_semana',   s.ate_ind_semana::numeric),
            ('ate_semana_total', (s.ate_dir_semana + s.ate_ind_semana)::numeric),
            ('horas_semana_dic', s.horas_fin),
            ('prom_pond_horas',  s.promedio_ponderado)) x(campo, valor)
        WHERE s.periodo = 'may_dic'
    ), mes AS (
        SELECT p.persona_id, p.it, p.mes, x.campo, x.valor
        FROM calc.plan_mes p
        CROSS JOIN LATERAL (VALUES
            ('semhab',           p.semanas_habiles),
            ('plan_ate_dir',     p.ate_dir::numeric),
            ('plan_ate_dir_ind', p.ate_dir_ind::numeric),
            ('meta',             p.meta::numeric),
            ('meta_dir_ind',     calc.f_meta(p.ate_dir_ind, v_meta)::numeric)) x(campo, valor)
    ), cmp AS (
        SELECT e.persona_id, e.it, e.campo, e.mes, e.valor AS excel,
               coalesce(m.valor, s.valor) AS sistema
        FROM esp e
        LEFT JOIN mes m ON e.mes IS NOT NULL AND m.persona_id = e.persona_id AND m.it = e.it
                       AND m.mes = e.mes AND m.campo = e.campo
        LEFT JOIN sem s ON e.mes IS NULL AND s.persona_id = e.persona_id AND s.it = e.it AND s.campo = e.campo
    )
    -- una fila por persona-IT-campo-mes; con filas repetidas en el Excel se queda la más cercana al sistema
    SELECT DISTINCT ON (persona_id, it, campo, mes)
           persona_id, it, campo, mes, excel, sistema,
           (excel IS NOT NULL AND abs(excel - coalesce(sistema, 0)) < 1e-6) AS coincide
    FROM cmp
    ORDER BY persona_id, it, campo, mes, abs(coalesce(excel, 1e12) - coalesce(sistema, 0));

    SELECT round(100.0 * count(*) FILTER (WHERE coincide) / nullif(count(*), 0), 2) INTO v_pct
    FROM cuad_cmp WHERE campo = 'plan_ate_dir' AND mes >= 5 AND sistema IS NOT NULL;

    DELETE FROM calc.cuadratura;
    INSERT INTO calc.cuadratura (persona_id, it, campo, mes, excel, sistema, diferencia, causa, calculado_en)
    WITH ajuste AS (               -- persona-IT con semanal may-dic distinto al del Excel
        SELECT persona_id, it FROM cuad_cmp
        WHERE campo IN ('ate_dir_semana', 'ate_ind_semana') AND NOT coincide AND sistema IS NOT NULL
        UNION                      -- o con atenciones may-dic distintas usando las mismas semanas hábiles
        SELECT c.persona_id, c.it FROM cuad_cmp c
        JOIN cuad_cmp s ON s.persona_id = c.persona_id AND s.it = c.it AND s.mes = c.mes AND s.campo = 'semhab'
        WHERE c.campo = 'plan_ate_dir' AND c.mes >= 5 AND NOT c.coincide AND c.sistema IS NOT NULL AND s.coincide
    ), dias AS (                   -- persona-IT-mes con semanas hábiles distintas
        SELECT persona_id, it, mes FROM cuad_cmp WHERE campo = 'semhab' AND NOT coincide
    ), multi AS (                  -- persona con más de un IT en la dotación o en el Excel
        SELECT persona_id FROM (SELECT persona_id, it FROM core.dotacion_mes
                                UNION SELECT persona_id, it FROM cuad_cmp) u
        GROUP BY persona_id HAVING count(DISTINCT it) > 1
    ), grupal AS (
        SELECT DISTINCT persona_id, it FROM calc.v_semanal WHERE coalesce(pct_grupal, 0) > 0
    )
    SELECT c.persona_id, c.it, c.campo, c.mes, c.excel, c.sistema, c.sistema - c.excel,
           CASE
               WHEN c.sistema IS NULL THEN CASE WHEN mu.persona_id IS NOT NULL THEN 'multi_it' ELSE 'otra' END
               WHEN x.persona_id IS NOT NULL                            THEN 'diferencia_explicada'
               WHEN a.persona_id IS NOT NULL                            THEN 'ajuste_individual'
               WHEN c.mes BETWEEN 1 AND 4                               THEN 'periodo_ene_abr'
               WHEN d.persona_id IS NOT NULL                            THEN 'dias_adicionales'
               WHEN mu.persona_id IS NOT NULL                           THEN 'multi_it'
               WHEN g.persona_id IS NOT NULL                            THEN 'grupal'
               ELSE 'otra'
           END, now()
    FROM cuad_cmp c
    LEFT JOIN param.cuadratura_explicada x ON x.persona_id = c.persona_id AND x.it = c.it
    LEFT JOIN ajuste a ON a.persona_id = c.persona_id AND a.it = c.it
    LEFT JOIN dias d   ON d.persona_id = c.persona_id AND d.it = c.it AND d.mes = c.mes
    LEFT JOIN multi mu ON mu.persona_id = c.persona_id
    LEFT JOIN grupal g ON g.persona_id = c.persona_id AND g.it = c.it
    WHERE NOT c.coincide;

    RETURN coalesce(v_pct, 0);
END $$;

REVOKE ALL ON FUNCTION api.cuadratura() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.cuadratura() TO bot_carga;
