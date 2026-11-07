-- B-12 · Flujo de escenarios: borrador -> (simular) pendiente -> (decidir) aprobado | rechazado -> (aplicar) aplicado.
-- Estados alineados con la pantalla Parámetros del front (docs\progreso-front.md, C-09).
-- cambios (jsonb): {"general": {"<clave>": <valor>, ...}} = valores propuestos para param.general vigente.
-- impacto (jsonb): lo deja simular(): [{it, instituto, atenciones_antes, atenciones_despues, meta_antes, meta_despues,
--   diferencia_meta}] (antes = calc.plan_mes al simular, después = calc.plan_mes_escenario).
ALTER TABLE calc.escenario DROP CONSTRAINT IF EXISTS escenario_estado_check;
UPDATE calc.escenario SET estado = 'pendiente' WHERE estado = 'simulado';
UPDATE calc.escenario SET estado = 'rechazado' WHERE estado = 'descartado';
ALTER TABLE calc.escenario ADD CONSTRAINT escenario_estado_check
    CHECK (estado IN ('borrador', 'pendiente', 'aprobado', 'rechazado', 'aplicado'));

ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS impacto         jsonb;
ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS simulado_en     timestamptz;
ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS decision_motivo text;
ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS decidido_por    text;
ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS decidido_en     timestamptz;
ALTER TABLE calc.escenario ADD COLUMN IF NOT EXISTS aplicado_en     timestamptz;
