# César · Codex (GPT Sol, razonamiento alto) — carpeta bothaton-codex

Razonamiento: alto en las tareas 1 y 2; medio en 3, 4 y 5 (`/model`).
Flujo: pega el ARRANQUE una vez; después, para cada tarea nueva en una sesión limpia, "Lee AGENTS.md y docs\progreso-codex.md." + el prompt de la tarea.

## ARRANQUE
Soy César, del equipo 33 de la Botathon 2026 (Teletón Chile, "Cada hora cuenta"). Lee AGENTS.md, docs\contexto.md, docs\contratos.md y docs\reglas.md.
Trabajas en un git worktree (rama codex/trabajo) en paralelo con mi Claude Code (hace web\ en la otra carpeta) y con Andrés (base de datos, otro computador). Tú SOLO modificas: bluePrism\codigo\, data\generar_casos.py, data\buk\, .github\, tests\e2e\, README.md, docs\instalacion.md y docs\progreso-codex.md (créalo). No toques web\, database\, api\, scripts\, AGENTS.md ni otros archivos de docs\.
Entorno: Windows 11, PowerShell 7, rutas con \. Sin GitHub: solo commits locales en codex/trabajo, sin push.
Después de cada tarea: commit (Conventional Commits en español), actualiza docs\progreso-codex.md (Hecho / Siguiente / Errores conocidos) y avísame en 2 líneas. Empieza por la TAREA 1 sin esperar confirmación.

## TAREA 1 · Código C# para Blue Prism (URGENTE)
Crea bluePrism\codigo\PlanBot_PostgreSQL.cs con el código para los code stages de un Business Object de Blue Prism 7.5.1 en C# (.NET Framework 4.7), usando solo System.Data.Odbc. Separa claramente: (a) Global Code (métodos auxiliares: abrir conexión, agregar parámetros posicionales desde un DataTable nombre/valor, convertir tipos); (b) el cuerpo de cada acción tal como se pega en su Code stage, con sus variables de entrada y salida con los nombres exactos de los Data Items:
- Ejecutar Consulta: entradas connStr (Text), sql (Text), parametros (Collection → DataTable con columnas nombre, valor); salida resultado (Collection → DataTable).
- Ejecutar Comando: mismas entradas; salida filasAfectadas (Number).
- Ejecutar Función: entradas connStr, funcion (Text), argumentos (Collection con columna valor); construye "SELECT * FROM <funcion>(?, ?, ...)" validando que funcion solo tenga letras, números, guion bajo y punto; salida resultado (Collection).
- Carga Masiva: entradas connStr, tabla (Text, debe empezar con "stg." y validarse con regex), datos (Collection), tamanoLote (Number, por defecto 500); inserta con INSERT parametrizado usando los nombres de columna del DataTable, en transacciones por lote; salida filasInsertadas (Number).
Reglas: nunca concatenar valores en el SQL; manejar DBNull; lanzar Exception con el mensaje original de PostgreSQL; cerrar conexiones con using.
Crea también bluePrism\codigo\PlanBot_Archivos_Hash.cs: acción Calcular Hash (entrada ruta Text; salida hash Text) con SHA-256 en hexadecimal minúscula, abriendo el archivo con FileShare.ReadWrite.
Y bluePrism\codigo\LEEME.md para un principiante en Blue Prism: instalar psqlODBC de 64 bits y verificarlo en "Orígenes de datos ODBC (64 bits)"; crear cada Business Object; Code Options (References: System.dll, System.Data.dll, System.Xml.dll; Namespace Imports: System, System.Data, System.Data.Odbc, System.IO, System.Security.Cryptography, System.Text, System.Text.RegularExpressions; lenguaje C#); Data Items de cada acción; acción auxiliar "Armar Conexion" que toma usuario y contraseña de Credentials > Get Login (credencial PlanBot_Postgres) y la variable de entorno ConnStrSinClave; cadena: Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;Uid=<usuario>;Pwd=<clave>; y una prueba con SELECT 1. Revisa dos veces que el código compile en C# 7.3 (.NET 4.7): sin características de C# 8 o superior.

## TAREA 2 · Bases de prueba (D-04)
Crea data\generar_casos.py (Python 3, openpyxl), ejecutable con: python data\generar_casos.py. Lee "data\excel\Nac - Base contratos x mes.xlsx", hoja Dotacion_2026 (encabezados en la fila 2, fila 1 vacía, hay filas vacías y un encabezado repetido: respétalos tal cual en la copia). Genera en data\buk\:
- 01_original.xlsx: copia idéntica.
- 02_cambios.xlsx: elige 5 persona_id con 12 meses de datos y aplica: (1) Horas Semanales 40 → 44 desde junio; (2) baja: elimina sus filas desde agosto; (3) alta: persona 999001 desde julio copiando las filas de un KINESIOLOGO de Santiago (IT 131); (4) cambio de Cargo desde septiembre (KINESIOLOGO → TERAPEUTA OCUPACIONAL o similar existente); (5) cambio de IT e Instituto desde octubre.
- 03_errores.xlsx: sobre la base original, horas en 0 en una fila, Fecha Término anterior a Fecha Ingreso en otra, Cargo "CARGO INEXISTENTE", una fila duplicada y el texto "cuarenta" en Horas Semanales.
- esperado_cambios.csv (tipo, persona_id, it, mes_vigencia) con tipos alta, baja, cambio_jornada, cambio_cargo, cambio_it.
- esperado_errores.csv (persona_id, campo, motivo).
Ejecútalo, verifica que los archivos se abren y que esperado_*.csv coincide con lo aplicado. Imprime los persona_id elegidos.

## TAREA 3 · CI (D-06)
Crea .github\workflows\ci.yml (para cuando exista el repositorio): en push y pull_request a main; job en ubuntu-latest con servicio postgres:16 (variables de prueba, healthcheck); instala postgresql-client; con shell pwsh corre .\scripts\migrar.ps1 y .\scripts\test.ps1 -Modulo todo si existen (si no, imprime aviso y sigue); job de lint con Node 20 y ESLint sobre web\js con una configuración mínima en .github\eslint.config.js para módulos ES de navegador. Que el workflow tarde menos de 3 minutos.

## TAREA 4 · Guion de pruebas de punta a punta (D-07)
Crea tests\e2e\guion.md: tabla con Paso, Acción, Resultado esperado, Resultado real, OK. Pasos: (1) dejar la planilla en C:\PlanBot\entrada\planificacion → P00 carga reglas (verificar SELECT count(*) FROM param.cargo_distribucion); (2) dejar data\buk\01_original.xlsx en entrada\buk → P01–P05 cargan y el dashboard Nacional muestra datos; (3) dejar 02_cambios.xlsx → se detectan exactamente las filas de esperado_cambios.csv (consulta a api.v_cambios) y calc.plan_mes cambia solo desde el mes vigente; (4) dejar 03_errores.xlsx → cada fila de esperado_errores.csv aparece en api.v_errores_carga con su motivo; (5) dejar el mismo archivo dos veces → "archivo repetido"; (6) cambiar la meta a 0.85 → simulación y aprobación. Incluye las consultas SQL de verificación y una lista de respaldo previa a la demo (pg_dump, exportar release de Blue Prism, grabar video).

## TAREA 5 · README e instalación (D-08)
README.md: qué es PlanBot (problema y solución en 5 líneas), arquitectura en 3 partes (Blue Prism recibe y valida; PostgreSQL con reglas y cálculo; dashboard), indicadores (meta 90 %, % FOJA), estructura de carpetas, requisitos, instalación con Docker y sin Docker en Windows, cómo correr la demo, equipo y uso de IA. docs\instalacion.md: paso a paso para la VM de la demo (Windows, Blue Prism 7.5.1): instalar PostgreSQL o Docker, psqlODBC, PostgREST, crear .env, migrar, crear carpetas C:\PlanBot\*, importar el release de Blue Prism, crear la credencial PlanBot_Postgres y las variables de entorno, programar el proceso en Control Room y abrir el dashboard.
