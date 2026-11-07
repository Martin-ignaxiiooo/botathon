-- Contrato 2 · cargar_parametros(p_carga_id bigint) returns int (versión creada). Lo llaman P00 y P09.
-- Crea una versión nueva de param.*, cierra la anterior y copia lo que trae stg.param_* de esa carga.
-- Lo que la carga no trae se hereda de la versión anterior (merge por clave). param.general siempre se hereda.
-- Cargos cuyo pct_dir + pct_ind + pct_nas no suma 1 -> stg.error_fila y no se aplican.
-- Llamarla dos veces con la misma carga devuelve la misma versión (idempotente).
CREATE OR REPLACE FUNCTION api.cargar_parametros(p_carga_id bigint)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_tipo      text;
    v_anterior  int;
    v_nueva     int;
    v_hoy       date := current_date;
    v_leidas    int;
    v_errores   int;
    c_tolerancia constant numeric := 1e-6;   -- tolerancia numérica de la suma (no es regla de negocio)
BEGIN
    SELECT tipo INTO v_tipo FROM stg.carga WHERE carga_id = p_carga_id;
    IF v_tipo IS NULL THEN
        RAISE EXCEPTION 'cargar_parametros: no existe la carga %', p_carga_id;
    END IF;
    IF v_tipo NOT IN ('planificacion', 'parametros') THEN
        RAISE EXCEPTION 'cargar_parametros: la carga % es de tipo % (se espera planificacion o parametros)', p_carga_id, v_tipo;
    END IF;

    -- Idempotente: si esta carga ya generó versión, se devuelve esa.
    SELECT version INTO v_nueva FROM param.version WHERE carga_id = p_carga_id;
    IF v_nueva IS NOT NULL THEN
        RETURN v_nueva;
    END IF;

    -- Validación de sumas
    DELETE FROM stg.error_fila WHERE carga_id = p_carga_id AND campo = 'pct_dir+pct_ind+pct_nas';
    INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo)
    SELECT p_carga_id, n, NULL, 'pct_dir+pct_ind+pct_nas',
           format('%s tramo %s: %s', cargo, tramo, coalesce(pct_dir, 0) + coalesce(pct_ind, 0) + coalesce(pct_nas, 0)),
           'La distribución directa + indirecta + NAS del cargo no suma 1'
    FROM (SELECT *, row_number() OVER (ORDER BY cargo, tramo) AS n
          FROM stg.param_cargo WHERE carga_id = p_carga_id) s
    WHERE pct_dir IS NULL OR pct_ind IS NULL OR pct_nas IS NULL
       OR abs(pct_dir + pct_ind + pct_nas - 1) > c_tolerancia;
    GET DIAGNOSTICS v_errores = ROW_COUNT;

    -- Versión nueva y cierre de la anterior
    SELECT max(version) INTO v_anterior FROM param.version WHERE vigente_hasta IS NULL;

    INSERT INTO param.version (carga_id, descripcion, vigente_desde)
    VALUES (p_carga_id, format('Carga %s (%s)', p_carga_id, v_tipo), v_hoy)
    RETURNING version INTO v_nueva;

    UPDATE param.version SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL AND version <> v_nueva;
    UPDATE param.cargo_distribucion  SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL;
    UPDATE param.asignacion_catalogo SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL;
    UPDATE param.calendario_mes      SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL;
    UPDATE param.grupal              SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL;
    UPDATE param.general             SET vigente_hasta = v_hoy WHERE vigente_hasta IS NULL;

    -- cargo_distribucion: válidos de la carga + lo anterior que la carga no trae
    INSERT INTO param.cargo_distribucion (version, vigente_desde, cod_esp, cargo, unidad, min_directa, min_indirecta,
                                          tramo, pct_dir, pct_ind, pct_nas)
    SELECT DISTINCT ON (cargo, tramo) v_nueva, v_hoy, nullif(trim(cod_esp), ''), trim(cargo), unidad,
           min_directa, min_indirecta, tramo, pct_dir, pct_ind, pct_nas
    FROM stg.param_cargo
    WHERE carga_id = p_carga_id AND cargo IS NOT NULL AND tramo IN (1, 2, 3)
      AND pct_dir IS NOT NULL AND pct_ind IS NOT NULL AND pct_nas IS NOT NULL
      AND abs(pct_dir + pct_ind + pct_nas - 1) <= c_tolerancia
    ORDER BY cargo, tramo;

    INSERT INTO param.cargo_distribucion (version, vigente_desde, cod_esp, cargo, unidad, min_directa, min_indirecta,
                                          tramo, pct_dir, pct_ind, pct_nas)
    SELECT v_nueva, v_hoy, a.cod_esp, a.cargo, a.unidad, a.min_directa, a.min_indirecta, a.tramo, a.pct_dir, a.pct_ind, a.pct_nas
    FROM param.cargo_distribucion a
    WHERE a.version = v_anterior
    ON CONFLICT (version, cargo, tramo) DO NOTHING;

    -- asignacion_catalogo: si la carga trae catálogo, lo reemplaza entero; si no, se hereda
    IF EXISTS (SELECT 1 FROM stg.param_asignacion WHERE carga_id = p_carga_id) THEN
        INSERT INTO param.asignacion_catalogo (version, vigente_desde, tipo, horas_semana, requiere_dmn, descripcion)
        SELECT v_nueva, v_hoy, trim(tipo), horas_semana, requiere_dmn, descripcion
        FROM stg.param_asignacion WHERE carga_id = p_carga_id AND tipo IS NOT NULL;
    ELSE
        INSERT INTO param.asignacion_catalogo (version, vigente_desde, tipo, horas_semana, requiere_dmn, descripcion)
        SELECT v_nueva, v_hoy, tipo, horas_semana, requiere_dmn, descripcion
        FROM param.asignacion_catalogo WHERE version = v_anterior;
    END IF;

    -- calendario_mes: merge por (mes, zona)
    INSERT INTO param.calendario_mes (version, vigente_desde, mes, zona, dias, inhabiles, dias_habiles, semanas)
    SELECT DISTINCT ON (mes, coalesce(nullif(trim(zona), ''), 'general'))
           v_nueva, v_hoy, mes, coalesce(nullif(trim(zona), ''), 'general'), dias, inhabiles, dias_habiles, semanas
    FROM stg.param_calendario
    WHERE carga_id = p_carga_id AND mes BETWEEN 1 AND 12 AND semanas IS NOT NULL
    ORDER BY mes, coalesce(nullif(trim(zona), ''), 'general');

    INSERT INTO param.calendario_mes (version, vigente_desde, mes, zona, dias, inhabiles, dias_habiles, semanas)
    SELECT v_nueva, v_hoy, mes, zona, dias, inhabiles, dias_habiles, semanas
    FROM param.calendario_mes WHERE version = v_anterior
    ON CONFLICT (version, mes, zona) DO NOTHING;

    -- grupal: merge por (cod_esp, grupo_it)
    INSERT INTO param.grupal (version, vigente_desde, cod_esp, grupo_it, pct_grupal, pacientes_grupo)
    SELECT DISTINCT ON (trim(cod_esp), trim(grupo_it))
           v_nueva, v_hoy, trim(cod_esp), trim(grupo_it), pct_grupal, pacientes_grupo
    FROM stg.param_grupal
    WHERE carga_id = p_carga_id AND cod_esp IS NOT NULL AND trim(grupo_it) IN ('San-Con', 'otros')
    ORDER BY trim(cod_esp), trim(grupo_it);

    INSERT INTO param.grupal (version, vigente_desde, cod_esp, grupo_it, pct_grupal, pacientes_grupo)
    SELECT v_nueva, v_hoy, cod_esp, grupo_it, pct_grupal, pacientes_grupo
    FROM param.grupal WHERE version = v_anterior
    ON CONFLICT (version, cod_esp, grupo_it) DO NOTHING;

    -- general: se hereda siempre (lo cambian los escenarios, B-12)
    INSERT INTO param.general (version, vigente_desde, clave, valor, descripcion)
    SELECT v_nueva, v_hoy, clave, valor, descripcion
    FROM param.general WHERE version = v_anterior;

    -- Conteos en stg.carga
    SELECT (SELECT count(*) FROM stg.param_cargo      WHERE carga_id = p_carga_id)
         + (SELECT count(*) FROM stg.param_asignacion WHERE carga_id = p_carga_id)
         + (SELECT count(*) FROM stg.param_calendario WHERE carga_id = p_carga_id)
         + (SELECT count(*) FROM stg.param_grupal     WHERE carga_id = p_carga_id)
    INTO v_leidas;
    UPDATE stg.carga
    SET estado = 'aplicada', leidas = v_leidas, validas = v_leidas - v_errores, con_error = v_errores
    WHERE carga_id = p_carga_id;

    RETURN v_nueva;
END
$$;

REVOKE ALL ON FUNCTION api.cargar_parametros(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.cargar_parametros(bigint) TO bot_carga;
