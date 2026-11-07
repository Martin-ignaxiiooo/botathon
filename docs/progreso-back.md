# Progreso BACK (Andrés · Claude Code)
Última actualización: 2026-11-07 · por: Claude Code
Rama actual: main (fix/area-sigue-it #11 y feat/C-01-jwt #10 fusionados)
Reparto 7-nov: B-09 (vistas api.*, database\views\) lo hace el Codex de César en feat/B-09-vistas; el BACK revisa
y fusiona su PR. El BACK no toca database\views\ mientras tanto.

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
  La regla semanal se mantiene tal cual. Codex mide 98,66 % en su capa B, pero con insumos del Excel; no es esta
  cifra de punta a punta. 134744/11 es una diferencia explicada: 20 × 0,75 × 0,825 / 0,85 = 14,56 -> floor 14 y el
  Excel dice 15. No sale de los insumos con la regla escrita, y no se ajusta.
- B-06 (SIMPLIFICADO) · `calc.calcular_plan(p_desde_mes)` en database\functions\040_calcular_plan.sql + V006
  (`calc.plan_mes_traza`: fuente de semanas por fila). Puebla calc.plan_mes (5.338 filas, base real).
  - **Semanas hábiles:** `semhab` de stg.esperado (última carga con semhab; persona-IT repetida -> el máximo del mes).
    Si la persona no tiene valor: semanas de param.calendario_mes (zona del IT; si no hay, 'general'),
    fuente 'calendario'.
  - **Atenciones:** ate_dir = floor(directas+grupal/sem × SH); ate_dir_ind = floor((dir+grupal+ind)/sem × SH);
    meta = floor(ate_dir × meta).
  - **Horas [h/mes]:** contratadas = h × S; dir/ind/nas = (h − colación) × %final × SH; foja = horas_dir / horas_contratadas.
    Las ausencias no se cargan a horas_nas.
  - **may-dic:** capa aislada (semanal y semhab del Excel) plan_ate_dir 3752/3752 = 100 %, meta 3747/3752 = 99,87 %.
    Cálculo completo: plan_ate_dir 3394/3552 = 95,55 %, meta 3393/3552 = 95,52 %. Las 158 diferencias de
    atenciones son de 20 persona-IT con semanal distinto (B-05) y 1 es "otra". Ene-abr: 95,35 % completo; la capa
    aislada da 65 % porque el Excel no guarda el semanal de ene-abr (limitación).
  - Evidencia: database\evidencia\b06\resumen.txt y diferencias_*.csv (scripts\evidencia_b06.ps1).
    tests\sql\020_plan_mes.sql (137732, alta, baja, unidades FOJA, recálculo desde 9) en verde.
  - **Mejora pendiente (no implementada):** V006 completa con ausencias, beneficios y cumpleaños desde el Excel, para
    calcular semanas hábiles por regla. Fórmulas y evidencia en database\evidencia\b06\formulas.md: la regla reproduce
    SemHab en 100 % de los meses con valor, con techo a 1 decimal en mayo y julio (inferido).
    Pendientes: zona extrema y valores para altas.

- B-07 · `api.detectar_cambios(carga_id)` y `api.mes_minimo_afectado(carga_id)` (database\functions\050).
  - Compara contra la carga 'buk' anterior que tenga filas, usando solo meses reales del BUK.
  - Reglas por tipo:
    - jornada y cargo: solo en (persona, it, mes) presentes en las dos cargas;
    - cambio_it: mismo mes, otro IT;
    - alta: persona nueva;
    - baja: pierde meses al final;
    - cambio_vigencia: cambia fecha_ingreso o fecha_termino; mes = el de la fecha más temprana.
  - Escribe en core.cambios y se puede re-ejecutar. mes_minimo_afectado da 1 en la primera carga y NULL si no hay
    cambios (en ese caso Blue Prism NO llama a recalcular).
  - Casos D-04: 5/5 iguales a data\buk\esperado_cambios.csv (database\evidencia\b07\casos_cambios.md).
- B-08 · `api.recalcular(desde_mes)` -> table(filas, ms) (database\functions\060): llama a calc.calcular_plan en la
  transacción de la llamada; los meses anteriores no se tocan. Registra en audit.log (motivo = planbot.motivo).
  Base real desde mes 3: 4.447 filas en 125 ms.
  - GRANT EXECUTE a bot_carga en las 3 funciones; web_lectura no las tiene.
  - tests\sql\030_cambios_recalcular.sql en verde.
- Ojo al compilar a mano: hacerlo como owner_planbot o con migrar.ps1. Si se compila como postgres, la función
  queda con otro dueño y migrar falla con "debe ser dueño".

- **Conteos de stg.carga en cargar_dotacion (paso 4, 7-nov):**
  - **Errores del robot:** los que Blue Prism dejó en stg.error_fila; su motivo NO empieza con 'cargar_dotacion:'.
  - **Errores de la base:** los que agrega la función, con ese prefijo. Al re-ejecutar se borran y se recalculan;
    los del robot no se tocan.
  - **Repetidos:** errores del robot con el mismo (persona_id, campo) que un error de la base. Esa fila también
    llegó a stg.buk_fila y la base ya la contó.
  - Fórmulas:
    - `con_error = robot + base − repetidos`
    - `leidas = filas de stg.buk_fila + robot − repetidos`
    - `validas = filas pasadas a core.dotacion_mes`
  - Probado en tests\sql\002 (error del robot repetido sobre 900005: 24/19/5) y con 03_errores (3124/3119/5).
- Prueba de cambios renombrada a tests\sql\035_cambios_recalcular.sql: Codex usa 030_vistas.sql para B-09.
- B-10 · `api.cuadratura()` (database\functions\070_cuadratura.sql, V007 param.cuadratura_explicada) hecha.
  - Compara la última carga de stg.esperado con calc.v_semanal (may_dic) y calc.plan_mes; guarda SOLO diferencias
    (|excel − sistema| ≥ 1e-6) en calc.cuadratura → api.v_cuadratura. diferencia = sistema − excel.
  - Sin fila en el sistema cuenta como 0 (coincide si el Excel dice 0); si el Excel repite persona-IT, vale la más cercana.
  - Causa (la primera que aplica): diferencia_explicada (param.cuadratura_explicada: 134744/11, floor 14,56 vs 15)
    → ajuste_individual (semanal may-dic distinto, o plan may-dic distinto con las mismas semhab: 19 persona-IT de
    B-05) → periodo_ene_abr → dias_adicionales (semhab distinta) → multi_it → grupal → otra.
  - Devuelve % plan_ate_dir may-dic sobre persona-IT-mes con plan en el sistema: 3394/3552 = 95,55 %.
  - Base real: 1.518 diferencias, 135 personas (ajuste 950, multi_it 338, grupal 88, ene-abr 65, explicada 50, otra 27).
    Las 5 persona-IT del Excel con otro IT que el BUK (p. ej. 71342/61) salen multi_it.
  - instalar_sin_docker.ps1 -CargarBukPrueba ahora corre también api.cuadratura(). tests\sql\040_cuadratura.sql.
- B-11 · Auditoría con triggers (database\functions\080_auditoria.sql) hecha.
  - Trigger `auditar` AFTER INSERT/UPDATE/DELETE FOR EACH ROW en todas las tablas de param.* (se agrega solo a las
    nuevas al correr migrar.ps1), core.asignacion y calc.escenario → `audit.registrar()` (SECURITY DEFINER).
  - audit.log: tabla esquema.tabla, operacion insert|update|delete, usuario session_user, motivo
    current_setting('planbot.motivo') o NULL, antes/despues jsonb. UPDATE sin cambios no se registra (semilla repetible).
  - calc.plan_mes NO tiene trigger: recalcular() deja una sola fila resumen (B-08).
  - Instalación desde cero: la semilla queda registrada como insert con motivo NULL. tests\sql\050_auditoria.sql.
- D-05 · Casos dorados (tests\sql\060_casos_dorados.sql) hecha. 10 persona-IT del Excel que el sistema reproduce
  exacto, calculadas en CI desde sus 70 filas BUK embebidas (solo persona_id): 71853/12, 72379/51, 76852/11 (arica),
  73182/51, 71509/101, 132962/41, 72253/81, 125926/131, 71425/91 (grupal 55 %), 71132/131. Cubre cambio de jornada,
  colación, asignaciones 0,25-6 h, 7 cargos. Usa api.cuadratura(): ninguna diferencia (salvo ate_semana_total grupal).
  Generador: se armó con una consulta a la carga BUK local 63 (filas copiadas tal cual al test).
- B-12 · Escenarios (database\functions\090_escenarios.sql, V008__escenario_flujo.sql) hecha.
  - Flujo: borrador → simular() → pendiente → decidir_escenario() → aprobado | rechazado → aplicar_escenario() → aplicado.
    V008 cambia el CHECK de estado (antes borrador/simulado/aprobado/descartado) y agrega impacto, simulado_en,
    decision_motivo, decidido_por, decidido_en, aplicado_en.
  - calc.escenario.cambios = {"general": {"<clave>": valor}} (MVP: solo param.general; de esas claves solo `meta`
    mueve el plan, las demás tienen valor por cargo o son informativas).
  - `api.simular(p_escenario_id)`: aplica los cambios en un subbloque, corre calcular_plan(1), guarda el resultado en
    calc.plan_mes_escenario y deshace todo (param.* y calc.plan_mes intactos; ~0,5 s). Devuelve
    (it, area, atenciones_antes, atenciones_despues, meta_antes, meta_despues, diferencia_meta) y deja
    calc.escenario.impacto por instituto. GRANT bot_carga, planificador.
  - `api.aplicar_escenario(p_escenario_id)` → int: solo 'aprobado'. Versión nueva de param.* (copia de la vigente +
    cambios, param.version.escenario_id), cierra la anterior, recalcular(1), estado 'aplicado'. GRANT bot_carga.
  - `api.listar_escenarios()`: columnas de docs\progreso-front.md (escenario_id, descripcion, parametro,
    valor_actual, valor_propuesto, estado, creado_por, creado_en, decision_motivo, impacto). GRANT web_lectura,
    planificador, bot_carga.
  - `api.decidir_escenario(escenario_id, decision, motivo)` → text (estado nuevo): 'aprobar' | 'rechazar' sobre
    pendiente o borrador; motivo obligatorio, se fija como planbot.motivo y queda en audit.log. Aprobar solo cambia
    el estado. GRANT solo planificador (PostgREST tiene que usar ese rol para esta llamada).
  - database\demo\escenarios_demo.sql (lo corre instalar_sin_docker.ps1 -CargarBukPrueba): meta 92 % pendiente
    (+12.202 de meta), 91 % aprobado (+6.021), 95 % rechazado (+30.980). Idempotente.
  - tests\sql\070_escenarios.sql. Funciones nuevas fuera del Contrato 2 (listar/decidir): PR con etiqueta contrato.
- Fix (aviso del front) · area sigue al IT. Causa: en el BUK la area es la sede (1 por IT); el 02_cambios.xlsx de
  prueba cambia IT e Instituto de 71146 desde julio pero deja Area = Santiago, y cargar_dotacion la copiaba.
  Ahora cargar_dotacion usa la area más frecuente del IT en esa carga cuando una fila trae otra, también en la
  proyección, y deja core.alerta 'area_distinta_it' (detalle: area_buk, area_usada, meses). Base real: 0 alertas.
  Para Codex: data\generar_casos.py debería cambiar también Area (y Centro de costo) en el traslado.
- recalcular() rehace api.cuadratura() al final si stg.esperado tiene datos (audit.log guarda cuadratura_pct):
  api.v_cuadratura ya no mezcla plan nuevo con diferencias viejas, y Blue Prism no necesita llamarla aparte.
  recalcular(1) con la base real: 1,15 s. tests\sql\090_area_y_cuadratura.sql.
- C-01 (parte BACK) · PostgREST con JWT. Decisión: decidir_escenario solo planificador, el front se autentica con JWT.
  - api\postgrest.conf sin credenciales: db-uri = "$(PGRST_DB_URI)", jwt-secret = "$(PGRST_JWT_SECRET)" (PostgREST
    interpola el entorno), anon web_lectura, role claim .role, puerto 3000, CORS http://localhost:8080.
  - docker-compose.yml: PGRST_JWT_SECRET obligatorio (${...:?}), no base64, claim .role.
  - instalar_sin_docker.ps1: genera PGRST_JWT_SECRET de 40 caracteres si falta, es el de ejemplo o tiene < 32.
  - database\views\zz_permisos_jwt.sql: `GRANT planificador TO web_lectura WITH INHERIT FALSE, SET TRUE` (PostgREST
    puede cambiar de rol con token; sin token sigue de solo lectura) + SELECT de api.* a planificador.
    tests\sql\080_permisos_jwt.sql.
  - scripts\token_planificador.ps1 [-Horas 24]: JWT HS256 {"role":"planificador","exp":ahora+24h} con el secreto de
    .env; imprime solo el token (el aviso va a stderr), no lo guarda. Verificado: firma HMAC correcta y
    SET ROLE planificador desde web_lectura ejecuta decidir_escenario.

## Siguiente
- Apoyar la integración en la VM (extras congelados a las 7:00).
- Pendiente para el front/PostgREST: decidir_escenario requiere el rol planificador (JWT o segundo PostgREST).
- Si sobra tiempo: usar data\csv\insumos.csv (Codex) para minutos, distribución y asignaciones por persona, como
  excepción documentada, y subir del 95,5 %.

## Instalación en la VM de la demo (paso 5) · un solo comando
Requisitos: Windows con PostgreSQL 16 instalado y su servicio corriendo en el puerto 5432. También Git, la clave del
superusuario `postgres` y, solo para cargar datos de prueba, Python con `pip install --user openpyxl`.
No usa Docker, no reinicia y no pide permisos de administrador.
```powershell
git clone https://github.com/Martin-ignaxiiooo/botathon.git C:\dev\botathon   # o git pull en main si ya existe
cd C:\dev\botathon
.\scripts\instalar_sin_docker.ps1 -SuperClave '<clave de postgres>' -CargarBukPrueba
```
1. Si no hay `.env`, lo crea desde `.env.example` con claves aleatorias para owner_planbot, bot_carga, web_lectura
   y el JWT. Las claves no se muestran en pantalla y `.env` no se versiona.
2. Crea el rol owner_planbot y la base planbot (UTF8, America/Santiago).
3. Corre migraciones, funciones, vistas y semilla; los roles quedan con las claves de `.env`.
4. Con `-CargarBukPrueba` carga `data\excel\Nac - Base contratos x mes.xlsx` (unos 3 minutos) y ejecuta
   `api.recalcular(1)`. Sin ese parámetro, la base queda vacía para que cargue Blue Prism.
5. Al final corre `.\scripts\test.ps1 -Modulo db`. Debe terminar con "Instalación lista".

Notas:
- Otros parámetros: `-Puerto 5433`, `-PgBin <ruta bin>`, `-SuperUsuario <rol>` y `-SinPruebas`.
- Se puede repetir sin riesgo. Si `.env` ya existe, se reutiliza y las claves no cambian.
- **Blue Prism (Lucas):** se conecta a `localhost:5432`, base `planbot`, usuario `bot_carga`, con la clave
  `BOT_CARGA_PASSWORD` del `.env` de la VM. Se le pasa por mensaje privado, nunca por el repo ni el chat del equipo.
  `bot_carga` tiene search_path `api, stg, public`, así que llama las funciones sin prefijo. Para ver la clave en
  la VM: `Select-String BOT_CARGA_PASSWORD .env`.
- **PostgREST:** se conecta como `web_lectura` (`WEB_LECTURA_PASSWORD`), en `api\postgrest.conf`.

## Token de planificador en la VM (aprobar / rechazar escenarios)
```powershell
cd C:\dev\botathon
.\scripts\token_planificador.ps1            # imprime el token (vence en 24 h); -Horas 8 para otro plazo
$t = .\scripts\token_planificador.ps1       # o guardarlo en una variable de la sesión
Invoke-RestMethod -Method Post http://localhost:3000/rpc/decidir_escenario -ContentType 'application/json' `
  -Headers @{ Authorization = "Bearer $t" } -Body '{"escenario_id": 1, "decision": "rechazar", "motivo": "prueba"}'
```
- El token se firma con PGRST_JWT_SECRET de .env: PostgREST debe arrancar con ESE mismo secreto en su entorno
  (si el instalador generó uno nuevo, reiniciar PostgREST). Si cambia el secreto, los tokens anteriores dejan de valer.
- No guardar el token en el repo ni pegarlo en el chat; se entrega al front por la vía que defina César.
- Sin token, decidir_escenario responde 401/403 (permiso denegado): es lo esperado.
- Ojo Codex: tools\vm\levantar_demo.ps1 quita las líneas jwt-* y las variables PGRST_* y no importa
  PGRST_JWT_SECRET; debe pasar PGRST_JWT_SECRET de .env al proceso de PostgREST (o usar api\postgrest.conf tal cual).

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
