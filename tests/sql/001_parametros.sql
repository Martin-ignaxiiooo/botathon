-- 001 · Parámetros (B-03): seed de general e institutos, carga de CSV, versionado y validación de sumas.
BEGIN;
DO $$
DECLARE
    v_vigente int;
    v_n       int;
    v_meta    numeric;
    v_carga   bigint;
    v_ver     int;
    v_ver2    int;
BEGIN
    -- Una sola versión vigente
    SELECT count(*), max(version) INTO v_n, v_vigente FROM param.version WHERE vigente_hasta IS NULL;
    IF v_n <> 1 THEN RAISE EXCEPTION 'PARAM: hay % versiones vigentes (se espera 1)', v_n; END IF;

    -- param.general: 12 claves y meta = 0.9
    SELECT count(*) INTO v_n FROM param.general WHERE version = v_vigente;
    IF v_n <> 12 THEN RAISE EXCEPTION 'PARAM: param.general vigente tiene % claves (se esperan 12)', v_n; END IF;
    SELECT valor INTO v_meta FROM param.general WHERE version = v_vigente AND clave = 'meta';
    IF v_meta IS DISTINCT FROM 0.9 THEN RAISE EXCEPTION 'PARAM: meta = % (se espera 0.9)', v_meta; END IF;

    -- 16 institutos; 81 y 131 San-Con
    SELECT count(*) INTO v_n FROM param.instituto;
    IF v_n <> 16 THEN RAISE EXCEPTION 'PARAM: % institutos (se esperan 16)', v_n; END IF;
    SELECT count(*) INTO v_n FROM param.instituto WHERE grupo_it = 'San-Con';
    IF v_n <> 2 THEN RAISE EXCEPTION 'PARAM: % institutos San-Con (se esperan 2: 81 y 131)', v_n; END IF;

    -- CSV cargados en la versión vigente
    SELECT count(*) INTO v_n FROM param.cargo_distribucion WHERE version = v_vigente;
    IF v_n <> 258 THEN RAISE EXCEPTION 'PARAM: % filas en cargo_distribucion (se esperan 258)', v_n; END IF;
    SELECT count(*) INTO v_n FROM param.calendario_mes WHERE version = v_vigente;
    IF v_n <> 12 THEN RAISE EXCEPTION 'PARAM: % meses en calendario (se esperan 12)', v_n; END IF;
    SELECT count(*) INTO v_n FROM param.grupal WHERE version = v_vigente;
    IF v_n <> 10 THEN RAISE EXCEPTION 'PARAM: % filas grupal (se esperan 10)', v_n; END IF;
    SELECT count(*) INTO v_n FROM param.asignacion_catalogo WHERE version = v_vigente;
    IF v_n <> 33 THEN RAISE EXCEPTION 'PARAM: % asignaciones en catálogo (se esperan 33)', v_n; END IF;
    SELECT count(*) INTO v_n FROM stg.esperado;
    IF v_n < 31000 THEN RAISE EXCEPTION 'PARAM: stg.esperado con % filas (se esperan ~31.527)', v_n; END IF;

    -- Todo cargo homologado existe en los 3 tramos de la versión vigente
    SELECT count(*) INTO v_n
    FROM param.cargo_homologado h
    WHERE (SELECT count(*) FROM param.cargo_distribucion d WHERE d.version = v_vigente AND d.cargo = h.cargo) <> 3;
    IF v_n > 0 THEN RAISE EXCEPTION 'PARAM: % cargos homologados sin sus 3 tramos en cargo_distribucion', v_n; END IF;

    -- Carga de parámetros parcial con un cargo inválido: versión nueva, error a stg.error_fila, se hereda lo demás
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('parametros', 'prueba', 'test:001:' || clock_timestamp())
    RETURNING carga_id INTO v_carga;
    INSERT INTO stg.param_cargo (carga_id, cod_esp, cargo, unidad, min_directa, min_indirecta, tramo, pct_dir, pct_ind, pct_nas)
    VALUES (v_carga, 'KI', 'KINESIOLOGO', 'KINESIOLOGÍA', 40, 30, 1, 0.70, 0.10, 0.25),   -- suma 1.05: inválido
           (v_carga, 'PC', 'PSICOLOGO',   'PSICOLOGÍA',   45, 30, 1, 0.60, 0.15, 0.25);   -- válido
    v_ver := api.cargar_parametros(v_carga);
    IF v_ver <= v_vigente THEN RAISE EXCEPTION 'PARAM: no se creó versión nueva (% <= %)', v_ver, v_vigente; END IF;

    SELECT count(*) INTO v_n FROM stg.error_fila WHERE carga_id = v_carga;
    IF v_n <> 1 THEN RAISE EXCEPTION 'PARAM: % errores de suma (se espera 1)', v_n; END IF;

    SELECT count(*) INTO v_n FROM param.version WHERE vigente_hasta IS NULL;
    IF v_n <> 1 THEN RAISE EXCEPTION 'PARAM: tras la carga hay % versiones vigentes', v_n; END IF;

    SELECT count(*) INTO v_n FROM param.cargo_distribucion WHERE version = v_ver;
    IF v_n <> 258 THEN RAISE EXCEPTION 'PARAM: versión nueva con % cargos (se esperan 258 heredados)', v_n; END IF;
    SELECT count(*) INTO v_n FROM param.cargo_distribucion
    WHERE version = v_ver AND cargo = 'PSICOLOGO' AND tramo = 1 AND pct_dir = 0.60 AND min_directa = 45;
    IF v_n <> 1 THEN RAISE EXCEPTION 'PARAM: el cargo válido no se aplicó'; END IF;
    SELECT count(*) INTO v_n FROM param.cargo_distribucion a JOIN param.cargo_distribucion b
        ON b.version = v_vigente AND b.cargo = a.cargo AND b.tramo = a.tramo
    WHERE a.version = v_ver AND a.cargo = 'KINESIOLOGO' AND a.tramo = 1 AND a.pct_dir = b.pct_dir;
    IF v_n <> 1 THEN RAISE EXCEPTION 'PARAM: el cargo inválido no conservó su valor anterior'; END IF;
    SELECT count(*) INTO v_n FROM param.general WHERE version = v_ver;
    IF v_n <> 12 THEN RAISE EXCEPTION 'PARAM: param.general no se heredó (% claves)', v_n; END IF;

    -- Idempotente por carga
    v_ver2 := api.cargar_parametros(v_carga);
    IF v_ver2 <> v_ver THEN RAISE EXCEPTION 'PARAM: segunda llamada creó otra versión (% vs %)', v_ver2, v_ver; END IF;

    RAISE NOTICE 'PARAMETROS OK (versión vigente %)', v_vigente;
END
$$;
ROLLBACK;
