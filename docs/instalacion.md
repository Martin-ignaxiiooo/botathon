# Instalación de PlanBot en la VM de demo

Objetivo: Windows 11 de 64 bits y Blue Prism 7.5.1. Los scripts de tools\vm funcionan con Windows PowerShell 5.1 y PowerShell 7. Ejecutar desde la raíz salvo indicación. Mantener claves fuera de Git y de los logs. Usar un repositorio integrado con el back de Andrés y el front actualizado; este worktree puede no contener ambos. No sustituir componentes ausentes por esquemas SQL inventados.

## Arranque de demo en un comando (Tarea 11)

Requiere PostgreSQL 16 ya instalado/en ejecución, psql, Python 3, driver psqlODBC x64 y el repositorio integrado con scripts\instalar_sin_docker.ps1 (versión de un comando de Andrés), scripts\servir_web.ps1, SQL y web. El lanzador no instala Blue Prism/PostgreSQL/ODBC ni modifica sus servicios. Coordinar instalación y carga inicial en una base de demo; nunca ejecutar el bootstrap sobre trabajo activo sin acuerdo.

Si falta la base, proporcionar la clave administrativa en memoria, sin escribirla en argumentos o historial:

```powershell
$credencialPg = Get-Credential -UserName postgres -Message 'Administrador PostgreSQL de esta VM'
$env:PG_SUPER_PASSWORD = $credencialPg.GetNetworkCredential().Password
.\tools\vm\levantar_demo.ps1
# Si los componentes están en otro clon integrado:
# .\tools\vm\levantar_demo.ps1 -RaizRepo C:\dev\botathon
```

El lanzador consulta primero pg_database. Solo si confirma ausencia llama al instalador de Andrés; un fallo de conexión no se trata como base ausente. El instalador puede crear .env con claves aleatorias. Si se desea cargar BUK y calcular al crear una base nueva, agregar -CargarBukPrueba; con base existente ese parámetro no recarga datos ni migra. La carga habitual corresponde a Blue Prism. .env se importa en memoria para el arranque y sus valores prevalecen; el entorno previo del llamador se restaura al terminar. No editar .env mientras haya procesos usando sus claves.

Después crea C:\PlanBot\entrada\{planificacion,buk,asignaciones}, procesados, errores, logs, respaldo, preparar y runtime. Busca C:\tools\postgrest.exe; si falta, descarga Windows x64 del [release oficial v16.5](https://github.com/PostgREST/postgrest/releases/tag/v16.5), con comprobación de digest cuando GitHub lo publica. Puede usarse un binario ya instalado o -DirectorioHerramientas con permisos de escritura. No descarga binarios al repositorio.

Crea C:\PlanBot\runtime\postgrest.conf desde api\postgrest.conf, sustituyendo esquema/rol/puerto/CORS y retirando URI/JWT. **La plantilla api aún no está publicada en las referencias revisadas**: en ese caso informa y usa tools\vm\postgrest.conf.example, sin escribir en api\. La clave de web_lectura se pasa al hijo por PGRST_DB_URI en su entorno, escapada como URI; no queda en el conf ni en los argumentos. Solo publica api, escucha 127.0.0.1:3000 y permite origen http://localhost:8080. Ver [configuración oficial de PostgREST](https://docs.postgrest.org/en/stable/references/configuration.html).

PostgREST y scripts\servir_web.ps1 se lanzan ocultos, en segundo plano. El hijo PostgREST recibe la carpeta de psql en PATH para encontrar libpq.dll; el PATH del llamador se restaura. Logs y registro de procesos propios quedan en runtime\. Si 3000/8080 están ocupados, no reinicia ni adopta el proceso ajeno: el verificador comprueba lo que responde y coteja los KPI HTTP con SQL. Abrir **http://localhost:8080/?modo=api#nacional**, confirmar «En vivo: base de datos» y usar «Actualizar datos» después de una carga. Un HTTP 200 no certifica el modo visual ni el recorrido BP. Para ensayos aislados se admiten -PuertoApi/-PuertoWeb; los valores predeterminados son 3000/8080. Cambiar puertos no cambia config.js del front: ese ensayo solo certifica HTTP/SQL, no su conexión visual.

Para diagnóstico independiente, verificar_vm.ps1 es **solo lectura**, no importa .env ni escribe archivos. Usa PG_HOST/PG_PORT/PG_BIN, POSTGRES_DB/POSTGRES_USER y claves del entorno:

```powershell
$env:BOT_CARGA_PASSWORD = (Get-Credential -UserName bot_carga).GetNetworkCredential().Password
$env:WEB_LECTURA_PASSWORD = (Get-Credential -UserName web_lectura).GetNetworkCredential().Password
$env:POSTGRES_PASSWORD = (Get-Credential -UserName owner_planbot).GetNetworkCredential().Password
.\tools\vm\verificar_vm.ps1
.\tools\vm\detener_demo.ps1
```

Las claves nunca se imprimen. El propietario se usa únicamente para contar calc.plan_mes; bot_carga y web_lectura conservan sus permisos. Muestra verde/rojo por carpeta, registro ODBC de 64 bits, puerto PostgreSQL (5432 por defecto), login, ocho funciones contractuales, ocho vistas leídas como web_lectura, plan poblado, JSON/CORS de PostgREST y web PlanBot. Exit 0 exige todo verde; exit 1 deja pendientes explícitos, incluidas funciones opcionales aún no entregadas. No ejecuta RPC. No confundir un rojo por falta de simular/cuadratura con caída del servicio.

detener_demo.ps1 solo detiene procesos registrados por levantar_demo, comparando PID, hora de inicio y ejecutable para evitar PID reutilizado. **No detiene PostgreSQL, Blue Prism ni servicios ajenos**, ni borra datos o claves. Tras un arranque fallido también puede usarse para retirar procesos propios. Limpiar las variables de claves del entorno al terminar el ensayo; para reabrir con claves nuevas, detener/levantar los procesos propios.

## 1. Preparar la VM

Instalar Blue Prism 7.5.1 con su licencia, conexión a su propia base Blue Prism y Runtime Resource operativo. La base **planbot** es distinta de la base interna de Blue Prism. Comprobar `$PSVersionTable.PSVersion`: el arranque tools\vm y los scripts recientes de Andrés admiten 5.1; PowerShell 7 es opcional. Para casos de prueba instalar Python 3 y `python -m pip install openpyxl`.

Elegir Docker o instalación nativa. En VM, Docker requiere virtualización anidada/WSL disponible en el host; si no está habilitada, usar instalación nativa. Requisitos oficiales: [Docker Desktop en Windows](https://docs.docker.com/desktop/setup/install/windows-install/).

## 2. Secretos locales

Si no existe `.env`, ejecutar `Copy-Item .env.example .env`. Editarlo localmente con valores propios para `POSTGRES_DB=planbot`, `POSTGRES_USER=owner_planbot`, `POSTGRES_PASSWORD`, `BOT_CARGA_PASSWORD`, `WEB_LECTURA_PASSWORD` y `PGRST_JWT_SECRET` (al menos 32 caracteres). No conservar los marcadores `cambiar`. `.env` no se versiona y PowerShell no lo importa automáticamente: los scripts/compose deben leerlo según la implementación de Andrés. No usar `Invoke-Expression` para cargar un archivo de configuración.

## 3A. Con Docker

Abrir Docker Desktop, seleccionar contenedores Linux y comprobar `docker compose version`. Revisar que 5432 y 8080 estén libres. Desde el repositorio integrado:

```powershell
docker compose up -d
docker compose ps
docker compose exec postgres pg_isready -U owner_planbot -d planbot
.\scripts\migrar.ps1
.\scripts\test.ps1 -Modulo todo
```

Si el script usa psql del host, instalar el cliente PostgreSQL y añadir su carpeta bin al PATH; revisar `Get-Help .\scripts\migrar.ps1 -Full` antes de definir conexión. Las migraciones/seed son responsabilidad del back y deben terminar sin errores. No borrar volúmenes para solucionar fallas sin respaldo. El rol de inicialización solo toma sus claves del entorno al crear un volumen nuevo: cambiar `.env` no cambia automáticamente las claves de una base existente.

PostgREST y nginx deben levantarse por compose con la configuración integrada de `api\postgrest.conf` y `web\`. Verificar el puerto publicado de PostgREST con `docker compose ps`; si no se publica al host, comprobarlo mediante la ruta proxy configurada en nginx. El robot Windows conecta a `localhost:5432`; entre contenedores el host es el nombre del servicio `postgres`.

## 3B. Sin Docker

Instalar PostgreSQL **16** y sus herramientas de línea de comandos. Durante instalación registrar la clave administrativa localmente, habilitar el servicio y puerto 5432. Añadir `C:\Program Files\PostgreSQL\16\bin` al PATH. Comprobar `psql --version` y `pg_isready -h localhost -p 5432`.

Con el administrador de PostgreSQL, crear el usuario/base de arranque si el instalador del proyecto aún no lo hace (psql pide la clave):

```powershell
psql -h localhost -U postgres -d postgres
```

```sql
-- Una sola vez, si aún no existen. Asignar clave sin escribirla en el historial.
CREATE ROLE owner_planbot LOGIN;
\password owner_planbot
CREATE DATABASE planbot OWNER owner_planbot;
```

Después ejecutar ` .\scripts\instalar_sin_docker.ps1` cuando se haya integrado; revisar su ayuda y permisos necesarios. Si Andrés indica preparación manual, usar ` .\scripts\migrar.ps1` con la conexión indicada por el script y después ` .\scripts\test.ps1 -Modulo todo`. La creación de roles puede requerir un administrador: no dar privilegios permanentes extra a `bot_carga` ni a `web_lectura` para resolverlo. Confirmar que el instalador no repite el bootstrap anterior.

Instalar el binario Windows de PostgREST de la versión acordada con el equipo. Usar `api\postgrest.conf`, exponer solo `api`, rol anónimo `web_lectura` y el rol de conexión definido por Andrés. Proporcionar el URI de conexión desde configuración protegida o `PGRST_DB_URI`; no poner la clave en argumentos de consola ni en un archivo versionado. El rol de conexión debe poder asumir el rol anónimo según el diseño de permisos del back. Ejecutar desde PowerShell:

```powershell
postgrest.exe .\api\postgrest.conf
```

PostgREST usa por defecto el puerto 3000; confirmar el valor real del archivo. Las variables `PGRST_*` prevalecen sobre el archivo de configuración: [referencia oficial](https://docs.postgrest.org/en/stable/references/configuration.html). Servir `web\` por HTTP; para un ensayo local sin nginx:

```powershell
python -m http.server 8080 --bind 127.0.0.1 --directory web
```

Mantener las consolas de PostgREST/servidor estático abiertas durante el ensayo, o configurar servicios con el administrador. Configurar la URL API real y CORS/origen o proxy con el responsable del dashboard. No abrir `index.html` por `file://`: los módulos y fetch necesitan HTTP. No usar el servidor de Python como despliegue público.

## 4. Comprobar la base y la API

```powershell
psql -h localhost -U owner_planbot -d planbot -c 'SELECT count(*) FROM param.cargo_distribucion;'
psql -h localhost -U owner_planbot -d planbot -c 'SELECT * FROM api.v_kpi;'
# Ajustar 3000 si el puerto/ruta publicado es otro.
Invoke-RestMethod 'http://localhost:3000/v_kpi'
```

Los permisos y firmas deben coincidir con `docs\contratos.md`. Una respuesta vacía antes de cargar BUK puede ser válida; un error de esquema/permisos no lo es. Los cálculos se hacen en SQL, no en Blue Prism.

## 5. Instalar psqlODBC y los objetos

Descargar el instalador de **psqlODBC de 64 bits** desde [el proyecto oficial](https://odbc.postgresql.org/). En Windows abrir «Orígenes de datos ODBC (64 bits)» → Controladores; verificar `PostgreSQL Unicode(x64)`. Coincidir arquitectura del controlador y Runtime Resource.

En Blue Prism importar mediante Release Manager el release entregado por Lucas, resolver dependencias y ejecutar Check Code en todos los objetos. Este repositorio entrega código fuente de referencia; no afirmar que los `.cs` son un release BP. Si no hay release, crear los objetos siguiendo `bluePrism\codigo\LEEME.md`, incluyendo Code Options, Data Items y primera prueba `SELECT 1`. Asignar permisos al usuario/runtime que ejecutará el robot.

## 6. Carpetas y configuración del robot

Crear con permisos de lectura/escritura para la cuenta del Runtime Resource:

```powershell
$carpetasPlanBot = @(
  'C:\PlanBot\entrada\planificacion', 'C:\PlanBot\entrada\buk',
  'C:\PlanBot\entrada\asignaciones', 'C:\PlanBot\procesados',
  'C:\PlanBot\errores', 'C:\PlanBot\logs', 'C:\PlanBot\respaldo'
)
$carpetasPlanBot | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
```

Usar estas rutas como acuerdo con Lucas; revisar los nombres exactos de Environment Variables del release antes de configurarlas. No se ha definido un contrato de nombres para las rutas. Si el release usa otras rutas, alinear la configuración, no modificar el código SQL.

En Credential Manager crear **PlanBot_Postgres** para `bot_carga` con la clave real configurada por Andrés; autorizar acceso al proceso/runtime. Crear Environment Variable BP **ConnStrSinClave**:

```text
Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;
```

La acción Armar Conexion usa **Credentials > Get Login** y OdbcConnectionStringBuilder para añadir Uid/Pwd. No guardar claves en Environment Variables, capturas, colas ni logs. Desactivar logging de los Data Items sensibles. Las variables BP son distintas de las variables Windows y de `.env`.

## 7. Carga inicial y Control Room

1. Importar/configurar colas y calendarios requeridos por el release; limpiar solo elementos de ensayo según el procedimiento acordado, conservando trazabilidad.
2. Con Runtime Resource conectado, probar manualmente Armar Conexion → Ejecutar Consulta (`SELECT 1 AS prueba`) antes de programar.
3. Entregar reglas en `entrada\planificacion` y ejecutar **P00**. Verificar carga/versión y conteo de reglas.
4. Entregar BUK en `entrada\buk` y ejecutar el orquestador **P01–P05** del release. Confirmar errores por fila, conteos y actualización del plan.
5. En Control Room → Scheduler crear el schedule de demo, agregar tarea que ejecute el proceso orquestador en el recurso disponible y fijar hora/recurrencia acordadas con Lucas. Evitar ejecuciones solapadas y dos orquestadores procesando el mismo directorio. Verificar permisos y zona horaria America/Santiago de la VM; probar una ejecución y revisar Session Logs.
6. Procesar archivos solo cuando la copia haya terminado; hash con lectura compartida no garantiza estabilidad. Preferir copiar fuera de entrada y renombrar al completar.

## 8. Abrir dashboard y ensayar

Con César configurar `modo: 'api'` y la URL de PostgREST en `web\js\config.js`; no dejar modo mock durante la demo integrada. Abrir `http://localhost:8080`, mostrar Nacional y cotejar SQL. El front se mantiene en la otra carpeta: este trabajo no lo modifica.

Seguir `tests\e2e\guion.md` para original, cambios, errores, duplicado y simulación/aprobación. Los casos D-04 usan enero–julio: cargo desde marzo, alta desde abril, jornada 40 → 30 desde mayo, baja desde junio y traslado desde julio. Guardar dump, exportar release y grabar video antes de la demo. Fallas comunes: driver de arquitectura distinta, puerto ocupado, contraseña del volumen antiguo, URI API incorrecto, privilegios faltantes o proceso agendado en un recurso sin acceso a carpetas/credencial.
