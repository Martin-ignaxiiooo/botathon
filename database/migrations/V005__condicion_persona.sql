-- V005 · core.condicion_persona: datos por persona-IT que el BUK no trae (B-05). Idempotente.
-- Fuente MVP: hoja Dotacion_Asistencial del Excel de planificación (scripts\extraer_condiciones.py).
-- Pendiente de contrato: Blue Prism aún no tiene tabla stg.* para enviar estos campos.
CREATE TABLE IF NOT EXISTS core.condicion_persona (
    persona_id                 bigint NOT NULL,
    it                         int NOT NULL,
    colacion_h                 numeric NOT NULL DEFAULT 0,   -- horas de colación en contrato (se restan de las disponibles)
    dias_semana_contrato       numeric,
    feriado_adicional_dias     numeric NOT NULL DEFAULT 0,   -- B-06 (semanas hábiles jul-dic)
    capacitacion_dias          numeric NOT NULL DEFAULT 0,   -- B-06
    vacaciones_pendientes_dias numeric NOT NULL DEFAULT 0,   -- B-06
    licencia_extensa           text,
    fuente                     text NOT NULL DEFAULT 'excel_planificacion',
    actualizado_en             timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (persona_id, it)
);
