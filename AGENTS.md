# PlanBot — instrucciones para agentes de IA (Claude Code y Codex)

## Qué es
MVP del equipo 33 para la Botathon 2026 (Teletón Chile, desafío "Cada hora cuenta"). Reemplaza un Excel de planificación asistencial: calcula por profesional (persona_id), instituto (IT) y mes las horas directas, indirectas y NAS, las atenciones planificadas, la meta de gestión (90 %) y el % FOJA. Blue Prism (lo hace Lucas) carga los Excel en tablas `stg.*`; PostgreSQL calcula; un dashboard HTML/JS muestra los resultados vía PostgREST. Andrés programa el BACK (SQL) con Claude Code en su computador; César programa el FRONT, los datos de prueba, el CI y el código C# para Blue Prism con Claude Code (y Codex de respaldo). Revisión cruzada: César revisa los PR de Andrés y Andrés los de César.

Lee SIEMPRE antes de empezar:
- `docs/progreso-back.md` o `docs/progreso-front.md` (estado de tu parte)
- `docs/contratos.md` (contratos que NO se pueden romper)
- `docs/reglas.md` (reglas de cálculo)
- `docs/backlog.md` (historias y criterios de aceptación)
- Contexto general: `docs/contexto.md`

## Arquitectura
**Back:** PostgreSQL 16 con toda la lógica de negocio en SQL (tablas, funciones PL/pgSQL, vistas). Sin servidor de aplicación propio. PostgREST expone el esquema `api` (vistas y funciones RPC). Esquemas: `param` (reglas con version y vigencia), `stg` (crudo, lo escribe Blue Prism), `core` (dotación limpia, cambios, asignaciones), `calc` (planificación, escenarios, cuadratura), `audit` (log por triggers), `api` (público). Roles: `owner_planbot`, `bot_carga`, `web_lectura`, `planificador`.

**Front:** página única estática, HTML + JavaScript (módulos ES, sin framework ni build) + Apache ECharts 5 + Tabulator 6 en `web/vendor/`. `web/js/config.js` define `modo: 'mock' | 'api'`. Pantallas: nacional, instituto, profesional, cambios, parametros, cuadratura. Accesible (teclado, aria-label, contraste AA, tabla alternativa en gráficos, lectura fácil). Números en formato es-CL.

**Empaquetado:** `docker-compose.yml` (postgres:16, postgrest, nginx en :8080). Plan B sin Docker: `scripts/instalar_sin_docker.ps1`.

## Entorno
Windows 11 + PowerShell 7. Todos los scripts en PowerShell (`.ps1`), rutas con `\`. Nada de `.sh`. CI en GitHub Actions con `ubuntu-latest` usando `pwsh` para correr los mismos `.ps1`. La VM de la demo también es Windows.

## Estructura
```
database\migrations   V000__, V001__... idempotentes, orden estricto
database\functions    database\views    database\seed
api\                  postgrest.conf
web\                  index.html, js\, js\pages\, css\, mock\, vendor\
data\                 extraer.py (listo), excel\ (los 2 Excel), csv\ (generados), buk\ (casos de prueba)
tests\sql  tests\e2e
scripts\              migrar.ps1, test.ps1 (-Modulo db|web|todo), instalar_sin_docker.ps1
bluePrism\codigo\     código C# de referencia para Lucas, lo hace César (el resto de bluePrism\ es de Lucas: NO tocar)
docs\                 contexto, contratos, reglas, backlog, progreso-back, progreso-front, prompts\
```

## Comandos
- Levantar: `docker compose up -d`
- Migrar y sembrar: `.\scripts\migrar.ps1`
- Probar: `.\scripts\test.ps1 -Modulo db` | `web` | `todo` (en verde antes de cada commit)
- Consultar: `docker compose exec postgres psql -U owner_planbot -d planbot`
- Regenerar CSV: `python data\extraer.py "data\excel\Nac - Planificacion Asistencial x mes.xlsx" data\csv`
- Web: http://localhost:8080

## Reglas
1. Los contratos de `docs/contratos.md` son ley: no agregar, quitar ni renombrar columnas de `stg.*`, firmas de funciones ni columnas de vistas. Si hace falta, detente y pregunta.
2. Constantes de negocio solo desde `param.*` (nunca 0.9, 44, 42, 40, 22, 30 fijos en el código).
3. "Redondeo hacia abajo" = `floor(x + 1e-9)`.
4. Sin contraseñas ni datos reales: `.env` (no versionado) y `.env.example`. Solo `persona_id`, nunca nombres ni RUT.
5. Dos personas trabajan en paralelo, cada una con su agente y en su propio clon del repositorio:
   - BACK (Andrés): solo `database\`, `api\`, `scripts\`, `docker-compose.yml`, `tests\sql\`, `docs\progreso-back.md`.
   - FRONT (César): solo `web\`, `data\`, `tests\e2e\`, `.github\`, `bluePrism\codigo\`, `docs\progreso-front.md`.
6. Una historia por rama `feat/<ID>-<nombre>` desde `main`. Commits Conventional Commits en español: `feat(db): ...`, `fix(web): ...`. PR con `gh pr create`.
7. Cambios pequeños y probados. No refactorizar lo que la historia no pide.
8. No leer los `.xlsx` completos: usar `data\csv\*.csv`.
9. Al cerrar una historia: pruebas en verde, marcar criterios en `docs\backlog.md`, actualizar tu archivo de progreso (Hecho / En curso / Siguiente / Errores conocidos), commit y PR. Si la sesión se corta, otro agente debe poder seguir solo leyendo esos archivos.
10. Respuestas breves en español.
