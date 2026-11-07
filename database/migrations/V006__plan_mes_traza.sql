-- V006 · Traza del plan mensual (B-06): qué semanas hábiles usó cada fila de calc.plan_mes.
-- No cambia calc.plan_mes (contrato interno de B-12) ni stg.* / api.*. Idempotente.
--   fuente_semanas = 'excel'      -> semhab de stg.esperado (Excel de planificación) para esa persona-IT-mes
--                    'calendario' -> regla general: semanas del mes de param.calendario_mes (zona del IT o 'general')
CREATE TABLE IF NOT EXISTS calc.plan_mes_traza (
    persona_id        bigint   NOT NULL,
    it                int      NOT NULL,
    mes               smallint NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fuente_semanas    text     NOT NULL CHECK (fuente_semanas IN ('excel', 'calendario')),
    semanas_excel     numeric,
    semanas_mes       numeric,
    zona_calendario   text,
    calculado_en      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (persona_id, it, mes)
);
