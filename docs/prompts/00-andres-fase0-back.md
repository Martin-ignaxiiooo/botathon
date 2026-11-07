# Andrés · Fase 0 del BACK (Claude Code, primera sesión en su clon del repo)

Lee AGENTS.md, docs/contexto.md, docs/contratos.md, docs/reglas.md, docs/backlog.md y docs/progreso-back.md. Soy Andrés y programo el BACK (SQL). César programa el front en paralelo en otro computador. Ya están listos: los documentos de contexto, los Excel en data\excel y los CSV en data\csv (D-02 hecho). NO leas los Excel completos.

Estamos en Windows 11 con PowerShell 7: todos los scripts en .ps1, rutas con \. Solo puedo modificar database\, api\, scripts\, docker-compose.yml, tests\sql\ y docs\progreso-back.md (y marcar mis historias en docs\backlog.md).

Tarea de esta sesión:
1) Muéstrame un plan corto y espera mi OK.
2) Crea las carpetas del back con .gitkeep: database\{migrations,functions,views,seed}, api, scripts, tests\sql.
3) Implementa B-01 y B-02 completos (criterios en docs\backlog.md): docker-compose.yml, V000__roles.sql, V001..V004, scripts\migrar.ps1, scripts\test.ps1 (-Modulo db|web|todo; web puede quedar como "sin pruebas aún"), scripts\instalar_sin_docker.ps1, tests\sql\000_humo.sql.
4) Levanta con docker compose up -d, corre .\scripts\migrar.ps1 dos veces y .\scripts\test.ps1 -Modulo db hasta verde.
5) Marca B-01 y B-02 en docs\backlog.md, actualiza docs\progreso-back.md (Siguiente: B-03, B-04, B-05), commit en la rama feat/B-01-B-02-base, push y PR con gh pr create (revisa César).
Al terminar, resúmeme en 5 líneas qué quedó listo y detente.
