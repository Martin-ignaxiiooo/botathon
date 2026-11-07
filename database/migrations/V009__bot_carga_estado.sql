-- Cierre demo · Blue Prism marca una carga con error en su recuperación (guía de Lucas, Q09):
--   UPDATE stg.carga SET estado = 'error' WHERE carga_id = CAST(? AS bigint);
-- Solo la columna estado: leidas / validas / con_error los fija cargar_dotacion (no se pisan desde el robot).
GRANT UPDATE (estado) ON stg.carga TO bot_carga;
