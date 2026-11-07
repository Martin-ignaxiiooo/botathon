-- 010 · Cálculo semanal (B-05): calc.v_semanal.
-- Parte 1 (solo con la base BUK real cargada): coincidencia may_dic con stg.esperado y 10 mayores diferencias.
--   Medida: capa calc.v_semanal, periodo may_dic; numerador = persona-IT con ate_dir_semana igual al Excel
--   (pct_dir_final a ±0,0001); denominador = persona-IT con esperado ate_dir_semana. Pares repetidos del Excel:
--   acierto si calza con cualquiera de sus filas. Evidencia completa: database\evidencia\b05 (scripts\evidencia_b05.ps1).
--   Guardia anti-regresión: >= 95,5 % (nivel actual 95,8 %). El criterio del backlog (>= 98 %) sigue ABIERTO.
-- Parte 2: ejemplo verificado de reglas.md (137732) con datos sintéticos; corre también en CI.
DO $$
DECLARE v_total int; v_ate int; v_pdf int; r record;
BEGIN
    IF (SELECT count(*) FROM core.dotacion_mes WHERE origen = 'buk') < 3000 THEN
        RAISE NOTICE 'SEMANAL: base BUK real no cargada; se omite la comparación con el Excel';
        RETURN;
    END IF;
    CREATE TEMP TABLE t_cmp ON COMMIT DROP AS
    WITH e AS (
        SELECT persona_id, it, array_agg(valor) FILTER (WHERE campo = 'ate_dir_semana') AS ate,
               array_agg(valor) FILTER (WHERE campo = 'pct_dir_final') AS pdf
        FROM stg.esperado WHERE mes IS NULL GROUP BY persona_id, it)
    SELECT s.persona_id, s.it, s.cargo, s.ate_dir_semana, e.ate, s.pct_dir_final, e.pdf,
           s.ate_dir_semana = ANY (e.ate) AS ate_ok,
           EXISTS (SELECT 1 FROM unnest(e.pdf) x WHERE abs(x - s.pct_dir_final) <= 0.0001) AS pdf_ok,
           (SELECT min(abs(x - s.ate_dir_semana)) FROM unnest(e.ate) x) AS dif
    FROM calc.v_semanal s JOIN e ON e.persona_id = s.persona_id AND e.it = s.it
    WHERE s.periodo = 'may_dic' AND e.ate IS NOT NULL;

    SELECT count(*), count(*) FILTER (WHERE ate_ok), count(*) FILTER (WHERE pdf_ok) INTO v_total, v_ate, v_pdf FROM t_cmp;
    RAISE NOTICE 'SEMANAL may_dic: ate_dir_semana %/% = % %% · pct_dir_final %/% = % %%',
        v_ate, v_total, round(100.0 * v_ate / v_total, 1), v_pdf, v_total, round(100.0 * v_pdf / v_total, 1);
    FOR r IN SELECT * FROM t_cmp WHERE NOT ate_ok ORDER BY dif DESC, persona_id LIMIT 10 LOOP
        RAISE NOTICE '  dif % · persona % IT % % · sistema % vs Excel % · pct_dir_final % vs %',
            r.dif, r.persona_id, r.it, r.cargo, r.ate_dir_semana, r.ate, round(r.pct_dir_final, 6), r.pdf;
    END LOOP;
    IF v_ate < 0.955 * v_total THEN
        RAISE EXCEPTION 'SEMANAL: regresión, ate_dir_semana coincide solo en %/%', v_ate, v_total;
    END IF;
    IF v_ate < 0.98 * v_total THEN
        RAISE NOTICE 'SEMANAL: criterio B-05 (>= 98 %%) aún no se cumple; ver database\evidencia\b05\resumen.md';
    END IF;
    DROP TABLE t_cmp;
END
$$;

BEGIN;
DO $$
DECLARE v_carga bigint; r record;
BEGIN
    INSERT INTO stg.carga (tipo, archivo, hash) VALUES ('buk', 'prueba 010', 'test:010:' || clock_timestamp())
    RETURNING carga_id INTO v_carga;
    -- Ejemplo de reglas.md: médico fisiatra, IT 11, 40 h todo el año, NAS 20 %, asignación 2 h, sin colación
    INSERT INTO stg.buk_fila (carga_id, it, persona_id, periodo, horas_semanales, cargo, dias_jornada)
    SELECT v_carga, 11, 900137, make_date(2026, m, 1), 40, 'MEDICO FISIATRA', 'lmwjv' FROM generate_series(1, 7) m;
    PERFORM api.cargar_dotacion(v_carga);
    INSERT INTO core.asignacion (persona_id, it, tipo, horas) VALUES (900137, 11, 'Líder Equipo', 2);

    SELECT * INTO r FROM calc.v_semanal WHERE persona_id = 900137 AND periodo = 'may_dic';
    IF r.tramo <> 1 OR r.pct_nas_asig <> 0.25 OR abs(r.pct_dir_final - 0.609375) > 1e-9
       OR abs(r.pct_ind_final - 0.140625) > 1e-9 OR r.ate_dir_semana <> 36 OR r.ate_ind_semana <> 11 THEN
        RAISE EXCEPTION 'SEMANAL 137732 (sintético): tramo % nas+asig % dir % ind % ate % / % (se espera 1, 0.25, 0.609375, 0.140625, 36 / 11)',
            r.tramo, r.pct_nas_asig, r.pct_dir_final, r.pct_ind_final, r.ate_dir_semana, r.ate_ind_semana;
    END IF;

    -- Cambio de jornada en el periodo: 40 h may-jun y 30 h desde julio -> horas may_dic = (40×2 + 30×6) / 8 = 32,5
    UPDATE core.dotacion_mes SET horas_semanales = 30 WHERE persona_id = 900137 AND mes >= 7;
    SELECT * INTO r FROM calc.v_semanal WHERE persona_id = 900137 AND periodo = 'may_dic';
    IF r.horas_semanales <> 32.5 OR r.horas_fin <> 30 THEN
        RAISE EXCEPTION 'SEMANAL: horas may_dic = % / fin % (se espera 32.5 / 30)', r.horas_semanales, r.horas_fin;
    END IF;
    RAISE NOTICE 'SEMANAL OK (caso 137732 sintético)';
END
$$;
ROLLBACK;
