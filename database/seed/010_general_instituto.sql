-- Seed 010 · Constantes de negocio (param.general, versión inicial) y catálogo de institutos. Idempotente.
-- Las constantes viven SOLO aquí (datos); el código SQL las lee de param.general.

-- Versión inicial de constantes: solo si aún no hay ninguna versión.
INSERT INTO param.version (descripcion)
SELECT 'Constantes iniciales (seed)'
WHERE NOT EXISTS (SELECT 1 FROM param.version);

INSERT INTO param.general (version, vigente_desde, vigente_hasta, clave, valor, descripcion)
SELECT v.version, v.vigente_desde, v.vigente_hasta, g.clave, g.valor, g.descripcion
FROM (SELECT * FROM param.version ORDER BY version LIMIT 1) v
CROSS JOIN (VALUES
    ('meta',               0.9,  'Meta de gestión: fracción de las atenciones planificadas'),
    ('jornada_ene_abr',    44,   'Jornada legal semanal ene-abr (h)'),
    ('jornada_may_dic',    42,   'Jornada legal semanal may-dic (h)'),
    ('pausa_pct_alta',     0.10, 'Pausa saludable si horas >= tramo_limite_alto'),
    ('pausa_pct_baja',     0.06, 'Pausa saludable si horas < tramo_limite_alto'),
    ('colacion_h_dia',     0.25, 'Beneficio de colación por día (h)'),
    ('tramo_limite_bajo',  22,   'Tramo 2 desde estas horas semanales'),
    ('tramo_limite_alto',  40,   'Tramo 1 desde estas horas semanales'),
    ('max_asignaciones',   2,    'Máximo de asignaciones por profesional'),
    ('horas_min_para_max', 30,   'Horas semanales mínimas para tener el máximo de asignaciones'),
    ('min_indirecta',      30,   'Minutos estándar por atención indirecta'),
    ('dia_en_semanas',     0.2,  'Un día hábil expresado en semanas')
) AS g(clave, valor, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM param.general);

-- Catálogo de institutos (nombres como el campo Área del BUK; correos ficticios)
INSERT INTO param.instituto (it, nombre, zona, grupo_it, correo_jefatura) VALUES
    (11,  'Arica',        'arica',   'otros',   'jefatura.it11@planbot.example'),
    (12,  'Iquique',      'general', 'otros',   'jefatura.it12@planbot.example'),
    (21,  'Antofagasta',  'general', 'otros',   'jefatura.it21@planbot.example'),
    (22,  'Calama',       'general', 'otros',   'jefatura.it22@planbot.example'),
    (31,  'Copiapó',      'general', 'otros',   'jefatura.it31@planbot.example'),
    (41,  'Coquimbo',     'general', 'otros',   'jefatura.it41@planbot.example'),
    (51,  'Valparaíso',   'general', 'otros',   'jefatura.it51@planbot.example'),
    (61,  'O''Higgins',   'general', 'otros',   'jefatura.it61@planbot.example'),
    (71,  'Talca',        'general', 'otros',   'jefatura.it71@planbot.example'),
    (81,  'Concepción',   'general', 'San-Con', 'jefatura.it81@planbot.example'),
    (91,  'Temuco',       'general', 'otros',   'jefatura.it91@planbot.example'),
    (101, 'Puerto Montt', 'general', 'otros',   'jefatura.it101@planbot.example'),
    (102, 'Castro',       'general', 'otros',   'jefatura.it102@planbot.example'),
    (111, 'Coyhaique',    'aysen',   'otros',   'jefatura.it111@planbot.example'),
    (131, 'Santiago',     'general', 'San-Con', 'jefatura.it131@planbot.example'),
    (141, 'Valdivia',     'general', 'otros',   'jefatura.it141@planbot.example')
ON CONFLICT (it) DO UPDATE
SET nombre = EXCLUDED.nombre, zona = EXCLUDED.zona, grupo_it = EXCLUDED.grupo_it,
    correo_jefatura = EXCLUDED.correo_jefatura;
