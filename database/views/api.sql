-- B-09 · Contrato 3 v1.1 (0fb3a93:docs/contratos.md).
-- Proyecciones del plan mensual: no recalculan las reglas B ni usan esperado.
-- Los LEFT JOIN por PK conservan planes sin dotación/catálogo, sin multiplicarlos.
-- No faltan columnas en V002/V003/V004: no se requieren NULL de sustitución TODO.
BEGIN;

CREATE OR REPLACE VIEW api.v_kpi AS
SELECT sum(p.ate_dir) AS atenciones_plan,
       sum(p.meta) AS meta,
       sum(p.horas_dir) / nullif(sum(p.horas_contratadas), 0) AS foja,
       sum(p.horas_contratadas) AS horas_contratadas,
       count(DISTINCT p.persona_id) FILTER (
           WHERE p.mes = (SELECT max(mes) FROM calc.plan_mes)
       ) AS dotacion,
       max(c.recibido_en) AS ultima_carga
FROM calc.plan_mes p
LEFT JOIN core.dotacion_mes d USING (persona_id, it, mes)
LEFT JOIN stg.carga c ON c.carga_id = d.carga_id
HAVING count(*) > 0;
-- Sin plan no se publica una fila nacional ficticia con NULL/cero.
-- Dotación = personas del último mes del plan; horas/atenciones suman el horizonte.
-- Última carga = fecha de los archivos fuente enlazados a ese plan, no de intentos fallidos.

CREATE OR REPLACE VIEW api.v_nacional_mes AS
SELECT p.mes,
       sum(p.ate_dir) AS atenciones_dir,
       sum(p.ate_dir_ind - p.ate_dir) AS atenciones_ind,
       sum(p.meta) AS meta,
       sum(p.horas_dir) AS horas_dir,
       sum(p.horas_ind) AS horas_ind,
       sum(p.horas_nas) AS horas_nas,
       sum(p.horas_dir) / nullif(sum(p.horas_contratadas), 0) AS foja
FROM calc.plan_mes p
GROUP BY p.mes;
-- ate_dir_ind es el total directa + indirecta; no sumar otra vez las directas.
-- FOJA agregado es cociente de sumas, nunca suma/promedio simple de porcentajes.

CREATE OR REPLACE VIEW api.v_instituto_area_mes AS
SELECT p.it,
       coalesce(i.nombre, d.instituto) AS instituto,
       d.area,
       d.cargo,
       p.mes,
       sum(p.ate_dir) AS atenciones_dir,
       sum(p.meta) AS meta,
       sum(p.horas_dir) / nullif(sum(p.horas_contratadas), 0) AS foja,
       count(DISTINCT p.persona_id) AS dotacion,
       sum(p.horas_contratadas) AS horas_contratadas,
       sum(p.horas_dir) AS horas_dir,
       sum(p.horas_ind) AS horas_ind,
       sum(p.horas_nas) AS horas_nas
FROM calc.plan_mes p
LEFT JOIN core.dotacion_mes d USING (persona_id, it, mes)
LEFT JOIN param.instituto i ON i.it = p.it
GROUP BY p.it, coalesce(i.nombre, d.instituto), d.area, d.cargo, p.mes;

CREATE OR REPLACE VIEW api.v_profesional_mes AS
SELECT p.persona_id,
       p.it,
       d.cargo,
       d.area,
       p.mes,
       p.horas_contratadas,
       p.pct_dir_final,
       p.ate_dir AS atenciones_dir,
       p.ate_dir_ind AS atenciones_dir_ind,
       p.meta,
       p.foja
FROM calc.plan_mes p
LEFT JOIN core.dotacion_mes d USING (persona_id, it, mes);

CREATE OR REPLACE VIEW api.v_cambios AS
SELECT carga_id, tipo, persona_id, it, mes_vigencia, antes, despues, detectado_en
FROM core.cambios;

CREATE OR REPLACE VIEW api.v_errores_carga AS
SELECT e.carga_id, c.archivo, e.fila, e.persona_id, e.campo, e.motivo
FROM stg.error_fila e
JOIN stg.carga c ON c.carga_id = e.carga_id;

-- valor es text: números generales convertibles por Number() en el front;
-- reglas compuestas como JSON textual con todas sus propiedades, sin perder campos.
-- Se conservan claves reales (meta/jornada_*), sin inventar aliases del front.
-- Vigencia abierta (vigente_hasta IS NULL), igual que las vistas de cálculo existentes.
CREATE OR REPLACE VIEW api.v_parametros_vigentes AS
SELECT 'param.general'::text AS tabla, g.clave, g.valor::text AS valor,
       g.version, g.vigente_desde
FROM param.general g WHERE g.vigente_hasta IS NULL
UNION ALL
SELECT 'param.cargo_distribucion', c.cargo || '|tramo_' || c.tramo,
       (to_jsonb(c) - 'version' - 'vigente_desde' - 'vigente_hasta')::text,
       c.version, c.vigente_desde
FROM param.cargo_distribucion c WHERE c.vigente_hasta IS NULL
UNION ALL
SELECT 'param.asignacion_catalogo', a.tipo || '|id_' || a.id,
       (to_jsonb(a) - 'version' - 'vigente_desde' - 'vigente_hasta')::text,
       a.version, a.vigente_desde
FROM param.asignacion_catalogo a WHERE a.vigente_hasta IS NULL
UNION ALL
SELECT 'param.calendario_mes', c.zona || '|mes_' || c.mes,
       (to_jsonb(c) - 'version' - 'vigente_desde' - 'vigente_hasta')::text,
       c.version, c.vigente_desde
FROM param.calendario_mes c WHERE c.vigente_hasta IS NULL
UNION ALL
SELECT 'param.grupal', g.cod_esp || '|' || g.grupo_it,
       (to_jsonb(g) - 'version' - 'vigente_desde' - 'vigente_hasta')::text,
       g.version, g.vigente_desde
FROM param.grupal g WHERE g.vigente_hasta IS NULL;

CREATE OR REPLACE VIEW api.v_cuadratura AS
SELECT persona_id, campo, mes, excel, sistema, diferencia, causa
FROM calc.cuadratura;
-- La tabla existe aunque B-10 aún no la pueble; no fabricar comparaciones.

GRANT SELECT ON api.v_kpi, api.v_nacional_mes, api.v_instituto_area_mes,
    api.v_profesional_mes, api.v_cambios, api.v_errores_carga,
    api.v_parametros_vigentes, api.v_cuadratura TO web_lectura;
COMMIT;
