# PlanBot · Botathon 2026 · Equipo 33

La planificación asistencial en Excel exige cargas y cálculos manuales.<br>
PlanBot recibe reportes BUK sin copiar y pegar.<br>
Valida filas, registra errores y detecta altas, bajas y cambios con vigencia.<br>
PostgreSQL calcula horas, atenciones y metas por persona, instituto y mes.<br>
El dashboard muestra resultados y trazabilidad para «Cada hora cuenta» de Teletón Chile.

La solución tiene tres partes: **Blue Prism 7.5.1** recibe, limpia y valida los archivos; **PostgreSQL 16** conserva reglas versionadas y calcula en SQL, con PostgREST sobre `api`; el **dashboard HTML/JavaScript** muestra Nacional, Instituto, Profesional, Cambios, Parámetros y Cuadratura. No necesita build. La meta inicial es 90 %, parametrizable; % FOJA = horas disponibles para atención directa / horas contratadas. Ver [reglas](docs/reglas.md), [contratos v1.1](docs/contratos.md) y [supuestos del MVP](docs/demo.md#supuestos-del-mvp).

## Levantar la VM Windows

Requisitos: Git, PostgreSQL 16 con cliente psql y servicio activo, psqlODBC Unicode **x64**, Python 3 con openpyxl; Blue Prism 7.5.1 y Runtime Resource con licencia. Los scripts de VM admiten Windows PowerShell 5.1 y PowerShell 7. Se necesita Internet para clonar/descargar PostgREST y permisos de escritura en `C:\tools` y `C:\PlanBot`.

```powershell
git clone https://github.com/Martin-ignaxiiooo/botathon.git C:\dev\botathon
Set-Location C:\dev\botathon
python -m pip install openpyxl
```

**Antes de arrancar**, el administrador debe configurar `PG_SUPER_PASSWORD` en el `.env` local o en el entorno del proceso. Es la clave administrativa de PostgreSQL: sin ella el instalador se detiene. No escribir valores en comandos, capturas ni archivos versionados. Si `.env` no existe, el instalador genera las claves de aplicación y el secreto JWT; si ya existe, completar sus marcadores localmente. Configuración, permisos y diagnóstico independiente: [instalación paso a paso](docs/instalacion.md).

```powershell
.\tools\vm\levantar_demo.ps1
```

El lanzador corre siempre `scripts\instalar_sin_docker.ps1 -SinPruebas`, también tras un `git pull`. Descarga/verifica la versión fijada en [postgrest-version.json](tools/vm/postgrest-version.json), arranca PostgREST y la web ocultos y termina con `verificar_vm.ps1`. No carga BUK por defecto. `-CargarBukPrueba` añade explícitamente una carga inicial y cálculo. Coordinar migraciones/cargas con Lucas y Andrés; usar una base de demo.

- Dashboard real: **http://localhost:8080/?modo=api#nacional**, confirmar «En vivo: base de datos» y pulsar **Actualizar datos** tras una carga.
- API: http://localhost:3000/v_kpi. Un HTTP 200 no demuestra la sesión Blue Prism.
- Diagnóstico: `.\tools\vm\verificar_vm.ps1`, con las variables de conexión/claves importadas según la guía; no importa `.env` por sí solo.
- Detener procesos propios: `.\tools\vm\detener_demo.ps1`. Conserva PostgreSQL, Blue Prism y procesos ajenos.

Con Docker Desktop disponible, usar como alternativa `docker compose up -d`, `.\scripts\migrar.ps1 -Modo docker` y `.\scripts\test.ps1 -Modulo todo -Modo docker`, con `.env` completo. No levantar a la vez Docker y los servicios nativos sobre los mismos puertos; ver [instalación](docs/instalacion.md#alternativa-con-docker).

## Robot y demo

En Blue Prism importar el release de Lucas y ejecutar Check Code. Crear la credencial **PlanBot_Postgres** para `bot_carga` en Credential Manager y la Environment Variable **ConnStrSinClave**, sin usuario ni contraseña. Armar Conexion usa **Credentials > Get Login**. Seguir [LEEME de los objetos](bluePrism/codigo/LEEME.md) y [guía de procesos](bluePrism/codigo/guia_procesos.md); los `.cs` son referencias, no un release importable.

1. Antes del ensayo, con respaldo y sin cargas BP activas, `.\scripts\reiniciar_demo.ps1 -Modo nativo` devuelve **solo la base de demo** al estado 01, calcula plan/cuadratura y prepara escenarios. Borra cargas BUK y escenarios anteriores; no ejecutarlo durante la exposición.
2. Con base 01 lista, Blue Prism recibe `02_cambios.xlsx` en `C:\PlanBot\entrada\buk`; mostrar cola/Control Room, cinco cambios y Nacional actualizado.
3. Ensayar 03 desde una base 01 restaurada: tiene cinco errores intencionales. 03 deriva de 01 y puede revertir 02 si se carga después sin restaurar.
4. Para escenarios, `scripts\token_planificador.ps1` genera el JWT usando el secreto local; capturarlo solo en memoria según la guía, nunca publicarlo ni registrarlo.

El [guion de cinco minutos](docs/demo.md), las [consultas de Andrés](database/demo/consultas_demo.sql) y las [evidencias e2e](tests/e2e/guion.md) indican qué mostrar y guardar. Respaldar PostgreSQL, exportar el release y grabar video antes de presentar.

## Plan B y comprobaciones

**Blue Prism es el camino principal.** El simulador es contingencia por psql, usa los mismos C# de limpieza/validación y no certifica ODBC, Runtime ni cola. Pausar BP antes de usarlo:

```powershell
.\tools\vm\simular_robot.ps1 -Archivo .\data\buk\02_cambios.xlsx -Servidor localhost -Puerto 5432 -Base planbot -EnvArchivo .\.env
.\tests\e2e\e2e.ps1
.\tools\vm\compilar_bp.ps1
```

El e2e crea su propio PostgreSQL/puerto, prueba 01 → 02 y reinicia a 01 con el script del back antes de 03; detiene su instancia. Imprime OK/FALLA y guarda evidencia en TEMP. El chequeo de vigencia individual conserva una diferencia explicada para 71555/131 en marzo–abril; no se presenta como aprobado ni se modifica SQL para ocultarla. Detalle en [progreso](docs/progreso-codex.md) y [LEEME del simulador](tests/e2e/LEEME_simulador.md). La compilación estricta usa las tres referencias BP; Odbc está incluido en System.Data.dll.

## Carpetas y equipo

| Ruta | Contenido |
|---|---|
| `bluePrism\`, `bluePrism\codigo\` | Release de Lucas; fuentes/guías de Code stages |
| `database\`, `api\`, `scripts\` | Back de Andrés: reglas, SQL, PostgREST, instalación y pruebas |
| `web\` | Dashboard de César/Claude Code y dependencias locales |
| `data\excel\`, `data\csv\`, `data\buk\` | Fuentes, CSV extraídos y casos 01/02/03; generador `data\generar_casos.py` |
| `tools\vm\`, `tests\e2e\`, `tests\sql\` | Arranque/contingencia y pruebas |
| `.github\`, `docs\` | CI y documentación |

Equipo 33: Andrés (back), César (front/datos/apoyo) y Lucas (Blue Prism). Claude Code, Codex y ChatGPT apoyan análisis/código/guías; las personas revisan contratos, resultados y ejecución. Ver [uso de IA](docs/uso-ia.md) y [protección de datos](docs/proteccion-datos.md). Usar solo persona_id, sin nombres ni RUT; secretos en Credential Manager y `.env` local excluido de Git. Estado del trabajo: [progreso Codex](docs/progreso-codex.md).
