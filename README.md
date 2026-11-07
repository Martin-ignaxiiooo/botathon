# PlanBot · Botathon 2026 · Equipo 33

La planificación asistencial vive en Excel y requiere cargas y cálculos manuales.<br>
PlanBot recibe reportes BUK y reglas de planificación sin copiar y pegar.<br>
Valida filas y detecta altas, bajas y cambios desde su mes de vigencia.<br>
Calcula horas directas, indirectas, NAS y atenciones por profesional, instituto y mes.<br>
Muestra resultados y trazabilidad para el desafío Teletón «Cada hora cuenta».

## Arquitectura

1. **Blue Prism 7.5.1** recibe Excel, valida filas y duplicados por hash, registra errores y carga `stg.*` por ODBC.
2. **PostgreSQL 16** conserva reglas versionadas en `param.*`, calcula en SQL y publica vistas/RPC mediante PostgREST, sin servidor de aplicación propio.
3. **Dashboard** estático HTML/JavaScript con ECharts y Tabulator: Nacional, Instituto, Profesional, Cambios, Parámetros y Cuadratura.

La **meta de gestión** es `floor(atenciones planificadas × porcentaje vigente)` (inicial 90 %). **% FOJA** es horas mensuales disponibles para atención directa / horas mensuales contratadas. Las constantes pertenecen a `param.*`; las reglas completas están en [docs/reglas.md](docs/reglas.md) y las interfaces en [docs/contratos.md](docs/contratos.md).

## Carpetas

| Ruta | Contenido / responsable |
|---|---|
| `bluePrism\` | Procesos y objetos del robot · Lucas |
| `bluePrism\codigo\` | Código C# ODBC/hash y guía para los Code stages |
| `database\`, `api\`, `scripts\` | SQL, PostgREST, migraciones y pruebas · Andrés |
| `web\` | Dashboard estático y dependencias locales · César/Claude Code |
| `data\excel\`, `data\csv\` | Entradas y reglas extraídas |
| `data\generar_casos.py`, `data\buk\` | Generador y casos de prueba BUK |
| `tests\sql\`, `tests\e2e\` | Pruebas de base y guion integrado |
| `.github\` | CI PostgreSQL/pwsh y ESLint |
| `docs\` | Contexto, contratos, reglas, instalación y progreso |

Este clon contiene los entregables de apoyo. `database\`, `scripts\`, `web\`, `api\` y `docker-compose.yml` todavía deben integrarse desde el trabajo paralelo; los comandos siguientes requieren esos componentes. El generador detecta que la fuente actual solo contiene enero–julio y se detiene antes de inventar meses: falta resolver la base anual para D-04.

## Requisitos e instalación en Windows

Windows 11 de 64 bits, PowerShell 7, Blue Prism 7.5.1 con Runtime Resource y licencia, psqlODBC Unicode de 64 bits y acceso a PostgreSQL 16. Para generar casos: Python 3 y `python -m pip install openpyxl`. Node 20 y ESLint se usan en CI; el dashboard no necesita build.

Con Docker Desktop y contenedores Linux habilitados, desde la raíz en PowerShell 7:

```powershell
Copy-Item .env.example .env
# Completar .env con secretos locales antes de continuar.
docker compose up -d
.\scripts\migrar.ps1
.\scripts\test.ps1 -Modulo todo
```

Sin Docker: instalar PostgreSQL 16 con cliente psql, PostgREST y un servidor estático local; configurar `.env`, luego ejecutar ` .\scripts\instalar_sin_docker.ps1` cuando esté integrado. La preparación manual y las verificaciones están en [docs/instalacion.md](docs/instalacion.md). No ejecutar los dos motores sobre el mismo puerto 5432.

## Demo de cinco minutos

1. Preparar base/robot con [la instalación](docs/instalacion.md), cargar reglas por P00 y respaldar el estado limpio.
2. Generar los casos con `python data\generar_casos.py` una vez resuelta la cobertura anual; entregar `01_original.xlsx` a `C:\PlanBot\entrada\buk` y ejecutar P01–P05.
3. Abrir `http://localhost:8080` con `modo: 'api'` en la configuración del dashboard y mostrar Nacional.
4. Entregar `02_cambios.xlsx`, mostrar Cambios y el efecto desde los meses vigentes.
5. Ensayar errores, archivo repetido y escenario de meta 85 % siguiendo [tests/e2e/guion.md](tests/e2e/guion.md). La simulación debe preceder a la aprobación.

Credenciales en Credential Manager y `.env` local; nunca en Git ni en capturas. Usar datos de demostración autorizados y `persona_id` como identificador de persona, sin nombres ni RUT.

## Equipo y uso de IA

Equipo 33: Andrés desarrolla SQL/cálculo; César desarrolla dashboard, datos, CI y código de apoyo; Lucas implementa Blue Prism. Claude Code y Codex apoyan programación y revisión; el equipo valida cálculos, contratos y demo. Este trabajo de Codex usa la rama `codex/trabajo`, con commits locales y sin push. Estado y limitaciones: [docs/progreso-codex.md](docs/progreso-codex.md). Instrucciones para agentes: [AGENTS.md](AGENTS.md).
