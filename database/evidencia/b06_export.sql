-- Evidencia B-06 · plan mensual y meta contra el Excel (stg.esperado, campos por mes).
--   A · capa mensual AISLADA: semanal del Excel × semhab del Excel, con calc.f_ate_mes / calc.f_meta.
--   B · cálculo completo: calc.calcular_plan(1) (semanal calculado en B-05 × semhab del Excel o calendario).
-- Numerador = persona-IT-mes con el mismo valor que el Excel; persona-IT repetida en el Excel: acierto si calza con
-- cualquiera de sus filas. Deja calc.plan_mes calculado. Se ejecuta con scripts\evidencia_b06.ps1 (cwd = raíz).
SELECT valor AS meta FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta' \gset
SELECT calc.calcular_plan(1) AS filas_plan \gset

CREATE TEMP TABLE ev_e AS
SELECT persona_id, it, mes, CASE WHEN mes <= 4 THEN 'ene_abr' ELSE 'may_dic' END AS periodo,
       array_agg(valor) FILTER (WHERE campo = 'semhab')           AS sh,
       array_agg(valor) FILTER (WHERE campo = 'plan_ate_dir')     AS ate,
       array_agg(valor) FILTER (WHERE campo = 'plan_ate_dir_ind') AS ate_di,
       array_agg(valor) FILTER (WHERE campo = 'meta')             AS meta
FROM stg.esperado WHERE mes IS NOT NULL GROUP BY persona_id, it, mes;

CREATE TEMP TABLE ev_w AS
SELECT persona_id, it,
       array_agg(valor) FILTER (WHERE campo = 'ate_semana_total') AS tot,
       array_agg(valor) FILTER (WHERE campo = 'ate_ind_semana')   AS ind
FROM stg.esperado WHERE mes IS NULL GROUP BY persona_id, it;

CREATE TEMP TABLE ev_a AS
SELECT e.persona_id, e.it, e.mes, e.periodo, e.ate, e.ate_di, e.meta, e.sh,
       array_agg(DISTINCT calc.f_ate_mes(t - i, s)::numeric)                   AS ate_calc,
       array_agg(DISTINCT calc.f_ate_mes(t, s)::numeric)                       AS ate_di_calc,
       array_agg(DISTINCT calc.f_meta(calc.f_ate_mes(t - i, s), :meta)::numeric) AS meta_calc
FROM ev_e e JOIN ev_w w USING (persona_id, it)
CROSS JOIN LATERAL unnest(w.tot, w.ind) AS u (t, i)
CROSS JOIN LATERAL unnest(e.sh) AS s
GROUP BY e.persona_id, e.it, e.mes, e.periodo, e.ate, e.ate_di, e.meta, e.sh;

CREATE TEMP TABLE ev_b AS
SELECT p.*, t.fuente_semanas, e.ate, e.ate_di, e.meta AS meta_excel, e.sh AS sh_excel, w.tot, w.ind,
       s.ate_dir_grupal_semana
FROM calc.plan_mes p
JOIN calc.plan_mes_traza t USING (persona_id, it, mes)
JOIN ev_e e USING (persona_id, it, mes)
LEFT JOIN ev_w w USING (persona_id, it)
LEFT JOIN calc.v_semanal s ON s.persona_id = p.persona_id AND s.it = p.it AND s.periodo = p.periodo;

CREATE TEMP VIEW ev_dif AS
SELECT b.persona_id, b.it, b.mes, b.periodo, b.fuente_semanas,
       b.ate[1] AS esperado_ate, b.ate_dir AS obtenido_ate, b.meta_excel[1] AS esperado_meta, b.meta AS obtenido_meta,
       b.sh_excel[1] AS semanas_excel, b.semanas_habiles AS semanas_usadas,
       b.tot[1] - b.ind[1] AS semanal_dir_grupal_excel, b.ate_dir_grupal_semana AS semanal_dir_grupal_sistema,
       CASE WHEN b.ate_dir IS NULL THEN 'sin_semanal (cargo sin parámetros)'
            WHEN NOT EXISTS (SELECT 1 FROM unnest(b.tot, b.ind) u (t, i) WHERE abs(t - i - b.ate_dir_grupal_semana) < 1e-6)
                 THEN 'semanal_distinto (diferencia B-05)'
            ELSE 'otra' END AS causa
FROM ev_b b
WHERE b.ate_dir IS NULL OR NOT (b.ate_dir = ANY (b.ate)) OR NOT (b.meta = ANY (b.meta_excel));

\o database/evidencia/b06/resumen.txt
\echo '# Evidencia B-06 (scripts\\evidencia_b06.ps1)'
\echo 'Filas en calc.plan_mes:' :filas_plan
\echo ''
\echo '## A · capa mensual aislada (semanal y semhab del Excel). Denominador: persona-IT-mes del Excel'
SELECT periodo, count(*) AS denominador,
       count(*) FILTER (WHERE ate_calc && ate)       AS ate_dir_ok,
       count(*) FILTER (WHERE ate_di_calc && ate_di) AS ate_dir_ind_ok,
       count(*) FILTER (WHERE meta_calc && meta)     AS meta_ok,
       round(100.0 * count(*) FILTER (WHERE ate_calc && ate) / count(*), 2)   AS pct_ate_dir,
       round(100.0 * count(*) FILTER (WHERE meta_calc && meta) / count(*), 2) AS pct_meta
FROM ev_a GROUP BY ROLLUP (periodo) ORDER BY periodo NULLS LAST;
\echo ''
\echo '## B · cálculo completo. Denominador: persona-IT-mes del Excel con fila en calc.plan_mes'
SELECT periodo, count(*) AS denominador,
       count(*) FILTER (WHERE ate_dir = ANY (ate))        AS ate_dir_ok,
       count(*) FILTER (WHERE ate_dir_ind = ANY (ate_di)) AS ate_dir_ind_ok,
       count(*) FILTER (WHERE meta = ANY (meta_excel))    AS meta_ok,
       round(100.0 * count(*) FILTER (WHERE ate_dir = ANY (ate)) / count(*), 2)     AS pct_ate_dir,
       round(100.0 * count(*) FILTER (WHERE meta = ANY (meta_excel)) / count(*), 2) AS pct_meta
FROM ev_b GROUP BY ROLLUP (periodo) ORDER BY periodo NULLS LAST;
\echo ''
\echo '## B · diferencias por causa'
SELECT periodo, causa, count(*) AS filas, count(DISTINCT (persona_id, it)) AS persona_it
FROM ev_dif GROUP BY 1, 2 ORDER BY 1 DESC, 3 DESC;
\echo ''
\echo '## B may-dic · persona-IT con diferencias'
SELECT persona_id, it, causa, count(*) AS meses, min(semanal_dir_grupal_excel) AS semanal_excel,
       min(semanal_dir_grupal_sistema) AS semanal_sistema
FROM ev_dif WHERE periodo = 'may_dic' GROUP BY 1, 2, 3 ORDER BY 1, 2;
\echo ''
\echo '## Cobertura y fuente de semanas'
SELECT 'excel_sin_fila_en_plan' AS caso, count(*) AS filas, count(*) FILTER (WHERE ate[1] > 0) AS con_atenciones_excel
FROM ev_e e WHERE NOT EXISTS (SELECT 1 FROM calc.plan_mes p WHERE (p.persona_id, p.it, p.mes) = (e.persona_id, e.it, e.mes))
UNION ALL
SELECT 'plan_sin_excel', count(*), count(*) FILTER (WHERE ate_dir > 0)
FROM calc.plan_mes p WHERE NOT EXISTS (SELECT 1 FROM ev_e e WHERE (p.persona_id, p.it, p.mes) = (e.persona_id, e.it, e.mes));
SELECT fuente_semanas, count(*) FROM calc.plan_mes_traza GROUP BY 1 ORDER BY 1;
\echo ''
\echo '## Unidades e identidades (filas con porcentajes)'
SELECT count(*) AS filas,
       count(*) FILTER (WHERE abs(p.horas_dir + p.horas_ind + p.horas_nas
                                  - (d.horas_semanales - s.colacion_h) * p.semanas_habiles) < 1e-6) AS dir_ind_nas_igual_disp_x_sh,
       count(*) FILTER (WHERE abs(p.horas_contratadas - d.horas_semanales * t.semanas_mes) < 1e-9) AS contratadas_igual_h_x_s,
       count(*) FILTER (WHERE abs(p.foja - p.horas_dir / p.horas_contratadas) < 1e-12)           AS foja_igual_dir_sobre_contr,
       count(*) FILTER (WHERE p.horas_dir + p.horas_ind + p.horas_nas > p.horas_contratadas + 1e-6) AS suma_mayor_que_contratadas,
       round(min(p.foja), 4) AS foja_min, round(avg(p.foja), 4) AS foja_prom, round(max(p.foja), 4) AS foja_max
FROM calc.plan_mes p
JOIN calc.plan_mes_traza t USING (persona_id, it, mes)
JOIN core.dotacion_mes d USING (persona_id, it, mes)
JOIN calc.v_semanal s ON s.persona_id = p.persona_id AND s.it = p.it AND s.periodo = p.periodo
WHERE s.pct_dir_final IS NOT NULL;
\o

\copy (SELECT * FROM ev_dif ORDER BY periodo DESC, persona_id, it, mes) TO 'database/evidencia/b06/diferencias_completo.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT persona_id, it, mes, periodo, ate[1] AS esperado_ate, ate_calc, ate_di[1] AS esperado_ate_dir_ind, ate_di_calc, meta[1] AS esperado_meta, meta_calc, sh AS semanas_excel FROM ev_a WHERE NOT (ate_calc && ate) OR NOT (meta_calc && meta) OR NOT (ate_di_calc && ate_di) ORDER BY periodo DESC, 1, 2, 3) TO 'database/evidencia/b06/diferencias_aislada.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
