# Instalación de PlanBot en la VM de demo

Objetivo: Windows 11 de 64 bits, PowerShell 7 y Blue Prism 7.5.1. Ejecutar comandos desde la raíz del repositorio salvo que se indique otra ruta. Mantener claves fuera de Git y de los logs. Esta guía describe el despliegue integrado: este clon ya recibió el dashboard del trabajo paralelo, pero aún no incluye SQL, scripts ni compose. Obtener esos componentes de Andrés antes de intentar levantar el sistema. No sustituirlos por esquemas SQL inventados.

## 1. Preparar la VM

Instalar Blue Prism 7.5.1 con su licencia, conexión a su propia base Blue Prism y Runtime Resource operativo. La base **planbot** es distinta de la base interna de Blue Prism. Instalar PowerShell 7 y comprobar `$PSVersionTable.PSVersion`; los comandos deben ejecutarse con `pwsh`, no Windows PowerShell 5.1. Para casos de prueba instalar Python 3 y `python -m pip install openpyxl`.

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
