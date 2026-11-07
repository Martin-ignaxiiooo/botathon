-- V002 · Tablas stg.* = Contrato 1 (docs\contratos.md v1.1). NO agregar, quitar ni renombrar columnas.
CREATE TABLE IF NOT EXISTS stg.carga (
    carga_id    bigserial PRIMARY KEY,
    tipo        text NOT NULL CHECK (tipo IN ('buk', 'planificacion', 'parametros', 'asignaciones')),
    archivo     text,
    hash        text UNIQUE,
    recibido_en timestamptz NOT NULL DEFAULT now(),
    estado      text DEFAULT 'recibida',
    leidas      int,
    validas     int,
    con_error   int
);

CREATE TABLE IF NOT EXISTS stg.buk_fila (
    carga_id        bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    it              int,
    instituto       text,
    persona_id      bigint,
    area            text,
    sub_area        text,
    centro_costo    text,
    periodo         date,
    tipo_contrato   text,
    tipo_trabajador text,
    fecha_ingreso   date,
    fecha_termino   date,
    horas_semanales numeric,
    cargo           text,
    dias_jornada    text,
    ndias           int,
    cod_esp         text
);
CREATE INDEX IF NOT EXISTS buk_fila_carga_idx ON stg.buk_fila (carga_id, persona_id, it);

CREATE TABLE IF NOT EXISTS stg.error_fila (
    carga_id   bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    fila       int,
    persona_id bigint,
    campo      text,
    valor      text,
    motivo     text
);
CREATE INDEX IF NOT EXISTS error_fila_carga_idx ON stg.error_fila (carga_id);

CREATE TABLE IF NOT EXISTS stg.param_cargo (
    carga_id      bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    cod_esp       text,
    cargo         text,
    unidad        text,
    min_directa   int,
    min_indirecta int,
    tramo         smallint,   -- 1: >=40 h, 2: 22-40 h, 3: <22 h
    pct_dir       numeric,
    pct_ind       numeric,
    pct_nas       numeric
);

CREATE TABLE IF NOT EXISTS stg.param_asignacion (
    carga_id     bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    tipo         text,
    horas_semana numeric,
    requiere_dmn boolean,
    descripcion  text
);

CREATE TABLE IF NOT EXISTS stg.param_calendario (
    carga_id     bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    mes          smallint,
    zona         text,
    dias         int,
    inhabiles    int,
    dias_habiles int,
    semanas      numeric
);

CREATE TABLE IF NOT EXISTS stg.param_grupal (
    carga_id        bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    cod_esp         text,
    grupo_it        text,     -- 'San-Con' | 'otros'
    pct_grupal      numeric,
    pacientes_grupo numeric
);

CREATE TABLE IF NOT EXISTS stg.excepcion (
    carga_id   bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    persona_id bigint,
    it         int,
    mes        smallint,
    horas      numeric
);

CREATE TABLE IF NOT EXISTS stg.asignacion (
    carga_id    bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    persona_id  bigint,
    it          int,
    tipo        text,
    horas       numeric,
    desde       date,
    hasta       date,
    solicitante text,
    motivo      text,
    estado      text
);

CREATE TABLE IF NOT EXISTS stg.esperado (
    carga_id   bigint NOT NULL REFERENCES stg.carga ON DELETE CASCADE,
    persona_id bigint,
    it         int,
    campo      text,
    mes        smallint,
    valor      numeric
);
CREATE INDEX IF NOT EXISTS esperado_idx ON stg.esperado (carga_id, persona_id, it, campo, mes);

-- Blue Prism (bot_carga) escribe y lee stg.*; actualiza estado y conteos de stg.carga.
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA stg TO bot_carga;
GRANT UPDATE (estado, leidas, validas, con_error) ON stg.carga TO bot_carga;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA stg TO bot_carga;
