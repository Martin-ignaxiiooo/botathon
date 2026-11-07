-- Métricas de la última carga BUK (las usa scripts\casos_buk.ps1). Variable: -v salida=<archivo de texto>. Solo lectura.
\o :salida
SELECT max(carga_id) AS carga FROM stg.carga WHERE tipo = 'buk' \gset
\echo '== Carga'
SELECT carga_id, archivo, estado, leidas, validas, con_error FROM stg.carga WHERE carga_id = :carga;
\echo '== core.dotacion_mes por origen'
SELECT origen, count(*) AS filas, count(DISTINCT (persona_id, it)) AS persona_it FROM core.dotacion_mes GROUP BY origen ORDER BY origen;
\echo '== Alertas de la carga'
SELECT tipo, persona_id, it, mes, detalle FROM core.alerta WHERE carga_id = :carga ORDER BY tipo, persona_id;
\echo '== Errores de fila de la carga'
SELECT persona_id, campo, valor, motivo FROM stg.error_fila WHERE carga_id = :carga ORDER BY persona_id, campo;
\echo '== Semanal may_dic vs stg.esperado (ate_dir_semana / pct_dir_final ±0,0001)'
WITH e AS (
    SELECT persona_id, it, array_agg(valor) FILTER (WHERE campo = 'ate_dir_semana') AS ate,
           array_agg(valor) FILTER (WHERE campo = 'pct_dir_final') AS pdf
    FROM stg.esperado WHERE mes IS NULL GROUP BY persona_id, it)
SELECT count(*) AS comparables,
       count(*) FILTER (WHERE s.ate_dir_semana = ANY (e.ate)) AS ate_ok,
       round(100.0 * count(*) FILTER (WHERE s.ate_dir_semana = ANY (e.ate)) / nullif(count(*), 0), 1) AS ate_pct,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM unnest(e.pdf) x WHERE abs(x - s.pct_dir_final) <= 0.0001)) AS pdf_ok
FROM calc.v_semanal s JOIN e ON e.persona_id = s.persona_id AND e.it = s.it
WHERE s.periodo = 'may_dic' AND e.ate IS NOT NULL;
\echo '== Personas de los casos D-04: dotación (mes:horas + b=buk p=proyectado)'
SELECT persona_id, it, string_agg(mes || ':' || trim(to_char(horas_semanales, 'FM990.##')) || left(origen, 1), ' ' ORDER BY mes) AS meses,
       (array_agg(cargo ORDER BY mes DESC))[1] AS cargo_ultimo
FROM core.dotacion_mes WHERE persona_id IN (71555, 71027, 999001, 71132, 71146, 71232, 71247, 71279)
GROUP BY persona_id, it ORDER BY persona_id, it;
\echo '== Personas de los casos D-04: semanal'
SELECT persona_id, it, periodo, round(horas_semanales, 3) AS horas_periodo, horas_fin, cargo, tramo,
       round(pct_dir_final, 6) AS pct_dir_final, ate_dir_semana, ate_ind_semana
FROM calc.v_semanal WHERE persona_id IN (71555, 71027, 999001, 71132, 71146, 71232, 71247, 71279)
ORDER BY persona_id, it, periodo;
\o
