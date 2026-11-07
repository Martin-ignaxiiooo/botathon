-- B-11 · Auditoría con triggers: cada INSERT / UPDATE / DELETE en param.* (todas sus tablas), core.asignacion y
-- calc.escenario deja una fila en audit.log:
--   tabla = esquema.tabla · operacion = insert | update | delete · usuario = session_user (quien se conectó, aunque
--   el cambio venga de una función SECURITY DEFINER) · motivo = current_setting('planbot.motivo') (Contrato 2:
--   antes de cambios auditables, SELECT set_config('planbot.motivo', '<motivo>', false)) · antes / despues = fila jsonb.
-- Un UPDATE que no cambia nada no se registra (la semilla se puede repetir sin llenar el log).
-- audit.registrar es SECURITY DEFINER: bot_carga y planificador no necesitan permiso de escritura en audit.log.
CREATE OR REPLACE FUNCTION audit.registrar() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_antes   jsonb;
    v_despues jsonb;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN v_antes := to_jsonb(OLD); END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN v_despues := to_jsonb(NEW); END IF;
    IF TG_OP = 'UPDATE' AND v_antes = v_despues THEN RETURN NULL; END IF;
    INSERT INTO audit.log (tabla, operacion, usuario, motivo, antes, despues)
    VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, lower(TG_OP), session_user,
            nullif(current_setting('planbot.motivo', true), ''), v_antes, v_despues);
    RETURN NULL;
END $$;

REVOKE ALL ON FUNCTION audit.registrar() FROM PUBLIC;

-- Triggers (idempotente). Toda tabla nueva de param.* queda auditada al volver a correr migrar.ps1.
DO $$
DECLARE t regclass;
BEGIN
    FOR t IN
        SELECT c.oid::regclass FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r', 'p') AND n.nspname = 'param'
        UNION ALL SELECT 'core.asignacion'::regclass
        UNION ALL SELECT 'calc.escenario'::regclass
    LOOP
        EXECUTE format('CREATE OR REPLACE TRIGGER auditar AFTER INSERT OR UPDATE OR DELETE ON %s
                        FOR EACH ROW EXECUTE FUNCTION audit.registrar()', t);
    END LOOP;
END $$;
