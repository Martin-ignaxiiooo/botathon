-- Demo · limpieza para volver al estado "antes de la demo" (lo llama scripts\reiniciar_demo.ps1; repetible).
-- Borra todo lo que dejan las cargas BUK y la demo: cargas tipo 'buk' (con sus filas y errores), dotación,
-- personas, cambios, alertas, plan, cuadratura y escenarios; deshace las versiones de parámetros creadas por
-- aplicar_escenario() y reabre la versión anterior. Conserva: parámetros sembrados, Excel de planificación
-- (stg.esperado), asignaciones, condiciones por persona y audit.log (los borrados quedan auditados).
-- Todo en una transacción: si algo falla, la base queda como estaba.
BEGIN;
SELECT set_config('planbot.motivo', 'reiniciar demo', true);

-- 1 · parámetros: deshacer versiones creadas por escenarios aplicados
CREATE TEMP TABLE t_ver_esc ON COMMIT DROP AS SELECT version FROM param.version WHERE escenario_id IS NOT NULL;
DELETE FROM param.cargo_distribucion  WHERE version IN (SELECT version FROM t_ver_esc);
DELETE FROM param.asignacion_catalogo WHERE version IN (SELECT version FROM t_ver_esc);
DELETE FROM param.calendario_mes      WHERE version IN (SELECT version FROM t_ver_esc);
DELETE FROM param.grupal              WHERE version IN (SELECT version FROM t_ver_esc);
DELETE FROM param.general             WHERE version IN (SELECT version FROM t_ver_esc);
DELETE FROM param.version             WHERE version IN (SELECT version FROM t_ver_esc);
CREATE TEMP TABLE t_ver_base ON COMMIT DROP AS SELECT max(version) AS version FROM param.version;
-- si quedó cerrada por un escenario, se reabre (con todas sus filas)
UPDATE param.version            SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;
UPDATE param.cargo_distribucion  SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;
UPDATE param.asignacion_catalogo SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;
UPDATE param.calendario_mes      SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;
UPDATE param.grupal              SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;
UPDATE param.general             SET vigente_hasta = NULL WHERE version = (SELECT version FROM t_ver_base) AND vigente_hasta IS NOT NULL;

-- 2 · escenarios, plan y cuadratura
DELETE FROM calc.escenario;                 -- en cascada calc.plan_mes_escenario
DELETE FROM calc.plan_mes;
DELETE FROM calc.plan_mes_traza;
DELETE FROM calc.cuadratura;

-- 3 · cargas BUK y todo lo que cuelga de ellas
CREATE TEMP TABLE t_buk ON COMMIT DROP AS SELECT carga_id FROM stg.carga WHERE tipo = 'buk';
DELETE FROM core.cambios       WHERE carga_id IN (SELECT carga_id FROM t_buk) OR carga_anterior IN (SELECT carga_id FROM t_buk);
DELETE FROM core.alerta        WHERE carga_id IN (SELECT carga_id FROM t_buk);
DELETE FROM core.dotacion_mes;
DELETE FROM core.persona;
DELETE FROM stg.carga          WHERE carga_id IN (SELECT carga_id FROM t_buk);   -- en cascada buk_fila y error_fila

SELECT (SELECT count(*) FROM stg.carga WHERE tipo = 'buk') AS cargas_buk,
       (SELECT count(*) FROM core.dotacion_mes) AS dotacion,
       (SELECT max(version) FROM param.version WHERE vigente_hasta IS NULL) AS version_param_vigente,
       (SELECT valor FROM param.general WHERE vigente_hasta IS NULL AND clave = 'meta') AS meta_vigente;
COMMIT;
