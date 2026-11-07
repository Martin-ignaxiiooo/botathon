# Instalación en la VM Windows de demo

Ejecutar desde la raíz del clon en Windows PowerShell 5.1 o PowerShell 7. Usar una base de demo, coordinar migraciones con Andrés y pausar las cargas de Lucas antes de reiniciar datos. El arranque no deja consolas de servidores bloqueadas.

## 1. Requisitos y clon

Instalar Git, PostgreSQL **16** con psql/pg_dump y servicio activo, Python 3 con openpyxl y psqlODBC Unicode **x64**. Blue Prism **7.5.1** necesita licencia, su propia base interna y Runtime Resource operativo; la base planbot es distinta. Se necesita Internet para clonar/descargar PostgREST y escritura en C:\tools y C:\PlanBot.

```powershell
git clone https://github.com/Martin-ignaxiiooo/botathon.git C:\dev\botathon
Set-Location C:\dev\botathon
python -m pip install openpyxl
& 'C:\Program Files\PostgreSQL\16\bin\psql.exe' --version
& 'C:\Program Files\PostgreSQL\16\bin\pg_isready.exe' -h localhost -p 5432
```

Comprobar que el clon integrado incluye tools\vm, scripts\instalar_sin_docker.ps1, scripts\servir_web.ps1, scripts\reiniciar_demo.ps1, database y web. Si el PR sigue pendiente, usar la revisión integrada aprobada; no copiar SQL de otras versiones a mano.

Abrir **Orígenes de datos ODBC (64 bits)** → Controladores y comprobar PostgreSQL Unicode(x64). Runtime y driver deben ser x64. Fuente: [psqlODBC oficial](https://odbc.postgresql.org/). El lanzador no instala PostgreSQL, ODBC ni Blue Prism.

## 2. Configuración local

El administrador configura **PG_SUPER_PASSWORD** en el .env local o en el entorno del proceso: es la clave administrativa de PG_SUPER_USER (por defecto postgres). Sin ella el instalador se detiene. Aprovisionarla desde el gestor de secretos de la VM o editar exclusivamente .env en el equipo autorizado. No escribir valores en comandos, argumentos, historial o capturas ni mostrar .env.

Si .env no existe, el instalador lo crea y genera claves de aplicación/JWT. Si existe, completar localmente POSTGRES_PASSWORD, BOT_CARGA_PASSWORD y WEB_LECTURA_PASSWORD, sin dejar marcadores cambiar. PGRST_JWT_SECRET se genera/renueva si falta, es de ejemplo o tiene menos de 32 caracteres. Nunca publicar su contenido.

Conexión: POSTGRES_DB, POSTGRES_USER, PG_HOST, PG_PORT y PG_BIN. Predeterminados: planbot, owner_planbot, localhost, 5432 y bin de PostgreSQL 16. No envolver los valores en comillas: estos lectores no son un intérprete de shell.

.env está excluido de Git: restringir lectura a las cuentas autorizadas. El lanzador importa configuración en memoria y restaura el entorno del llamador. Conserva PG_SUPER_PASSWORD válida del entorno si el archivo contiene un marcador. El instalador puede guardar esa configuración en .env local; protegerlo y no adjuntarlo como evidencia.

## 3. Arranque en un comando

```powershell
.\tools\vm\levantar_demo.ps1
# Solo para preparar explícitamente datos BUK y escenarios iniciales:
# .\tools\vm\levantar_demo.ps1 -CargarBukPrueba
```

Siempre corre scripts\instalar_sin_docker.ps1 -SinPruebas, también con base existente y después de git pull: crea lo ausente y aplica migraciones, funciones, vistas y seed. Es repetible, pero modifica la base: reservar una ventana. Sin BUK, plan_mes puede estar vacío y el verificador lo marca rojo. CargarBukPrueba es explícito, no predeterminado.

Crea C:\PlanBot\entrada\planificacion, entrada\buk, entrada\asignaciones, procesados, errores, logs, respaldo, preparar y runtime. Descarga/verifica C:\tools\postgrest.exe desde el release oficial fijado en [postgrest-version.json](../tools/vm/postgrest-version.json), única definición de versión de tools\vm. Agrega bin de PostgreSQL al PATH del hijo para libpq.dll.

Genera runtime\postgrest.conf desde api\postgrest.conf; si falta, avisa y usa el respaldo de tools\vm. Publica api, rol anónimo web_lectura, 127.0.0.1:3000 y CORS para http://localhost:8080. URI/JWT se pasan por entorno sin secretos en conf/argv; conserva ajustes JWT de la plantilla. Inicia PostgREST y servir_web ocultos con Start-Process y guarda logs e identidad de procesos en runtime. Tras migrar reinicia solo su API registrada; no adopta ni detiene procesos ajenos.

Termina con verificar_vm. Abrir **http://localhost:8080/?modo=api#nacional**, confirmar «En vivo: base de datos» y pulsar **Actualizar datos** tras la carga. API: **http://localhost:3000/v_kpi**. localhost es local a la VM, no una URL pública. Cambiar puertos de ensayo no reconfigura automáticamente el front.

## 4. Diagnóstico y detención

El diagnóstico independiente no importa .env. En una consola de mantenimiento autorizada, importar solo las variables necesarias sin mostrarlas ni evaluar código:

```powershell
$clavesVm = @('PG_HOST','PG_PORT','PG_BIN','POSTGRES_DB','POSTGRES_USER',
              'POSTGRES_PASSWORD','BOT_CARGA_PASSWORD','WEB_LECTURA_PASSWORD')
foreach ($lineaVm in [IO.File]::ReadAllLines((Join-Path (Get-Location) '.env'))) {
    if ($lineaVm -match '^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$' -and $Matches[1] -in $clavesVm) {
        [Environment]::SetEnvironmentVariable($Matches[1],$Matches[2].Trim(),'Process')
    }
}
.\tools\vm\verificar_vm.ps1
# Al terminar en esta consola de mantenimiento:
foreach ($claveVm in $clavesVm) { [Environment]::SetEnvironmentVariable($claveVm,$null,'Process') }
```

Comprueba carpetas, driver Registry64, puerto, logins, ocho RPC contractuales, ocho vistas leídas como web_lectura, plan poblado, KPI HTTP contra SQL, CORS y web. Las consultas SQL son de solo lectura; el propietario cuenta el plan. Además revisa listar_escenarios y autorización de decidir_escenario: una decisión inválida con JWT alcanza la validación sin modificar datos; sin token obtiene 401/403. No imprime ni guarda el token/secreto. Exit 0 exige todo verde; exit 1 conserva pendientes.

```powershell
.\tools\vm\detener_demo.ps1
```

Detiene solo procesos registrados cuya identidad coincide. Conserva PostgreSQL, Blue Prism, procesos ajenos y datos. Si un puerto está ocupado, coordinar con el responsable; no cerrar procesos por nombre.

## 5. Blue Prism y autorización

Importar el release de Lucas mediante Release Manager, resolver VBO y ejecutar **Check Code**. Los .cs son referencia, no un release importable. Seguir [guia_procesos.md](../bluePrism/codigo/guia_procesos.md) y [LEEME.md](../bluePrism/codigo/LEEME.md). Para compilación externa:

```powershell
.\tools\vm\compilar_bp.ps1
```

Usa csc de Framework 4, referencias System.dll, System.Data.dll y System.Xml.dll, sin referencias implícitas. **System.Data.Odbc está incluido en System.Data.dll**. Microsoft.VisualBasic solo se usa en la consola CSV. Compilar no certifica Runtime/ODBC.

Crear **PlanBot_Postgres** en Credential Manager para bot_carga, con su clave aprovisionada y permisos al proceso/runtime. Crear la Environment Variable BP **ConnStrSinClave**:

```text
Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;
```

Armar Conexion usa **Credentials > Get Login** y OdbcConnectionStringBuilder. La clave debe coincidir con la del rol bot_carga, nunca la del propietario. No ponerla en variables BP, capturas ni logs. Probar SELECT 1 AS prueba: una fila con 1.

Crear cola **PlanBot_BUK**, un ítem por archivo, sin retry automático de lotes parciales. Catálogos aprobados: it y cargo_origen. Configurar rutas/permisos según el release. En Control Room → Scheduler programar solo **PlanBot Ciclo BUK** sobre el Runtime conectado, sin consumidores simultáneos. P00 carga reglas antes del ciclo, no por archivo; si ya se sembraron, confirmar versión con Andrés antes de repetirlo.

El helper del back genera el JWT desde el mismo .env/secreto que PostgREST. Capturarlo solo en memoria:

```powershell
$jwtPlanBot = & .\scripts\token_planificador.ps1
# Entregarlo únicamente al mecanismo de autenticación acordado con César.
# No imprimirlo ni guardarlo en Git, URLs, capturas o logs.
Remove-Variable jwtPlanBot
```

Capturarlo no inicia sesión en el navegador: verificar la entrega con César. Sin token se rechazan decisiones, pero la lectura anónima sigue disponible. Aprobar y aplicar son operaciones distintas; mostrar solo RPC realmente integradas.

## 6. Preparar y repetir la demo

Con pg_dump y release respaldados, schedules pausados y confirmando que .env apunta a **la base de demo**:

```powershell
.\scripts\reiniciar_demo.ps1 -Modo nativo
.\scripts\test.ps1 -Modulo db -Modo nativo
```

El reinicio limpia cargas BUK/dotación/plan/escenarios y versiones de escenarios; conserva parámetros base, esperado y auditoría. Carga 01, recalcula y prepara escenarios. No es una restauración universal ni una operación de producción; no usar durante la exposición ni sobre trabajo activo.

Tener 02/03 en el escritorio y sin entradas/ítems BP de ensayo pendientes. Con 01 cargado, entregar **02_cambios.xlsx** en C:\PlanBot\entrada\buk: copiar a preparar y mover cuando termine. Mostrar Control Room, cinco cambios y Nacional/Actualizar. Consultas: [consultas_demo.sql](../database/demo/consultas_demo.sql), ejecutadas con psql -w y credenciales aprovisionadas.

03 deriva de 01: para comprobar sus cinco errores aisladamente, reiniciar primero a 01. Después de 02 puede revertir cambios. Los mismos bytes deben dar archivo repetido sin nueva carga/recálculo. Seguir [demo](demo.md) y [guion e2e](../tests/e2e/guion.md); observación visual/cola corresponden a Lucas/César. Grabar video antes de presentar.

## 7. Plan B por psql

**Blue Prism es el camino principal**; el script es contingencia. Pausar BP, coordinar ventana y usar la base de demo migrada/con reglas:

```powershell
.\tools\vm\simular_robot.ps1 -Archivo .\data\buk\02_cambios.xlsx -Servidor localhost -Puerto 5432 -Base planbot -EnvArchivo .\.env
```

No mueve archivos ni crea cola BP. Usa los mismos C# de limpieza/validación; carga stg por lotes y llama cargar_dotacion/detectar_cambios/mínimo; recalcula solo si no es NULL y llama cuadratura. Claves del entorno o .env, sin argumentos de contraseña. Catálogos aprobados por consulta READ ONLY del propietario o -Catalogos JSON completo; no dar la clave del propietario al robot. Ante carga parcial, conciliar antes de reintentar. Evidencia y carga_id quedan en TEMP.

```powershell
.\tests\e2e\e2e.ps1
```

Crea **otro cluster/puerto y .env temporal**, nunca recibe la conexión activa. Prueba 01 → snapshot → 02, duplicado y mínimo NULL; usa reiniciar_demo en esa base privada antes de 03. Compara CSV/plan, guarda OK/FALLA por caso y detiene su instancia. Conserva una diferencia explicada de vigencia individual 71555/131 meses 3–4: no declarar toda la suite verde. Ver [progreso](progreso-codex.md), [valores](../tests/e2e/para_andres_71555.csv) y [LEEME](../tests/e2e/LEEME_simulador.md).

## Alternativa con Docker

Requiere Docker Desktop/virtualización y .env con claves/JWT válidos. No ejecutar el lanzador nativo simultáneamente sobre los mismos puertos:

```powershell
docker compose up -d
.\scripts\migrar.ps1 -Modo docker
.\scripts\test.ps1 -Modulo todo -Modo docker
.\scripts\reiniciar_demo.ps1 -Modo docker
```

Compose publica PostgreSQL 5432, PostgREST 3000 y web 8080. Desde Windows usar localhost; entre contenedores, servicio postgres. Detener con docker compose stop; no borrar volúmenes para resolver fallas. Cambiar .env no cambia por sí solo claves de un volumen PostgreSQL existente. El verificador de VM está orientado a la instalación nativa.
