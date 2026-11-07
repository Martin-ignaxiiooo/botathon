-- Solo modo nativo (scripts\instalar_sin_docker.ps1). Se ejecuta como superusuario en la base 'postgres'.
-- Variables: -v owner=... -v owner_pwd=... -v db=...  (idempotente)
SELECT format('CREATE ROLE %I LOGIN CREATEROLE', :'owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'owner') \gexec
SELECT format('ALTER ROLE %I LOGIN CREATEROLE PASSWORD %L', :'owner', :'owner_pwd') \gexec

SELECT format('CREATE DATABASE %I OWNER %I ENCODING %L TEMPLATE template0', :'db', :'owner', 'UTF8')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec
SELECT format('ALTER DATABASE %I SET timezone TO %L', :'db', 'America/Santiago') \gexec
