-- B-12 · Escenarios de ejemplo para la demo (no es semilla: necesita el plan calculado con la base BUK).
-- Lo corre instalar_sin_docker.ps1 -CargarBukPrueba después de recalcular(1). Idempotente (busca por nombre).
--   1. Meta de gestión 90 % -> 92 %          -> pendiente (espera decisión en la pantalla Parámetros)
--   2. Meta de gestión 90 % -> 91 %          -> aprobado  (lo aplicaría Blue Prism con aplicar_escenario)
--   3. Meta de gestión 90 % -> 95 %          -> rechazado
-- (de param.general solo 'meta' mueve el plan: las demás claves tienen valor propio por cargo o son informativas)
-- Los valores de las claves salen de param.general; aquí solo se proponen valores nuevos.
DO $$
DECLARE r record; v_id bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM calc.plan_mes) THEN
        RAISE NOTICE 'ESCENARIOS DEMO: calc.plan_mes vacío (falta cargar BUK y recalcular); se omiten';
        RETURN;
    END IF;
    FOR r IN SELECT * FROM (VALUES
        ('demo_meta_92', 'Subir la meta de gestión de 90 % a 92 % de las atenciones planificadas',
         '{"general": {"meta": 0.92}}'::jsonb, NULL::text, NULL::text),
        ('demo_meta_91', 'Subir la meta de gestión de 90 % a 91 % de las atenciones planificadas',
         '{"general": {"meta": 0.91}}'::jsonb, 'aprobar', 'Alza gradual acordada con las jefaturas de los institutos'),
        ('demo_meta_95', 'Subir la meta de gestión de 90 % a 95 % de las atenciones planificadas',
         '{"general": {"meta": 0.95}}'::jsonb, 'rechazar', 'No es alcanzable con la dotación actual: se revisa en 2027')
    ) x(nombre, descripcion, cambios, decision, motivo) LOOP
        PERFORM set_config('planbot.motivo', 'escenario de ejemplo para la demo', true);
        SELECT escenario_id INTO v_id FROM calc.escenario WHERE nombre = r.nombre;
        IF v_id IS NULL THEN
            INSERT INTO calc.escenario (nombre, descripcion, cambios) VALUES (r.nombre, r.descripcion, r.cambios)
            RETURNING escenario_id INTO v_id;
        END IF;
        IF (SELECT estado FROM calc.escenario WHERE escenario_id = v_id) IN ('borrador', 'pendiente') THEN
            PERFORM api.simular(v_id);
            IF r.decision IS NOT NULL THEN
                PERFORM api.decidir_escenario(v_id, r.decision, r.motivo);
            END IF;
        END IF;
    END LOOP;
    RAISE NOTICE 'ESCENARIOS DEMO: % escenarios (%)', (SELECT count(*) FROM calc.escenario WHERE nombre LIKE 'demo_%'),
        (SELECT string_agg(nombre || '=' || estado, ', ' ORDER BY escenario_id) FROM calc.escenario WHERE nombre LIKE 'demo_%');
END
$$;
