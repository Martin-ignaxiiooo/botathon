-- Comparación de solo lectura contra esperado.csv previamente sembrado en stg.esperado.
-- Conserva las alternativas por clave repetida; informa ambigüedad y cobertura.
-- No invoca cálculo ni cambia B. Una coincidencia con alguna alternativa no las resuelve.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
WITH e AS (
 SELECT persona_id,it,mes,campo,array_agg(valor) AS valores,count(DISTINCT valor) AS variantes
 FROM stg.esperado WHERE campo IN('plan_ate_dir','meta') AND mes BETWEEN 5 AND 12
 GROUP BY persona_id,it,mes,campo
), c AS (
 SELECT e.*,CASE WHEN campo='plan_ate_dir' THEN p.ate_dir ELSE p.meta END AS obtenido,
        p.persona_id IS NOT NULL AS cubierto
 FROM e LEFT JOIN calc.plan_mes p USING(persona_id,it,mes)
)
SELECT campo,count(*) AS claves_excel,count(*) FILTER(WHERE cubierto) AS comparables,
 count(*) FILTER(WHERE cubierto AND obtenido=ANY(valores)) AS aciertos,
 round(100.0*count(*) FILTER(WHERE cubierto AND obtenido=ANY(valores))/
       nullif(count(*) FILTER(WHERE cubierto),0),4) AS pct_comparables,
 count(*) FILTER(WHERE NOT cubierto) AS faltantes,
 count(*) FILTER(WHERE variantes>1) AS claves_ambiguas
FROM c GROUP BY campo ORDER BY campo;
SELECT fuente_semanas,count(*) FROM calc.plan_mes_traza GROUP BY fuente_semanas;
COMMIT;
