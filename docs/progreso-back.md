# Progreso BACK (Andrés · Claude Code)
Última actualización: 2026-11-07 · por: Claude Code
Rama actual: feat/B-05-semanal (sale de feat/B-04-dotacion; PR por web porque gh no está instalado)

## Hecho
- B-01 · docker-compose.yml, V000__roles.sql, .env.example, scripts\_comun.ps1 (elige docker/nativo),
  migrar.ps1, test.ps1, instalar_sin_docker.ps1, database\instalar\crear_base.sql. Probado en nativo.
- B-02 · V001 esquemas, V002 stg.* (Contrato 1 exacto), V003 param.* y core.*, V004 calc.* y audit.log,
  tests\sql\000_humo.sql. instalar_sin_docker.ps1 corrido 2 veces sin error; test.ps1 -Modulo db y todo en verde.
- B-03 · seed 010 (param.general: 12 constantes en versión 1 + 16 institutos), seed 020 (homologación de los 15 cargos
  del BUK), seed 030 (\copy de los 6 CSV a stg.* con carga 'planificacion', hash `seed:planificacion:csv-v1`),
  `api.cargar_parametros` (versión nueva, cierra la anterior, merge por clave, sumas inválidas a stg.error_fila,
  idempotente por carga). tests\sql\001_parametros.sql en verde.
- B-04 · `api.cargar_dotacion` (foto completa por carga BUK: errores de fila a stg.error_fila, cargo sin homologar y
  duplicados a core.alerta, upsert en core.persona y core.dotacion_mes, proyección ago-dic con origen 'proyectado'),
  `calc.v_promedio_horas` (promedio igual al Excel en 456/466 = 97,9 %), `scripts\cargar_buk_prueba.ps1` +
  `scripts\buk_a_csv.py` (solo pruebas). Base real: 3.123 filas buk + 2.215 proyectadas, 465 persona-IT, 0 alertas.
  tests\sql\002_dotacion.sql (sintético, corre en CI) en verde.

## En curso
- B-05 · `calc.v_semanal` hecha (V005 core.condicion_persona, api.cargar_asignaciones, seed 040 con
  database\seed\csv\asignaciones.csv y condiciones_persona.csv extraídos con scripts\extraer_condiciones.py).
  tests\sql\010_semanal.sql (guardia >= 95,5 % + caso sintético 137732) en verde.
  Coincidencia may-dic: ate_dir_semana 425/450 = 94,4 % con horas de dic (v0) -> 431/450 = 95,8 % con promedio
  may-dic (v1), 0 aciertos perdidos; pct_dir_final 430 -> 438/450. Criterio >= 98 % ABIERTO.
  Evidencia completa en database\evidencia\b05\LEEME.md (scripts\casos_buk.ps1 + scripts\evidencia_b05.ps1).
  19 diferencias v1: 4 distribución por área (TO ULAB/UTA, EDUCADOR UTA), 4 minutos 60 vs 40, 8 horas BUK ≠ Excel,
  1 sin fila en param (71613), 1 cambio de cargo (72365), 1 otra (134744). Sin excepciones por persona.
  Pendiente César: confirmar regla "horas del periodo = promedio may-dic" y homologación cargo + sub_area.
  Casos D-04: 01/02/03 cargan con conteos correctos (03: 3124 leídas, 3119 válidas, 5 con error).

## Siguiente
- B-06 (MODO PLAN: mostrar plan antes de programar), C-01, B-07+B-08; prioridad B-09 (vistas api.* para César).

## Cómo correr en este PC (laboratorio Duoc, sin admin, NO reiniciar)
- Repo en `C:\dev\botathon`. Servicio `postgresql-x64-16` (puerto 5432) ya está en Running; superusuario `postgres`.
- `.env` (no versionado): copiar `.env.example`, poner claves y `PG_SUPER_PASSWORD`; `PG_HOST`/`PG_PORT`/`PG_BIN`
  por defecto localhost, 5432, `C:\Program Files\PostgreSQL\16\bin`.
- `.\scripts\instalar_sin_docker.ps1` (crea rol owner_planbot y base planbot, luego migra) · `.\scripts\test.ps1 -Modulo db`.
- Plan B sin servicio: instancia propia en `C:\dev\pgdata` (initdb -U postgres -A trust -E UTF8 --locale=C, port 5433),
  `pg_ctl -D C:\dev\pgdata -l C:\dev\pgdata\log.txt start`; en `.env` poner `PG_PORT=5433`. Ya está creada (detenida).
  Ojo: lanzar pg_ctl start desde PowerShell, no desde Git Bash (bash queda esperando).

## Errores conocidos / decisiones
- **Horas del periodo (B-05, por confirmar con César):** el Excel usa el PROMEDIO de las horas de los meses del
  periodo (may-dic, incluye proyectados), no las de diciembre (40 h may-jun + 30 h jul-dic -> 32,5 h): 9/9 filas
  "Cambio jornada" calzan exacto. NAS = %NAS × promedio ponderado ANUAL. Tramo por promedio anual: INFERIDO (la hoja no
  tiene fórmulas; 17 filas discriminan y todas favorecen el promedio, 0 en contra).
- **Grupal (B-05):** directa + grupal = ate_dir × (1 − %grupal) + ate_dir × %grupal × pacientes (sin redondeo).
- **Promedio ponderado (B-04):** el Excel promedia con igual peso cada mes con contrato (reales + proyectados hasta
  fecha_termino o diciembre) y redondea hacia abajo (floor(x + 1e-9)). Ponderar por semanas da 454/466, peor.
  Las 10 diferencias son personas cuyas horas en el Excel de planificación no coinciden con el BUK (excepciones, multi-IT).
- **Proyección (B-04):** solo se proyecta a quien está en el último mes de la carga (julio); quien desaparece antes
  (p. ej. último mes mayo sin fecha_termino) se considera egresado y no se proyecta. Cada carga BUK es una foto completa:
  core.dotacion_mes se reemplaza por lo real de esa carga + su proyección.
- Cargar la base real para pruebas: `.\scripts\cargar_buk_prueba.ps1` (requiere `pip install --user openpyxl`;
  `-Forzar` para recargar el mismo archivo, `-Archivo data\buk\01_original.xlsx` para otra base).
- **Homologación de cargos (B-03):** el BUK 2026 tiene solo 15 cargos y todos calzan por nombre con param_cargo.
  Dudosos: EDUCADOR (BUK Cod_Esp ULAB; existe EDUCADOR NAS 0.30 y EDUCADOR ULAB NAS 0.50; se eligió EDUCADOR porque la
  hoja de planificación muestra %NAS ~0.30) y MEDICO GENERAL (igual a MEDICO GENERAL FI). `cod_esp` homologado = el
  del BUK: la columna cod_esp de param_cargo.csv viene desfasada (p. ej. FONOAUDIOLOGO con FI) y no se usa.
- **Datos por persona que NO están en los CSV (afecta B-05):** asignaciones 1-4 y sus horas, colación en contrato,
  otras NAS, licencias/vacaciones. Están en la hoja Dotacion_Asistencial del Excel de planificación. Para B-05/B-06
  se usará stg.esperado (pct_dir_final, semhab) como fuente temporal o se extraerán a un CSV (pedir a César/Codex,
  data\ no es del BACK).
- El BUK trae `Fecha de Nacimiento` (regla de cumpleaños) pero no está en el Contrato 1 de stg.buk_fila.
- Institutos: nombre = campo Área del BUK (Arica, ..., O'Higgins); 102 Castro no aparece en el BUK 2026.
- Python del PC: sin pandas; `pip install --user openpyxl` funciona (correr python SIN -I para ver el site de usuario).
- **Proyección ago-dic (regla de negocio, 6-nov):** stg.buk_fila solo trae ene-jul 2026 (corte de mitad de año).
  En B-04, `cargar_dotacion` genera los meses siguientes al último mes real de cada persona-IT, copiando sus
  condiciones (horas, cargo, área, contrato, días), hasta el mes de `fecha_termino` (incluido) o diciembre si no tiene.
  `core.dotacion_mes.origen` = 'buk' (real) | 'proyectado'. Un mes real posterior reemplaza al proyectado.
  Supuesto pendiente de confirmar: el mes de fecha_termino se proyecta completo (sin prorrateo).
  En B-07, `detectar_cambios` compara solo los (persona_id, it, mes) presentes en stg.buk_fila de ambas cargas.
- PC de laboratorio con PowerShell 5.1 (sin pwsh 7): .ps1 en UTF-8 con BOM, sin operadores de PS7. Rutas armadas
  con Join-Path y separador del sistema para que el CI (ubuntu + pwsh) también corra.
- Los scripts leen PG_HOST/PG_PORT y aceptan PGHOST/PGPORT o POSTGRES_HOST/POSTGRES_PORT (nombres del CI).
- Funciones del Contrato 2 irán en el esquema `api`; bot_carga tiene search_path `api, stg, public`
  para llamarlas sin prefijo. EXECUTE se revoca de PUBLIC por defecto y se da explícito por historia.
- Versionadas: cargo_distribucion, asignacion_catalogo, calendario_mes, grupal, general (version + vigencia).
  Catálogos sin versión: instituto, cargo_homologado.
- cargo_distribucion pk (version, cargo, tramo): 57 cargos vienen sin cod_esp. asignacion_catalogo con id propio
  (tipo se repite 2 veces en el CSV).
- PostgREST se conecta como web_lectura y usa el mismo rol como anónimo.
- No hay pandas en este PC (para B-04 hará falta `pip install --user pandas openpyxl` o usar csv/openpyxl).
