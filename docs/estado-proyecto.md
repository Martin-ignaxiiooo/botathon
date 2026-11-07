# PlanBot · Estado del proyecto y traspaso

Corte: sábado 7 de noviembre de 2026, 00:16 (Chile). Botathon 2026, equipo 33, desafío "Cada hora cuenta" (Teletón Chile).
Uso de este archivo: es el resumen completo para que cualquier IA (ChatGPT, Claude, Codex) o persona retome el trabajo. Leerlo junto con `AGENTS.md`, `docs\contratos.md`, `docs\reglas.md` y `docs\backlog.md`.

---

## 1. Qué estamos construyendo

**Problema:** Teletón planifica en un Excel manual a más de 600 profesionales (kinesiólogos, terapeutas, médicos, psicólogos, etc.). Define cuántas horas de cada profesional van a atención directa (pacientes), indirecta (informes, registros) y no asistencial (NAS: coordinación, capacitación, comités, asignaciones), y con eso su meta de atenciones. Dolores: carga manual desde BUK (RR.HH.), errores, reglas escondidas en fórmulas, sin trazabilidad ni versiones, poca visibilidad, asignaciones juntadas por correo.

**Solución, PlanBot (3 partes):**
1. **Robot que recibe los datos: Blue Prism 7.5.1** (en la VM de la Botathon, Windows). Toma los Excel dejados en `C:\PlanBot\entrada\*`, limpia, valida fila por fila, informa errores, carga en tablas `stg.*` de PostgreSQL por ODBC y llama funciones SQL que recalculan.
2. **Aplicación que arma todo: PostgreSQL 16 + PostgREST.** Reglas en tablas `param.*` editables y versionadas; cálculo por profesional y mes en funciones y vistas SQL; detección de cambios y recálculo desde el mes vigente; auditoría.
3. **Dashboards: HTML + JavaScript (módulos ES, sin framework) + ECharts + Tabulator.** Vista nacional filtrable por instituto, área, cargo, mes y profesional; meta (90 %) y % FOJA.

**Indicadores:** Meta de gestión = atenciones planificadas × 90 %. % FOJA = horas directas / horas contratadas.

**Obligatorio para el jurado:** Blue Prism central y visible en la demo (5 min: procesar un BUK y mostrar el efecto); carga sin copiar/pegar con errores detectados; reglas parametrizables; cálculo que coincida con el Excel; cambios durante el año; dashboard nacional. Pitch de 3 min + lámina de arquitectura.

## 2. Equipo, roles y herramientas

| Persona | Rol | Herramienta | Carpeta |
|---|---|---|---|
| César | Front (dashboard), datos de prueba, CI, código C# para Blue Prism; coordinación | Claude Code (Sonnet) en `bothaton`; Codex (GPT Sol, alto) en `bothaton-codex` | `C:\Users\SOPORTE\OneDrive\Desktop\bothaton` y `...\bothaton-codex` (worktree, rama `codex/trabajo`) |
| Andrés | Back: toda la base de datos SQL y el cálculo | Claude Code (Sonnet; Opus/alto en B-05 y B-06) | `C:\dev\planbot` (o `C:\dev\botathon` clonado del repo) |
| Lucas | Robot de Blue Prism en la VM | ChatGPT | VM `botvm-33` |

Revisión cruzada: César revisa los PR de Andrés y Andrés los de César.
Repositorio: https://github.com/Martin-ignaxiiooo/botathon (rama `main`; `codex/trabajo` para Codex).
Entorno: Windows 11 + PowerShell (no Ubuntu/WSL). Docker Desktop si funciona; si no, PostgreSQL 16 nativo.

## 3. Lo que YA está hecho

### Análisis y diseño
- [x] Análisis completo de los dos Excel. Reglas de cálculo reconstruidas y validadas contra 447 filas (`docs\reglas.md`): may–dic coincide 100 % en atenciones mensuales; % directo final 100 %; atenciones por semana 98–99 %.
- [x] Arquitectura definida (3 partes) y contratos entre módulos (`docs\contratos.md`, **versión 1.1**: `v_instituto_area_mes` incluye `horas_contratadas, horas_dir, horas_ind, horas_nas`).
- [x] Plan de trabajo en Claude Docs con módulos, 49 historias de usuario, sprints, riesgos y diagramas: https://claude.ai/artifact/P99TzoYW4SCDcAvqp6N6kn (la nota "Reparto vigente" manda sobre las secciones antiguas).
- [x] Documento Word con las 5 soluciones y la combinada (`Plan_Solucion_Botathon_2026_Equipo33.docx`).

### Repositorio y contexto
- [x] Carpeta del proyecto con `AGENTS.md` (instrucciones para agentes), `CLAUDE.md`, `docs\` (contexto, contratos, reglas, backlog, progreso-back, progreso-front, progreso-codex), `.gitignore`, `.gitattributes`, `.env.example`.
- [x] Git inicializado, worktree de Codex creado, todo subido a GitHub.
- [x] Prompts por IA en `docs\prompts\`: `10-cesar-claude-sonnet.md`, `11-cesar-codex-gptsol.md`, `12-andres-claude.md`, `13-lucas-chatgpt.md`, `03-traspaso.md`, `LEEME.md`.

### Datos (D-02, D-04)
- [x] `data\extraer.py` y CSV en `data\csv\`: `param_cargo` (258 filas = cargo × 3 tramos, todas suman 100 %), `param_asignacion` (33), `param_calendario` (12), `param_grupal` (10), `excepciones` (177), `esperado` (31.527 valores del Excel para comparar).
- [x] `data\generar_casos.py` y `data\buk\`: `01_original.xlsx`, `02_cambios.xlsx` (cambios dentro de ene–jul: jornada 40→30 desde mayo, baja desde junio, alta 999001 desde abril, cambio de cargo desde marzo, cambio de IT desde julio), `03_errores.xlsx` (5 errores), `esperado_cambios.csv`, `esperado_errores.csv`.

### Codex (César) — tareas 1 a 8 terminadas
- [x] `bluePrism\codigo\PlanBot_PostgreSQL.cs` (Ejecutar Consulta, Comando, Función, Carga Masiva; ODBC; C# 7.3) y `PlanBot_Archivos_Hash.cs` (SHA-256), con `LEEME.md` para Lucas.
- [x] `PlanBot_Limpieza.cs`, `PlanBot_Validador.cs` (detecta 5/5 errores de prueba) y `PlanBot_Reglas.cs` (Distribucion_NAC → cargo × tramo): aceleran P02 y P00 de Lucas.
- [x] `.github\workflows\ci.yml` (Postgres + pwsh + ESLint).
- [x] `tests\e2e\guion.md` (guion de pruebas de punta a punta).
- [x] `README.md` y `docs\instalacion.md` (instalación en la VM).
- [x] `docs\pitch.md`, `docs\arquitectura.md`, `docs\uso-ia.md`, `docs\proteccion-datos.md`, `docs\demo.md`.

### Claude Code (César) — front
- [x] D-03 mocks (`web\mock\*.json` + `generar_mocks.py`).
- [x] C-02 esqueleto: `index.html` accesible, `base.css`, `config.js`, `api.js` (mock/api), `router.js`, `formato.js`, `ui.js`, `main.js`; ECharts 5.6.0 y Tabulator 6.7.1 en `web\vendor\`; 6 pantallas como esqueleto.
- [~] C-03 Pantalla Nacional: en curso (con el contrato v1.1 para horas por área).

### Blue Prism (Lucas)
- [~] A-01 entorno: variables de entorno en curso (`RutaBase = C:\PlanBot`, `ConnStrSinClave = Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;`, `CorreoPlanificacion`, `CorreoGP`). Falta confirmar carpetas, colas y credencial `PlanBot_Postgres` (usuario `bot_carga`, clave = `BOT_CARGA_PASSWORD` del `.env` de Andrés).

### Base de datos (Andrés)
- [~] Recibió `planbot.zip` con contexto y datos; arrancando B-01 y B-02 con su prompt (estado exacto: revisar `docs\progreso-back.md` de Andrés).

## 4. Lo que FALTA (por persona y en orden)

### Andrés (camino crítico)
- [ ] B-01 base, roles, docker-compose, `scripts\migrar.ps1`, `scripts\test.ps1`, `scripts\instalar_sin_docker.ps1`
- [ ] B-02 tablas (stg exacto al contrato; `calc.plan_mes` con `horas_ind` y `horas_nas`)
- [ ] B-03 parámetros (seed, CSV a stg, `cargar_parametros`, institutos, cargo_homologado)
- [ ] B-04 `cargar_dotacion` + **proyección ago–dic** (el BUK solo trae ene–jul: mantener las condiciones del último mes conocido hasta fecha_termino o diciembre, columna `origen = 'buk' | 'proyectado'`)
- [ ] B-05 cálculo semanal (meta ≥ 98 %) — modo plan
- [ ] B-06 plan mensual, meta, FOJA (meta 100 % may–dic) — modo plan
- [ ] C-01 PostgREST
- [ ] B-07 `detectar_cambios` + B-08 `recalcular` (probar con `data\buk\02_cambios.xlsx`)
- [ ] B-09 vistas `api.*` v1.1 → **entregar a César** (`entrega_cesar.zip` o push)
- [ ] D-05 casos dorados
- [ ] Instalar la base en la VM (hora 7–9) para que Blue Prism se conecte con `localhost`
- [ ] Extras: B-10 cuadratura, B-11 auditoría, B-12 simulación, B-13 multi-instituto

### César · Claude Code (front)
- [ ] C-03 Nacional (en curso) · C-04 filtros · C-05 Instituto · C-06 Profesional · C-07 Cambios y errores
- [ ] Cambio a datos reales cuando llegue B-09 (modo api; verificar contra `v_kpi`)
- [ ] C-08 Cuadratura · C-10 accesibilidad y lectura fácil · C-09 Parámetros y simulación · C-11 exportar e imprimir

### César · Codex
- [ ] Tarea 9: `tools\verificar_calculo.py` (verificador independiente del cálculo contra `esperado.csv`; acepta `--plan` con export de `calc.plan_mes`) y `docs\verificacion.md`
- [ ] Después: revisar los PR de SQL de Andrés con el verificador; apoyar ensayos

### Lucas (Blue Prism)
- [ ] A-01 terminar entorno · A-03 objeto Archivos · A-04 P01 recepción · A-02 objeto PostgreSQL (con el C# de `bluePrism\codigo\`)
- [ ] A-05 P02 limpieza y validación (usar `PlanBot_Limpieza` y `PlanBot_Validador`)
- [ ] A-06 P00 extraer reglas (usar `PlanBot_Reglas`)
- [ ] A-07 P03–P04 cambios y recálculo · A-08 P05 informe · proceso maestro "PlanBot Ciclo BUK"
- [ ] A-09 P06 cuadratura · A-13 programación en Control Room (cada 5 min) y release `.bprelease`
- [ ] Extras: A-10 parámetros con simulación · A-11 asignaciones

### Equipo
- [ ] Integración en la VM (base + robot + dashboard) y prueba de punta a punta con `tests\e2e\guion.md`
- [ ] Presentación del pitch con lámina de arquitectura (armar cerca de la hora 10–11 con capturas reales)
- [ ] 3 ensayos de pitch (3 min) y demo (5 min); video de respaldo; `pg_dump` de respaldo
- [ ] Congelar código a las 14:30 de la hackathon

## 5. Decisiones tomadas (no volver a discutir)
- Nada de portales web: solo los dos Excel entregados.
- Windows nativo + PowerShell (scripts `.ps1`), sin Ubuntu.
- Back = PostgreSQL con lógica en SQL + PostgREST (sin servidor de aplicación propio). Front = HTML/JS estático.
- Blue Prism es el único que procesa los archivos en el sistema final; los scripts de carga de Andrés son solo para pruebas y escriben en las mismas tablas `stg.*`.
- Contrato v1.1 (horas por área en `v_instituto_area_mes`). Cambios de contrato solo con aviso a todos.
- El BUK trae solo ene–jul 2026: proyectar ago–dic; los casos de prueba usan ene–jul.
- Constantes de negocio siempre en `param.*`; redondeo hacia abajo `floor(x + 1e-9)`.
- Agentes: nunca ejecutar comandos que se quedan abiertos (servidores en primer plano, psql interactivo).
- Codex puede trabajar sin aprobaciones (`codex --dangerously-bypass-approvals-and-sandbox` o `config.toml`), solo dentro del proyecto.

## 6. Puntos abiertos y riesgos
- Reglas por confirmar con mentores: período ene–abr (44 h), descuento de julio, fórmula grupal (ED, AS, UTAC, UEDA, ULAB), beneficio de colación en 0 para algunos cargos.
- El BUK no trae licencias, vacaciones, permisos ni días adicionales: se usan valores del Excel (`semhab` en `esperado.csv`) como supuesto documentado.
- No hay Excel del SIC: la comparación planificado vs. realizado queda preparada sin datos reales.
- La base debe instalarse en la VM para que Blue Prism se conecte; confirmar el nombre exacto del driver ODBC en la VM.
- OneDrive puede bloquear archivos de Git: pausar la sincronización durante la hackathon.
- La carga de César es alta: si a la hora 9 va atrasado, recortar C-09, B-12, C-10, B-11, C-08, B-10 en ese orden.

## 7. Cómo seguir con ChatGPT (u otra IA)

1. Adjuntar este archivo y, si es posible, `AGENTS.md`, `docs\contratos.md`, `docs\reglas.md` y `docs\backlog.md`.
2. Pegar este mensaje:

> Eres mi asistente técnico en una hackathon de 16 horas. Te adjunto el estado completo del proyecto PlanBot (estado-proyecto.md) y sus documentos clave. Léelos y respeta las decisiones de la sección 5 y los contratos de docs\contratos.md (son ley). Mi rol es César: coordino al equipo, programo el front con Claude Code y Codex, y reviso los PR de Andrés. Ayúdame a: (1) decidir qué hacer a continuación según la sección 4; (2) escribir prompts detallados para Claude Code, Codex o el ChatGPT de Lucas, siguiendo el estilo de docs\prompts\; (3) resolver errores que te pegue; (4) preparar el pitch y la demo. Responde en español, breve y concreto. Antes de proponer cambios de arquitectura o de contrato, pregúntame.

3. Para continuar el trabajo de un agente que se quedó sin cuota, usar `docs\prompts\03-traspaso.md`.

## 8. Dónde está cada cosa
- Prompts: `docs\prompts\` (ver `LEEME.md`).
- Avance por agente: `docs\progreso-back.md` (Andrés), `docs\progreso-front.md` (Claude Code de César), `docs\progreso-codex.md` (Codex).
- Historias y criterios: `docs\backlog.md`. Contratos: `docs\contratos.md`. Reglas: `docs\reglas.md`.
- Pitch y demo: `docs\pitch.md`, `docs\demo.md`, `docs\arquitectura.md`.
- Código C# para Blue Prism: `bluePrism\codigo\`. Casos de prueba: `data\buk\`. Guion de pruebas: `tests\e2e\guion.md`.
