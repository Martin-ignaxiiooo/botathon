-- calc.v_promedio_horas · promedio ponderado anual de horas semanales por persona e IT (B-04).
-- Ponderación del Excel: cada mes con contrato (real o proyectado) pesa lo mismo; redondeo hacia abajo.
-- Verificado contra stg.esperado.prom_pond_horas (docs\progreso-back.md).
-- flag: compara las horas del último mes con contrato contra las del primero.
CREATE OR REPLACE VIEW calc.v_promedio_horas AS
SELECT d.persona_id,
       d.it,
       count(*)::int                                   AS meses,
       min(d.mes)::int                                 AS mes_desde,
       max(d.mes)::int                                 AS mes_hasta,
       avg(d.horas_semanales)                          AS promedio_exacto,
       floor(avg(d.horas_semanales) + 1e-9)            AS promedio_ponderado,
       (array_agg(d.horas_semanales ORDER BY d.mes))[1]      AS horas_inicio,
       (array_agg(d.horas_semanales ORDER BY d.mes DESC))[1] AS horas_fin,
       CASE WHEN (array_agg(d.horas_semanales ORDER BY d.mes DESC))[1] > (array_agg(d.horas_semanales ORDER BY d.mes))[1]
                THEN 'aumento'
            WHEN (array_agg(d.horas_semanales ORDER BY d.mes DESC))[1] < (array_agg(d.horas_semanales ORDER BY d.mes))[1]
                THEN 'disminucion'
            ELSE 'sin_cambio' END                      AS flag
FROM core.dotacion_mes d
GROUP BY d.persona_id, d.it;
