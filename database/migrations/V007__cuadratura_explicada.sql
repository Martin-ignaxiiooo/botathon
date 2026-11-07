-- B-10 · Diferencias de cuadratura ya analizadas: solo clasifican la causa en calc.cuadratura
-- (causa 'diferencia_explicada'); NO cambian ningún cálculo.
CREATE TABLE IF NOT EXISTS param.cuadratura_explicada (
    persona_id bigint NOT NULL,
    it         int    NOT NULL,
    nota       text   NOT NULL,
    PRIMARY KEY (persona_id, it)
);

INSERT INTO param.cuadratura_explicada (persona_id, it, nota) VALUES
    (134744, 11, 'Semanal directo: floor(20 × 0,75 × 0,825 / 0,85 × 60/60) = floor(14,56) = 14; el Excel dice 15 (B-05)')
ON CONFLICT (persona_id, it) DO NOTHING;
