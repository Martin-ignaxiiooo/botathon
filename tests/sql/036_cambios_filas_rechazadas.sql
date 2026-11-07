-- 036 · detectar_cambios ignora las filas que cargar_dotacion rechaza (sintético, ROLLBACK).
-- Caso de 03_errores.xlsx: una fila con 'CARGO INEXISTENTE' salía como cambio_cargo y una fecha de término
-- anterior al ingreso podía salir como cambio de vigencia. Son errores de la carga, no cambios de la persona.
BEGIN;
DO $$
DECLARE v_a bigint; v_b bigint; v_n int; v_lista text;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 036 A', 'test:036:a:' || clock_timestamp())
    RETURNING carga_id INTO v_a;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, horas_semanales, cargo, dias_jornada)
    SELECT v_a, 11, p, make_date(2026, m, 1), DATE '2015-04-01', 40, 'MEDICO FISIATRA', 'lmwjv'
    FROM unnest(ARRAY[900360, 900361, 900362]) p, generate_series(1, 7) m;
    PERFORM api.cargar_dotacion(v_a);

    -- B = A con dos filas erróneas en enero: 900360 cargo inexistente, 900361 término antes del ingreso;
    -- y un cambio real: 900362 pasa a 30 h desde mayo
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 036 B', 'test:036:b:' || clock_timestamp())
    RETURNING carga_id INTO v_b;
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada)
    SELECT v_b, 11, p, make_date(2026, m, 1), DATE '2015-04-01',
           CASE WHEN p = 900361 AND m = 1 THEN DATE '2015-03-31' END,
           CASE WHEN p = 900362 AND m >= 5 THEN 30 ELSE 40 END,
           CASE WHEN p = 900360 AND m = 1 THEN 'CARGO INEXISTENTE' ELSE 'MEDICO FISIATRA' END, 'lmwjv'
    FROM unnest(ARRAY[900360, 900361, 900362]) p, generate_series(1, 7) m;
    PERFORM api.cargar_dotacion(v_b);

    SELECT count(*), string_agg(tipo || ':' || persona_id || '/' || mes_vigencia, ', ')
    INTO v_n, v_lista FROM api.detectar_cambios(v_b);
    IF v_n <> 1 OR v_lista <> 'cambio_jornada:900362/5' THEN
        RAISE EXCEPTION 'CAMBIOS 036: se espera solo cambio_jornada:900362/5, llegó % (%)', v_n, v_lista;
    END IF;
    IF (SELECT count(*) FROM stg.error_fila WHERE carga_id = v_b) <> 2 THEN
        RAISE EXCEPTION 'CAMBIOS 036: las 2 filas erróneas deben quedar en stg.error_fila';
    END IF;
    RAISE NOTICE 'CAMBIOS 036 OK (filas rechazadas no son cambios; el cambio real sí)';
END
$$;
ROLLBACK;
