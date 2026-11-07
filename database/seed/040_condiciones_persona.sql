-- Seed 040 · Asignaciones y condiciones por persona (datos que el BUK no trae), desde database\seed\csv
-- (generados con scripts\extraer_condiciones.py desde la hoja Dotacion_Asistencial). Idempotente por hash.
\set hash_asig 'seed:asignaciones:excel-v1'

SELECT NOT EXISTS (SELECT 1 FROM stg.carga WHERE hash = :'hash_asig') AS cargar_asig \gset
\if :cargar_asig

BEGIN;
INSERT INTO stg.carga (tipo, archivo, hash, estado)
VALUES ('asignaciones', 'database/seed/csv/asignaciones.csv (Dotacion_Asistencial)', :'hash_asig', 'recibida')
RETURNING carga_id AS seed_asig \gset

CREATE TEMP TABLE t_asig (persona_id bigint, it int, tipo text, horas numeric) ON COMMIT DROP;
\copy t_asig FROM 'database/seed/csv/asignaciones.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
INSERT INTO stg.asignacion (carga_id, persona_id, it, tipo, horas, estado, motivo)
SELECT :seed_asig, persona_id, it, tipo, horas, 'vigente', 'Excel de planificación 2026' FROM t_asig;
SELECT api.cargar_asignaciones(:seed_asig) AS asignaciones_cargadas \gset
\echo 'Seed asignaciones:' :asignaciones_cargadas

CREATE TEMP TABLE t_cond (persona_id bigint, it int, colacion_h numeric, dias_semana_contrato numeric,
    feriado_adicional_dias numeric, capacitacion_dias numeric, vacaciones_pendientes_dias numeric,
    licencia_extensa text) ON COMMIT DROP;
\copy t_cond FROM 'database/seed/csv/condiciones_persona.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
INSERT INTO core.condicion_persona (persona_id, it, colacion_h, dias_semana_contrato, feriado_adicional_dias,
    capacitacion_dias, vacaciones_pendientes_dias, licencia_extensa)
SELECT persona_id, it, coalesce(colacion_h, 0), dias_semana_contrato, coalesce(feriado_adicional_dias, 0),
       coalesce(capacitacion_dias, 0), coalesce(vacaciones_pendientes_dias, 0), nullif(licencia_extensa, '')
FROM t_cond
ON CONFLICT (persona_id, it) DO UPDATE SET
    colacion_h = EXCLUDED.colacion_h, dias_semana_contrato = EXCLUDED.dias_semana_contrato,
    feriado_adicional_dias = EXCLUDED.feriado_adicional_dias, capacitacion_dias = EXCLUDED.capacitacion_dias,
    vacaciones_pendientes_dias = EXCLUDED.vacaciones_pendientes_dias, licencia_extensa = EXCLUDED.licencia_extensa,
    actualizado_en = now();
COMMIT;

\endif
