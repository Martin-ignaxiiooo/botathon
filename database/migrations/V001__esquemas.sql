-- V001 · Esquemas (idempotente)
CREATE SCHEMA IF NOT EXISTS param AUTHORIZATION owner_planbot;  -- reglas versionadas
CREATE SCHEMA IF NOT EXISTS stg   AUTHORIZATION owner_planbot;  -- crudo (Blue Prism)
CREATE SCHEMA IF NOT EXISTS core  AUTHORIZATION owner_planbot;  -- dotación limpia, cambios, asignaciones
CREATE SCHEMA IF NOT EXISTS calc  AUTHORIZATION owner_planbot;  -- planificación, escenarios, cuadratura
CREATE SCHEMA IF NOT EXISTS audit AUTHORIZATION owner_planbot;  -- log por triggers
CREATE SCHEMA IF NOT EXISTS api   AUTHORIZATION owner_planbot;  -- público (PostgREST)

GRANT USAGE ON SCHEMA stg TO bot_carga;
GRANT USAGE ON SCHEMA api TO bot_carga, web_lectura, planificador;

-- Las funciones nuevas no quedan ejecutables por PUBLIC: cada historia da EXECUTE explícito.
ALTER DEFAULT PRIVILEGES FOR ROLE owner_planbot REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
