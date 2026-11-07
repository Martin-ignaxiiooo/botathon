-- V000 · Roles de PlanBot (idempotente).
-- Las claves llegan como variables de psql desde .env: -v bot_pwd=... -v web_pwd=...
-- Se ejecuta como owner_planbot (superusuario en Docker; CREATEROLE en nativo).

-- bot_carga: Blue Prism (INSERT en stg.*, EXECUTE en funciones de carga y recálculo)
SELECT 'CREATE ROLE bot_carga LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bot_carga') \gexec
SELECT format('ALTER ROLE bot_carga LOGIN PASSWORD %L', :'bot_pwd') \gexec

-- web_lectura: PostgREST se conecta con él y lo usa como rol anónimo (SELECT en api.*)
SELECT 'CREATE ROLE web_lectura LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_lectura') \gexec
SELECT format('ALTER ROLE web_lectura LOGIN PASSWORD %L', :'web_pwd') \gexec

-- planificador: rol de grupo (EXECUTE en simular y aplicar_escenario)
SELECT 'CREATE ROLE planificador NOLOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'planificador') \gexec

-- Blue Prism llama las funciones sin prefijo de esquema
ALTER ROLE bot_carga SET search_path = api, stg, public;
ALTER ROLE web_lectura SET search_path = api, public;
ALTER ROLE planificador SET search_path = api, public;

-- La base no queda abierta a PUBLIC
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO bot_carga, web_lectura, planificador', current_database()) \gexec
