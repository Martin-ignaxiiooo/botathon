-- Evidencia B-05 · exporta, por persona-IT del periodo may_dic, los datos usados y el resultado de dos variantes:
--   v0 (antes):   horas del periodo = horas del último mes del periodo (diciembre o mes de término)
--   v1 (después): horas del periodo = promedio de las horas de los meses may-dic con contrato (reales + proyectados)
-- Mismos insumos en ambas (cargo, tramo por promedio anual, %Dir/%Ind/%NAS, asignaciones, colación, minutos).
-- Se ejecuta con scripts\evidencia_b05.ps1 (cwd = raíz del repo). Solo lectura.
CREATE TEMP VIEW ev_sistema AS
WITH s AS (SELECT * FROM calc.v_semanal WHERE periodo = 'may_dic'),
m AS (
    SELECT persona_id, it,
           string_agg(mes || ':' || trim(to_char(horas_semanales, 'FM999990.##')) ||
                      CASE WHEN origen = 'proyectado' THEN 'p' ELSE '' END, ' ' ORDER BY mes) AS serie_may_dic
    FROM core.dotacion_mes WHERE mes >= 5 GROUP BY persona_id, it
),
v0 AS (
    SELECT s.*, (s.horas_nas + s.horas_asignaciones) / nullif(s.horas_fin - s.colacion_h, 0) AS pna_v0
    FROM s
),
v0b AS (
    SELECT v0.*, greatest(0, v0.pct_dir * (1 - v0.pna_v0) / nullif(v0.pct_dir + v0.pct_ind, 0)) AS pdf_v0
    FROM v0
)
SELECT v.persona_id, v.it, v.cargo, v.cod_esp, v.tramo, v.promedio_ponderado,
       v.horas_fin            AS horas_dic,
       round(v.horas_semanales, 6) AS horas_prom_may_dic,
       v.colacion_h, v.horas_nas, v.horas_asignaciones, v.pct_dir, v.pct_ind, v.pct_nas, v.min_directa,
       round(v.pna_v0, 6)        AS pct_nas_asig_v0,
       round(v.pdf_v0, 6)        AS pct_dir_final_v0,
       floor((v.horas_fin - v.colacion_h) * v.pdf_v0 * 60 / nullif(v.min_directa, 0) + 1e-9)::int AS ate_dir_semana_v0,
       round(v.pct_nas_asig, 6)  AS pct_nas_asig_v1,
       round(v.pct_dir_final, 6) AS pct_dir_final_v1,
       v.ate_dir_semana          AS ate_dir_semana_v1,
       m.serie_may_dic
FROM v0b v
LEFT JOIN m ON m.persona_id = v.persona_id AND m.it = v.it;

\copy (SELECT * FROM ev_sistema ORDER BY persona_id, it) TO 'database/evidencia/b05/sistema_may_dic.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT persona_id, it, campo, valor FROM stg.esperado WHERE mes IS NULL AND campo IN ('ate_dir_semana', 'pct_dir_final', 'horas_semana_dic', 'prom_pond_horas') ORDER BY 1, 2, 3) TO 'database/evidencia/b05/esperado_semanal.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
