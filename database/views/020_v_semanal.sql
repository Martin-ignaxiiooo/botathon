-- calc.v_semanal · cálculo semanal por persona, IT y periodo (ene_abr, may_dic) según docs\reglas.md (B-05).
-- Constantes desde param.general vigente; distribución desde param.cargo_distribucion vigente.
-- Horas del periodo = promedio de las horas de los meses con contrato del periodo (así lo hace el Excel:
-- p. ej. 40 h may-jun y 30 h jul-dic -> 32,5 h en may_dic). horas_fin = horas del último mes del periodo.
-- Grupal en CTE aparte (informativo, lo usa B-06): directa + grupal = ate_dir × (1 − %grupal) + ate_dir × %grupal × pacientes.
CREATE OR REPLACE VIEW calc.v_semanal AS
WITH g AS (                       -- constantes vigentes como columnas
    SELECT max(valor) FILTER (WHERE clave = 'tramo_limite_alto') AS lim_alto,
           max(valor) FILTER (WHERE clave = 'tramo_limite_bajo') AS lim_bajo,
           max(valor) FILTER (WHERE clave = 'pausa_pct_alta')    AS pausa_alta,
           max(valor) FILTER (WHERE clave = 'pausa_pct_baja')    AS pausa_baja,
           max(valor) FILTER (WHERE clave = 'min_indirecta')     AS min_ind_general,
           max(version)                                          AS version_general
    FROM param.general WHERE vigente_hasta IS NULL
),
per AS (                          -- definición de los dos periodos del año
    SELECT * FROM (VALUES ('ene_abr', 1, 4), ('may_dic', 5, 12)) AS p(periodo, mes_desde, mes_hasta)
),
base AS (                         -- horas promedio del periodo y datos del último mes con contrato
    SELECT d.persona_id, d.it, p.periodo, p.mes_desde, p.mes_hasta,
           max(d.mes) AS mes_ref,
           avg(d.horas_semanales) AS horas_semanales,
           (array_agg(d.horas_semanales ORDER BY d.mes DESC))[1] AS horas_fin,
           (array_agg(d.cargo ORDER BY d.mes DESC))[1]           AS cargo,
           (array_agg(d.cod_esp ORDER BY d.mes DESC))[1]         AS cod_esp
    FROM core.dotacion_mes d
    JOIN per p ON d.mes BETWEEN p.mes_desde AND p.mes_hasta
    GROUP BY d.persona_id, d.it, p.periodo, p.mes_desde, p.mes_hasta
),
asig AS (                         -- horas de asignaciones vigentes en el periodo
    SELECT a.persona_id, a.it, p.periodo, sum(a.horas) AS horas
    FROM core.asignacion a
    CROSS JOIN per p
    WHERE a.estado IN ('vigente', 'aprobada')
      AND (a.desde IS NULL OR extract(month FROM a.desde) <= p.mes_hasta)
      AND (a.hasta IS NULL OR extract(month FROM a.hasta) >= p.mes_desde)
    GROUP BY a.persona_id, a.it, p.periodo
),
c AS (
    SELECT b.*, pr.promedio_ponderado AS prom,
           CASE WHEN pr.promedio_ponderado >= g.lim_alto THEN 1
                WHEN pr.promedio_ponderado >= g.lim_bajo THEN 2
                ELSE 3 END AS tramo,
           coalesce(cp.colacion_h, 0) AS colacion_h,
           coalesce(a.horas, 0)       AS horas_asignaciones,
           g.lim_alto, g.pausa_alta, g.pausa_baja, g.min_ind_general
    FROM base b
    JOIN calc.v_promedio_horas pr ON pr.persona_id = b.persona_id AND pr.it = b.it
    CROSS JOIN g
    LEFT JOIN core.condicion_persona cp ON cp.persona_id = b.persona_id AND cp.it = b.it
    LEFT JOIN asig a ON a.persona_id = b.persona_id AND a.it = b.it AND a.periodo = b.periodo
),
d AS (
    SELECT c.*, cd.pct_dir, cd.pct_ind, cd.pct_nas, cd.min_directa,
           coalesce(cd.min_indirecta, c.min_ind_general) AS min_indirecta,
           cd.version AS version_param,
           c.horas_semanales - c.colacion_h AS horas_disponibles,
           cd.pct_nas * c.prom AS horas_nas,
           c.horas_semanales * CASE WHEN c.horas_semanales >= c.lim_alto THEN c.pausa_alta ELSE c.pausa_baja END AS horas_pausa
    FROM c
    LEFT JOIN param.cargo_distribucion cd
           ON cd.vigente_hasta IS NULL AND cd.cargo = c.cargo AND cd.tramo = c.tramo
),
e AS (
    SELECT d.*, (d.horas_nas + d.horas_asignaciones) / nullif(d.horas_disponibles, 0) AS pct_nas_asig
    FROM d
),
f AS (
    SELECT e.*,
           greatest(0, e.pct_dir * (1 - e.pct_nas_asig) / nullif(e.pct_dir + e.pct_ind, 0)) AS pct_dir_final,
           greatest(0, e.pct_ind * (1 - e.pct_nas_asig) / nullif(e.pct_dir + e.pct_ind, 0)) AS pct_ind_final
    FROM e
),
h AS (
    SELECT f.*,
           floor(f.horas_disponibles * f.pct_dir_final * 60 / nullif(f.min_directa, 0) + 1e-9)::int   AS ate_dir_semana,
           floor(f.horas_disponibles * f.pct_ind_final * 60 / nullif(f.min_indirecta, 0) + 1e-9)::int AS ate_ind_semana
    FROM f
),
grupal AS (                       -- regla grupal parametrizada (param.grupal por cod_esp y grupo del instituto)
    SELECT h.persona_id, h.it, h.periodo, gr.pct_grupal, gr.pacientes_grupo
    FROM h
    JOIN param.instituto i ON i.it = h.it
    JOIN param.grupal gr ON gr.vigente_hasta IS NULL AND gr.cod_esp = h.cod_esp AND gr.grupo_it = i.grupo_it
)
SELECT h.persona_id, h.it, h.periodo, h.mes_ref, h.cargo, h.cod_esp, h.tramo,
       h.horas_semanales, h.horas_fin, h.prom AS promedio_ponderado, h.colacion_h, h.horas_disponibles,
       h.pct_dir, h.pct_ind, h.pct_nas, h.horas_nas, h.horas_pausa, h.horas_asignaciones, h.pct_nas_asig,
       h.pct_dir_final, h.pct_ind_final, h.min_directa, h.min_indirecta,
       h.ate_dir_semana, h.ate_ind_semana,
       coalesce(gp.pct_grupal, 0) AS pct_grupal, gp.pacientes_grupo,
       h.ate_dir_semana * (1 - coalesce(gp.pct_grupal, 0))
         + h.ate_dir_semana * coalesce(gp.pct_grupal, 0) * coalesce(gp.pacientes_grupo, 1) AS ate_dir_grupal_semana,
       h.version_param
FROM h
LEFT JOIN grupal gp ON gp.persona_id = h.persona_id AND gp.it = h.it AND gp.periodo = h.periodo;
