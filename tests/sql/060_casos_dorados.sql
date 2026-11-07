-- 060 · D-05 · Casos dorados: 10 persona-IT del Excel (data\csv\esperado.csv -> stg.esperado de la semilla)
-- que el sistema reproduce exactamente, calculados desde su entrada BUK (filas de abajo, solo persona_id, sin nombres).
-- Compara los 12 campos del Excel: semanales may-dic (pct_dir_final, pct_ind_final, ate_dir_semana, ate_ind_semana,
-- prom_pond_horas, horas_semana_dic) y mensuales (semhab, plan_ate_dir, plan_ate_dir_ind, meta, meta_dir_ind) de
-- los 12 meses. ate_semana_total solo sin atención grupal (con grupal el Excel suma otra cosa, ver B-10).
-- Usa api.cuadratura() de B-10: ningún campo de estos 10 casos debe aparecer como diferencia.
-- Corre en CI (no necesita la base BUK real). ROLLBACK al final. Filas BUK generadas con la carga BUK local 63.
BEGIN;
DO $$
DECLARE v_buk bigint; v_n int; r record; v_esp int;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stg.esperado WHERE campo = 'plan_ate_dir') THEN
        RAISE EXCEPTION 'DORADOS: stg.esperado vacío (falta la semilla 030 con data\csv\esperado.csv)';
    END IF;
    CREATE TEMP TABLE dorado (persona_id bigint, it int, descripcion text) ON COMMIT DROP;
    INSERT INTO dorado VALUES
        (71853::bigint, 12, 'ENFERMERA COORDINADORA, cambio de jornada, asignaciones 6 h'),
        (72379::bigint, 51, 'JEFE TERAPIA OCUPACIONAL, colación 2,5 h, cambio de jornada'),
        (76852::bigint, 11, 'TERAPEUTA OCUPACIONAL, IT 11 zona arica'),
        (73182::bigint, 51, 'MEDICO FISIATRA, cambio de jornada'),
        (71509::bigint, 101, 'PSICOLOGO, colación 2 h'),
        (132962::bigint, 41, 'FONOAUDIOLOGO'),
        (72253::bigint, 81, 'ENFERMERA, cambio de jornada, asignaciones 3,25 h'),
        (125926::bigint, 131, 'KINESIOLOGO, cambio de jornada'),
        (71425::bigint, 91, 'PROFESOR DE ARTE, atención grupal 55 %'),
        (71132::bigint, 131, 'MEDICO FISIATRA, colación 1,5 h');

    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 060 dorados', 'test:060:buk:' || clock_timestamp())
    RETURNING carga_id INTO v_buk;
    INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp)
    SELECT v_buk, b.* FROM (VALUES
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (131, 'San', 71132, 'Santiago', 'Fisiatría', '300202', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2015-04-01', NULL::date, 22, 'MEDICO FISIATRA', 'mwv', 3, 'FI'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (91, 'Tem', 71425, 'Temuco', 'UTAC Unidad de Terapias Artisticas Creativas', '301201', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2012-05-09', NULL::date, 32, 'PROFESOR DE ARTE', 'lmwjv', 5, 'UTAC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (101, 'PMo', 71509, 'Puerto Montt', 'Psicología', '300509', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '1995-03-01', NULL::date, 30, 'PSICOLOGO', 'lmwj', 4, 'PC'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 44, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 44, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 44, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 44, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 42, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 42, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (12, 'Iqu', 71853, 'Iquique', 'Enfermería', '300511', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2014-08-07', NULL::date, 42, 'ENFERMERA COORDINADORA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 44, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 44, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 44, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 44, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 42, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 42, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (81, 'Con', 72253, 'Concepción', 'Enfermería', '300511', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2008-10-13', NULL::date, 42, 'ENFERMERA', 'lmwjv', 5, 'EN'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 44, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 44, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 44, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 44, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 42, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 42, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 72379, 'Valparaíso', 'Terapia Ocupacional', '300503', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '1997-05-07', NULL::date, 42, 'JEFE TERAPIA OCUPACIONAL', 'lmwjv', 5, 'TO'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 27, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 27, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 27, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 27, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 26, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 26, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (51, 'Val', 73182, 'Valparaíso', 'Fisiatría', '300202', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2004-10-01', NULL::date, 26, 'MEDICO FISIATRA', 'wjv', 3, 'FI'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (11, 'Ari', 76852, 'Arica', 'Terapia Ocupacional', '300503', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2017-03-01', NULL::date, 35, 'TERAPEUTA OCUPACIONAL', 'mwjv', 4, 'TO'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 40, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 40, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 40, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 40, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 40, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 35, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (131, 'San', 125926, 'Santiago', 'Kinesiología', '300501', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2022-07-04', NULL::date, 35, 'KINESIOLOGO', 'lmwjv', 5, 'KI'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-01-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-02-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-03-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-04-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-05-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-06-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO'),
    (41, 'Coq', 132962, 'Coquimbo', 'Fonoaudiología', '300510', DATE '2026-07-01', 'Indefinido', 'Titular', DATE '2024-04-03', NULL::date, 25, 'FONOAUDIOLOGO', 'mwj', 3, 'FO')
    ) b(it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp);
    PERFORM api.cargar_dotacion(v_buk);
    PERFORM calc.calcular_plan(1);
    PERFORM api.cuadratura();

    FOR r IN SELECT * FROM dorado LOOP
        SELECT count(*) INTO v_esp FROM stg.esperado
        WHERE carga_id = (SELECT max(carga_id) FROM stg.esperado) AND persona_id = r.persona_id AND it = r.it;
        IF v_esp < 60 THEN
            RAISE EXCEPTION 'DORADOS: % / % tiene solo % valores en el Excel', r.persona_id, r.it, v_esp;
        END IF;
        IF (SELECT count(*) FROM calc.plan_mes WHERE persona_id = r.persona_id AND it = r.it) <> 12 THEN
            RAISE EXCEPTION 'DORADOS: % / % (%) sin 12 meses de plan', r.persona_id, r.it, r.descripcion;
        END IF;
        SELECT count(*) INTO v_n FROM api.v_cuadratura v
        WHERE v.persona_id = r.persona_id
          AND NOT (v.campo = 'ate_semana_total' AND v.causa = 'grupal');
        IF v_n > 0 THEN
            SELECT string_agg(campo || coalesce('/' || mes, '') || ' excel ' || excel || ' sistema ' || coalesce(sistema::text, '-'), '; ')
            INTO r.descripcion FROM (SELECT * FROM api.v_cuadratura WHERE persona_id = r.persona_id LIMIT 5) x;
            RAISE EXCEPTION 'DORADOS: % / % difiere del Excel en % campos: %', r.persona_id, r.it, v_n, r.descripcion;
        END IF;
    END LOOP;
    -- un valor concreto a la vista: el plan anual de los 10 casos = el del Excel
    SELECT count(*) INTO v_n FROM dorado d
    WHERE (SELECT sum(ate_dir) FROM calc.plan_mes p WHERE p.persona_id = d.persona_id AND p.it = d.it)
       <> (SELECT sum(t) FROM (SELECT mes, max(valor) t FROM stg.esperado e
                               WHERE e.carga_id = (SELECT max(carga_id) FROM stg.esperado)
                                 AND e.persona_id = d.persona_id AND e.it = d.it AND e.campo = 'plan_ate_dir' GROUP BY mes) m);
    IF v_n > 0 THEN RAISE EXCEPTION 'DORADOS: % casos con plan anual distinto al Excel', v_n; END IF;
    RAISE NOTICE 'DORADOS OK: 10 casos idénticos al Excel en los 12 campos y 12 meses';
END
$$;
ROLLBACK;
