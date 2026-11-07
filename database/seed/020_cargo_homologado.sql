-- Seed 020 · Homologación de cargos BUK (hoja Dotacion_2026, columna Cargo) -> cargo de param_cargo (Distribucion_NAC).
-- Los 15 cargos distintos del BUK 2026. cod_esp = el del BUK (el de param_cargo.csv viene desfasado).
-- Dudosos documentados en docs\progreso-back.md. Idempotente.
INSERT INTO param.cargo_homologado (cargo_origen, cargo, cod_esp, dudoso, nota) VALUES
    ('ASISTENTE SOCIAL',                                 'ASISTENTE SOCIAL',                                 'AS',   false, NULL),
    ('COORDINADOR DE SERVICIOS SOCIALES Y COMUNITARIOS', 'COORDINADOR DE SERVICIOS SOCIALES Y COMUNITARIOS', 'AS',   false, NULL),
    ('EDUCADOR',                                         'EDUCADOR',                                         'ULAB', true,
     'BUK trae Cod_Esp ULAB; existen EDUCADOR (NAS 0.30) y EDUCADOR ULAB (NAS 0.50). La hoja de planificación usa EDUCADOR con %NAS ~0.30'),
    ('ENFERMERA',                                        'ENFERMERA',                                        'EN',   false, NULL),
    ('ENFERMERA COORDINADORA',                           'ENFERMERA COORDINADORA',                           'EN',   false, NULL),
    ('FONOAUDIOLOGO',                                    'FONOAUDIOLOGO',                                    'FO',   false, NULL),
    ('JEFE KINESIOLOGIA',                                'JEFE KINESIOLOGIA',                                'KI',   false, NULL),
    ('JEFE TERAPIA OCUPACIONAL',                         'JEFE TERAPIA OCUPACIONAL',                         'TO',   false, NULL),
    ('KINESIOLOGO',                                      'KINESIOLOGO',                                      'KI',   false, NULL),
    ('MEDICO FISIATRA',                                  'MEDICO FISIATRA',                                  'FI',   false, NULL),
    ('MEDICO GENERAL',                                   'MEDICO GENERAL',                                   'FI',   true,
     'Existen MEDICO GENERAL y MEDICO GENERAL FI con los mismos porcentajes; BUK trae Cod_Esp FI'),
    ('PROFESOR DE ARTE',                                 'PROFESOR DE ARTE',                                 'UTAC', false, NULL),
    ('PROFESOR DE EDUCACION FISICA',                     'PROFESOR DE EDUCACION FISICA',                     'UEDA', false, NULL),
    ('PSICOLOGO',                                        'PSICOLOGO',                                        'PC',   false, NULL),
    ('TERAPEUTA OCUPACIONAL',                            'TERAPEUTA OCUPACIONAL',                            'TO',   false, NULL)
ON CONFLICT (cargo_origen) DO UPDATE
SET cargo = EXCLUDED.cargo, cod_esp = EXCLUDED.cod_esp, dudoso = EXCLUDED.dudoso, nota = EXCLUDED.nota;
