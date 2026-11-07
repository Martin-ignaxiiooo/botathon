-- Tras RESTAURAR 01, entregar 03 y completar la carga. No usar estado posterior a 02.
\set ON_ERROR_STOP on
\if :{?carga_id}
\else
\prompt 'carga_id observado de 03_errores: ' carga_id
\endif
BEGIN;
CREATE TEMP TABLE b09_errores(persona_id bigint,campo text,motivo text) ON COMMIT DROP;
\copy b09_errores FROM 'data/buk/esperado_errores.csv' CSV HEADER
SELECT now(),* FROM stg.carga WHERE carga_id=:'carga_id'::bigint;
SELECT fila,persona_id,campo,motivo FROM api.v_errores_carga
WHERE carga_id=:'carga_id'::bigint ORDER BY fila,campo;
-- CERO faltantes; los textos no están fijados literalmente por contrato.
SELECT e.* FROM b09_errores e WHERE NOT EXISTS (
 SELECT 1 FROM api.v_errores_carga r WHERE r.carga_id=:'carga_id'::bigint
 AND r.persona_id=e.persona_id AND r.campo=e.campo
);
SELECT e.*,r.fila,r.motivo AS motivo_observado FROM b09_errores e
LEFT JOIN api.v_errores_carga r ON r.carga_id=:'carga_id'::bigint
 AND r.persona_id=e.persona_id AND r.campo=e.campo;
SELECT c.carga_id,c.leidas,c.validas,c.con_error,
 (SELECT count(*) FROM stg.buk_fila b WHERE b.carga_id=c.carga_id) AS filas_stg,
 (SELECT count(DISTINCT e.fila) FROM stg.error_fila e WHERE e.carga_id=c.carga_id) AS filas_con_error,
 (SELECT count(*) FROM stg.error_fila e WHERE e.carga_id=c.carga_id) AS mensajes_error
FROM stg.carga c WHERE c.carga_id=:'carga_id'::bigint;
-- Debe quedar sin filas inválidas numéricas/fechas ni duplicados en stg validada.
SELECT persona_id,it,periodo,horas_semanales,fecha_ingreso,fecha_termino FROM stg.buk_fila
WHERE carga_id=:'carga_id'::bigint AND (horas_semanales<=0
 OR fecha_termino<fecha_ingreso);
SELECT persona_id,it,periodo,count(*) FROM stg.buk_fila WHERE carga_id=:'carga_id'::bigint
GROUP BY persona_id,it,periodo HAVING count(*)>1;
-- stg.buk_fila no tiene fila original: no inferir que toda una persona fue rechazada;
-- otras filas/meses suyos pueden ser válidos. Guardar el mapeo de fila desde BP.
ROLLBACK;
