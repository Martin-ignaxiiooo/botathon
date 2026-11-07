# Andrés · BACK (Claude Code) — sesiones siguientes a la fase 0

Lee AGENTS.md, docs/contratos.md, docs/reglas.md y docs/progreso-back.md. Soy Andrés y programo el BACK. Solo puedo modificar database\, api\, scripts\, docker-compose.yml, tests\sql\ y docs\progreso-back.md (y marcar mis historias en docs\backlog.md). César trabaja el front en paralelo: no toques web\, data\, .github\ ni bluePrism\.
Estás en Windows con PowerShell: comandos de PowerShell y rutas con \.

Implementa en orden: B-03 (CSV ya en data\csv), B-04, B-05, B-06, C-01, B-07, B-08, B-09, D-05, B-10, B-11, B-12, B-13. Criterios en docs\backlog.md; reglas en docs\reglas.md; contratos en docs\contratos.md.
Prioridad absoluta: B-09 (vistas api.*) lo antes posible después de B-06, porque el front de César lo necesita para dejar los datos de prueba.
Por cada historia: git checkout main; git pull; rama feat/<ID>; .\scripts\test.ps1 -Modulo db en verde; marca la historia en docs\backlog.md; actualiza docs\progreso-back.md; commit (Conventional Commits); push; PR con gh pr create.
B-05 y B-06: muéstrame el plan antes de programar y compara contra data\csv\esperado.csv (campos ate_dir_semana, plan_ate_dir, meta), informando el % de coincidencia por campo.
Si necesitas cambiar un contrato de docs\contratos.md, detente y pregúntame (hay que avisar a César y a Lucas).
