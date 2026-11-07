# Backlog de programación (Andrés: back · César: front)

Formato: `- [ ] ID · título` y debajo sus criterios. Al terminar una historia, cambia `[ ]` por `[x]` en su línea principal y en sus criterios.
**BACK** = Andrés con Claude Code en su computador. **FRONT** = César con Claude Code (Codex de respaldo). Cada uno revisa los PR del otro.

## BACK (Andrés)

- [ ] B-01 · Base instalada, roles y empaquetado (BACK, 3 pts)
  - [ ] `docker-compose.yml`: postgres:16 (volumen, 5432, variables de .env), postgrest (esquema api, rol anónimo web_lectura, CORS), nginx sirviendo `web\` en 8080
  - [ ] `database\migrations\V000__roles.sql` idempotente: owner_planbot, bot_carga, web_lectura, planificador
  - [ ] `scripts\migrar.ps1` (corre migrations, functions, views, seed en orden con psql) y `scripts\instalar_sin_docker.ps1`
  - [ ] `.env.example` sin secretos
- [ ] B-02 · Migraciones de esquemas y tablas (BACK, 3 pts)
  - [ ] Esquemas param, stg, core, calc, audit, api
  - [ ] Tablas stg.* exactamente como `docs\contratos.md`
  - [ ] param.* con version, vigente_desde, vigente_hasta; param.version, param.instituto(it, nombre, zona, grupo_it, correo_jefatura), param.cargo_homologado, param.general(clave, valor, descripcion)
  - [ ] core.persona, core.dotacion_mes pk(persona_id,it,mes), core.asignacion, core.excepcion_multi_it, core.cambios, core.alerta
  - [ ] calc.plan_mes pk(persona_id,it,mes), calc.escenario, calc.plan_mes_escenario, calc.cuadratura, audit.log
  - [ ] Correr todo dos veces no da error
  - [ ] `scripts\test.ps1 -Modulo db` + `tests\sql\000_humo.sql` verifican que existen esquemas y tablas
- [ ] B-03 · Parámetros iniciales (BACK, 2 pts) — los CSV YA ESTÁN en `data\csv`
  - [ ] Seed de param.general: meta 0.9, jornada_ene_abr 44, jornada_may_dic 42, pausa_pct_alta 0.10, pausa_pct_baja 0.06, colacion_h_dia 0.25, tramo_limite_bajo 22, tramo_limite_alto 40, max_asignaciones 2, horas_min_para_max 30, min_indirecta 30, dia_en_semanas 0.2
  - [ ] Carga de los CSV a stg.param_* y stg.excepcion y stg.esperado con un carga_id tipo 'planificacion'
  - [ ] `cargar_parametros(carga_id)` crea versión, cierra la anterior, valida sumas (inválidas a stg.error_fila)
  - [ ] param.instituto con los 16 institutos (IT, nombre, zona general/arica/nuble/aysen, grupo_it San-Con u otros) y param.cargo_homologado (cargos BUK → Distribucion_NAC)
- [ ] A-02/A-03 código · C# para Blue Prism (FRONT/César, 1 pt, entregar a Lucas antes de la hora 3) → `bluePrism\codigo\`
  - [ ] `PlanBot_PostgreSQL.cs`: Ejecutar Consulta, Ejecutar Comando, Ejecutar Función, Carga Masiva (lotes de 500, transacción, parámetros, solo tablas stg.*) con System.Data.Odbc, .NET 4.7, instrucciones de Code Options
  - [ ] `PlanBot_Archivos_Hash.cs`: SHA-256 hexadecimal en minúscula, lectura compartida
- [ ] B-04 · Normalización de la base de contratos (BACK, 3 pts)
  - [ ] `cargar_dotacion(carga_id)` → core.persona y core.dotacion_mes (upsert), mes = month(periodo), dias_semana = length(dias_jornada) o ndias
  - [ ] Cargo sin homologar → core.alerta
  - [ ] Vista calc.v_promedio_horas (promedio ponderado anual y flag aumento/disminucion/sin_cambio)
- [ ] B-05 · Cálculo semanal por período (BACK, 5 pts, MODO PLAN)
  - [ ] Vista calc.v_semanal por persona, it y periodo (ene_abr, may_dic) según `docs\reglas.md`
  - [ ] >= 98 % de coincidencia con esperado.csv en ate_dir_semana (may–dic)
  - [ ] Grupal en CTE separada y parametrizada
- [ ] B-06 · Plan mensual, meta y FOJA (BACK, 5 pts, MODO PLAN)
  - [ ] calc.plan_mes con semanas hábiles por zona, atenciones, meta, FOJA, version_param
  - [ ] 100 % en plan_ate_dir may–dic y >= 99 % en meta
- [ ] B-07 · Detección de cambios (BACK, 3 pts)
  - [ ] `detectar_cambios(carga_id)`: alta, baja, cambio_jornada, cambio_cargo, cambio_it, cambio_vigencia con mes_vigencia; inserta en core.cambios
  - [ ] `mes_minimo_afectado(carga_id)`
- [ ] B-08 · recalcular(desde_mes) (BACK, 3 pts)
  - [ ] Transaccional, meses anteriores intactos, < 10 s, registra en audit.log, GRANT a bot_carga
- [ ] B-09 · Vistas api.* (BACK, 2 pts)
  - [ ] Las 8 vistas con columnas exactas del contrato, GRANT SELECT a web_lectura
  - [ ] Suma de v_instituto_area_mes = v_kpi
- [ ] B-10 · cuadratura() (BACK, 2 pts, should)
- [ ] B-11 · Auditoría con triggers (BACK, 2 pts, should)
- [ ] B-12 · Escenarios, simular() y aplicar_escenario() (BACK, 5 pts, should)
- [ ] B-13 · Multi-instituto (BACK, 3 pts, could)

## FRONT (César)

- [x] D-02 · Extractor de Excel a CSV (hecho: `data\extraer.py`, CSV en `data\csv`)
- [ ] D-03 · Mocks JSON de las 8 vistas en `web\mock\` (FRONT, 1 pt)
  - [ ] Columnas exactas de `docs\contratos.md`; 3 institutos (131 San, 81 Con, 11 Ari), 4 áreas, 12 meses, 15 profesionales; meta = floor(atenciones × 0.9)
- [ ] C-02 · Esqueleto web y cliente de datos (FRONT, 3 pts)
  - [ ] index.html accesible, menú (Nacional, Instituto, Profesional, Cambios, Parámetros, Cuadratura), router por #hash
  - [ ] config.js (modo mock/api), api.js getData(vista, filtros), manejo de carga y errores
  - [ ] ECharts y Tabulator en web\vendor
- [ ] C-03 · Pantalla Nacional (FRONT, 5 pts)
  - [ ] Tarjetas de v_kpi; línea mensual con mayo marcado (42 h); barras por instituto (clic → instituto); apiladas directa/indirecta/NAS por área; tabla alternativa accesible
- [ ] C-04 · Filtros globales sincronizados con la URL (FRONT, 3 pts)
- [ ] C-05 · Pantalla Instituto y área (FRONT, 3 pts)
- [ ] C-06 · Pantalla Profesional con historial de cambios (FRONT, 3 pts)
- [ ] C-07 · Pantalla Cambios y errores de carga (FRONT, 3 pts)
- [ ] D-04 · Bases de prueba en `data\buk\` (FRONT, 3 pts)
  - [ ] 01_original.xlsx, 02_cambios.xlsx (40→44 h desde junio, baja desde agosto, alta 999001 desde julio, cambio de cargo desde septiembre, cambio de IT desde octubre), 03_errores.xlsx (horas 0, fechas incoherentes, cargo inexistente, duplicado, texto en número), esperado_cambios.csv, esperado_errores.csv
- [ ] D-05 · Pruebas SQL con 10 casos dorados de esperado.csv y prueba de forma de vistas (BACK/Andrés, 3 pts) → `tests\sql\`
- [ ] D-06 · CI en GitHub Actions (ubuntu-latest, servicio postgres:16, pwsh corre migrar.ps1 y test.ps1, ESLint) (FRONT, 2 pts)
- [ ] C-01 · postgrest.conf y prueba de endpoints (BACK/Andrés, 2 pts)
- [ ] C-08 · Pantalla Cuadratura (FRONT, 2 pts, should)
- [ ] C-10 · Accesibilidad y lectura fácil (FRONT, 2 pts, should)
- [ ] C-09 · Pantalla Parámetros y simulación (FRONT, 5 pts, should)
- [ ] C-11 · Exportar CSV e imprimir (FRONT, 1 pt, could)
