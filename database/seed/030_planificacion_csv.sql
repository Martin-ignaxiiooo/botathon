-- Seed 030 · Carga 'planificacion' desde data\csv (en el sistema final la hace Blue Prism, P00).
-- Copia los CSV a stg.param_*, stg.excepcion y stg.esperado y llama cargar_parametros. Idempotente:
-- solo carga si no existe la carga con este hash (cambiar el hash si cambian los CSV).
-- \copy usa rutas relativas a la raíz del repo (los scripts hacen Push-Location; en Docker cwd = /planbot).
\set hash_seed 'seed:planificacion:csv-v1'

SELECT NOT EXISTS (SELECT 1 FROM stg.carga WHERE hash = :'hash_seed') AS cargar_seed \gset
\if :cargar_seed

BEGIN;
INSERT INTO stg.carga (tipo, archivo, hash, estado)
VALUES ('planificacion', 'data/csv (Nac - Planificacion Asistencial x mes.xlsx)', :'hash_seed', 'recibida')
RETURNING carga_id AS seed_carga \gset

CREATE TEMP TABLE t_cargo      (cod_esp text, cargo text, unidad text, min_directa int, min_indirecta int, tramo smallint,
                                pct_dir numeric, pct_ind numeric, pct_nas numeric) ON COMMIT DROP;
CREATE TEMP TABLE t_asignacion (tipo text, horas_semana numeric, requiere_dmn boolean, descripcion text) ON COMMIT DROP;
CREATE TEMP TABLE t_calendario (mes smallint, zona text, dias int, inhabiles int, dias_habiles int, semanas numeric) ON COMMIT DROP;
CREATE TEMP TABLE t_grupal     (cod_esp text, grupo_it text, pct_grupal numeric, pacientes_grupo numeric) ON COMMIT DROP;
CREATE TEMP TABLE t_excepcion  (persona_id bigint, it int, mes smallint, horas numeric) ON COMMIT DROP;
CREATE TEMP TABLE t_esperado   (persona_id bigint, it int, campo text, mes smallint, valor numeric) ON COMMIT DROP;

\copy t_cargo      FROM 'data/csv/param_cargo.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy t_asignacion FROM 'data/csv/param_asignacion.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy t_calendario FROM 'data/csv/param_calendario.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy t_grupal     FROM 'data/csv/param_grupal.csv'     WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy t_excepcion  FROM 'data/csv/excepciones.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy t_esperado   FROM 'data/csv/esperado.csv'         WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

INSERT INTO stg.param_cargo      SELECT :seed_carga, * FROM t_cargo;
INSERT INTO stg.param_asignacion SELECT :seed_carga, * FROM t_asignacion;
INSERT INTO stg.param_calendario SELECT :seed_carga, * FROM t_calendario;
INSERT INTO stg.param_grupal     SELECT :seed_carga, * FROM t_grupal;
INSERT INTO stg.excepcion        SELECT :seed_carga, * FROM t_excepcion;
INSERT INTO stg.esperado         SELECT :seed_carga, * FROM t_esperado;

SELECT api.cargar_parametros(:seed_carga) AS version_creada \gset
\echo 'Seed planificacion: carga' :seed_carga '-> versión' :version_creada
COMMIT;

\endif
