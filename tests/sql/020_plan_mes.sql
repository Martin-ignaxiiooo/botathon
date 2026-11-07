-- 020 · Plan mensual, meta y FOJA (B-06): calc.calcular_plan(desde_mes) -> calc.plan_mes.
-- Parte 1 (solo con la base BUK real cargada): plan_ate_dir y meta may-dic vs Excel (stg.esperado).
--   Guardia anti-regresión >= 95 % (nivel actual 95,55 %; la capa aislada da 100 %). Evidencia: database\evidencia\b06.
-- Parte 2 (sintético, corre en CI): ejemplo de reglas.md, altas, bajas, cambio de jornada, meses sin contrato,
--   unidades de FOJA y recálculo desde un mes sin tocar los meses anteriores.
DO $$
DECLARE v_total int; v_ate int; v_meta int;
BEGIN
    IF (SELECT count(*) FROM core.dotacion_mes WHERE origen = 'buk') < 3000 THEN
        RAISE NOTICE 'PLAN: base BUK real no cargada; se omite la comparación con el Excel';
        RETURN;
    END IF;
    PERFORM calc.calcular_plan(1);
    WITH e AS (
        SELECT persona_id, it, mes, array_agg(valor) FILTER (WHERE campo = 'plan_ate_dir') AS ate,
               array_agg(valor) FILTER (WHERE campo = 'meta') AS meta
        FROM stg.esperado WHERE mes >= 5 GROUP BY 1, 2, 3)
    SELECT count(*), count(*) FILTER (WHERE p.ate_dir = ANY (e.ate)), count(*) FILTER (WHERE p.meta = ANY (e.meta))
    INTO v_total, v_ate, v_meta
    FROM calc.plan_mes p JOIN e USING (persona_id, it, mes);
    RAISE NOTICE 'PLAN may_dic: plan_ate_dir %/% = % %% · meta %/% = % %%',
        v_ate, v_total, round(100.0 * v_ate / v_total, 2), v_meta, v_total, round(100.0 * v_meta / v_total, 2);
    IF v_ate < 0.95 * v_total THEN
        RAISE EXCEPTION 'PLAN: regresión, plan_ate_dir may_dic coincide solo en %/%', v_ate, v_total;
    END IF;
END
$$;

BEGIN;
DO $$
DECLARE v_buk bigint; v_plan bigint; r record; v_n int; v_antes text; v_despues text;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 020', 'test:020:buk:' || clock_timestamp())
    RETURNING carga_id INTO v_buk;
    -- 900137: ejemplo de reglas.md (médico fisiatra IT 11, 40 h, NAS 20 % + asignación 2 h) todo el año
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, 11, 900137, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv' FROM generate_series(1, 7) m;
    -- 900138: alta en abril (sin semhab en el Excel -> regla general: semanas del calendario)
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, 11, 900138, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv' FROM generate_series(4, 7) m;
    -- 900139: baja, termina en mayo -> sin filas jun-dic (meses sin contrato)
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, fecha_termino, horas_semanales, cargo, dias_jornada)
    SELECT v_buk, 11, 900139, make_date(2026, m, 1), DATE '2026-05-31', 40, 'MEDICO FISIATRA', 'lmwjv'
    FROM generate_series(1, 5) m;
    PERFORM api.cargar_dotacion(v_buk);
    INSERT INTO core.asignacion (persona_id, it, tipo, horas) VALUES (900137, 11, 'Líder Equipo', 2);

    -- semhab del Excel para 900137 (feb 1 semana por vacaciones; resto 4,2)
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('planificacion', 'prueba 020', 'test:020:plan:' || clock_timestamp())
    RETURNING carga_id INTO v_plan;
    INSERT INTO stg.esperado (carga_id, persona_id, it, campo, mes, valor)
    SELECT v_plan, 900137, 11, 'semhab', m, CASE WHEN m = 2 THEN 1 ELSE 4.2 END FROM generate_series(1, 12) m;

    PERFORM calc.calcular_plan(1);

    -- Ejemplo de reglas.md: enero 151 / meta 135; febrero 36 / meta 32 (directas por semana: 36)
    SELECT * INTO r FROM calc.plan_mes WHERE persona_id = 900137 AND mes = 1;
    IF r.ate_dir_semana <> 36 OR r.ate_dir <> 151 OR r.meta <> 135 THEN
        RAISE EXCEPTION 'PLAN 137732 enero: semana % ate % meta % (se espera 36, 151, 135)', r.ate_dir_semana, r.ate_dir, r.meta;
    END IF;
    -- Unidades (enero): contratadas = 40 h/sem × 4,2 sem = 168 h; dir = 40 × 0,609375 × 4,2 = 102,375 h;
    -- dir + ind + nas = 40 × 4,2 (sin colación); FOJA = 102,375 / 168 (semanas multiplicadas una sola vez)
    IF r.horas_contratadas <> 168 OR abs(r.horas_dir - 102.375) > 1e-9
       OR abs(r.horas_dir + r.horas_ind + r.horas_nas - 168) > 1e-9 OR abs(r.foja - 102.375 / 168) > 1e-12 THEN
        RAISE EXCEPTION 'PLAN unidades: contratadas % dir % suma % foja %', r.horas_contratadas, r.horas_dir,
            r.horas_dir + r.horas_ind + r.horas_nas, r.foja;
    END IF;
    SELECT * INTO r FROM calc.plan_mes WHERE persona_id = 900137 AND mes = 2;
    IF r.ate_dir <> 36 OR r.meta <> 32 THEN
        RAISE EXCEPTION 'PLAN 137732 febrero: ate % meta % (se espera 36, 32)', r.ate_dir, r.meta;
    END IF;
    -- Febrero: contratadas con semanas del calendario (4,0), dir/ind/nas con semhab (1): la ausencia no va a horas_nas
    IF r.horas_contratadas <> 160 OR abs(r.horas_dir + r.horas_ind + r.horas_nas - 40) > 1e-9 THEN
        RAISE EXCEPTION 'PLAN febrero: contratadas % suma dir+ind+nas % (se espera 160 y 40)', r.horas_contratadas,
            r.horas_dir + r.horas_ind + r.horas_nas;
    END IF;

    -- Alta (abril): sin filas ene-mar; semanas del calendario y fuente 'calendario'
    SELECT count(*) INTO v_n FROM calc.plan_mes WHERE persona_id = 900138 AND mes < 4;
    IF v_n <> 0 THEN RAISE EXCEPTION 'PLAN alta: % filas antes de abril', v_n; END IF;
    SELECT count(*) INTO v_n FROM calc.plan_mes p JOIN calc.plan_mes_traza t USING (persona_id, it, mes)
    JOIN param.calendario_mes c ON c.vigente_hasta IS NULL AND c.zona = 'general' AND c.mes = p.mes
    WHERE p.persona_id = 900138 AND t.fuente_semanas = 'calendario' AND p.semanas_habiles = c.semanas;
    IF v_n <> 9 THEN RAISE EXCEPTION 'PLAN alta: % meses con semanas del calendario (se esperan 9: abr-dic)', v_n; END IF;
    -- Baja (mayo): solo ene-may
    SELECT count(*) AS n, max(mes) AS ultimo INTO r FROM calc.plan_mes WHERE persona_id = 900139;
    IF r.n <> 5 OR r.ultimo <> 5 THEN RAISE EXCEPTION 'PLAN baja: % filas hasta mes %', r.n, r.ultimo; END IF;

    -- Recálculo desde septiembre tras un cambio de jornada desde septiembre (900137: 40 -> 30 h)
    SELECT string_agg(concat_ws('|', persona_id, mes, ate_dir, meta, horas_dir, foja, calculado_en), ';' ORDER BY persona_id, mes)
    INTO v_antes FROM calc.plan_mes WHERE persona_id BETWEEN 900137 AND 900139 AND mes < 9;
    UPDATE core.dotacion_mes SET horas_semanales = 30 WHERE persona_id = 900137 AND mes >= 9;
    PERFORM calc.calcular_plan(9);
    SELECT string_agg(concat_ws('|', persona_id, mes, ate_dir, meta, horas_dir, foja, calculado_en), ';' ORDER BY persona_id, mes)
    INTO v_despues FROM calc.plan_mes WHERE persona_id BETWEEN 900137 AND 900139 AND mes < 9;
    IF v_antes IS DISTINCT FROM v_despues THEN RAISE EXCEPTION 'PLAN recálculo: cambiaron meses anteriores a septiembre'; END IF;
    SELECT * INTO r FROM calc.plan_mes WHERE persona_id = 900137 AND mes = 9;
    IF r.horas_contratadas <> 30 * 4.2 THEN
        RAISE EXCEPTION 'PLAN recálculo: septiembre con % h contratadas (se espera 126)', r.horas_contratadas;
    END IF;
    SELECT count(*) INTO v_n FROM calc.plan_mes WHERE persona_id = 900137;
    IF v_n <> 12 THEN RAISE EXCEPTION 'PLAN recálculo: 900137 con % meses', v_n; END IF;

    RAISE NOTICE 'PLAN OK (137732 sintético, alta, baja, unidades FOJA, recálculo desde 9)';
END
$$;
ROLLBACK;
