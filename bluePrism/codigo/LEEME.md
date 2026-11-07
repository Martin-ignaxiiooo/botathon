# Código para Lucas · Blue Prism 7.5.1

Estos archivos son referencias compilables con sintaxis compatible con C# 7.3 y .NET Framework 4.7. No son un release importable. Se usan únicamente ADO.NET ODBC y bibliotecas del framework; no instalar Npgsql.

## 1. Preparar ODBC

Instalar psqlODBC **de 64 bits**, controlador Unicode, desde el sitio oficial de PostgreSQL. Abrir **Orígenes de datos ODBC (64 bits)** en Windows, pestaña Controladores, y comprobar `PostgreSQL Unicode(x64)`. Blue Prism Runtime también debe ejecutar a 64 bits. No hace falta un DSN: la conexión usa el nombre del driver. Si el instalador registra otro nombre, copiar exactamente ese nombre.

## 2. Crear los Business Objects

En Object Studio crear `PlanBot_PostgreSQL` y `PlanBot_Archivos_Hash`. En Initialise → Code Options elegir lenguaje **C#**.

- References: `System.dll`, `System.Data.dll`, `System.Xml.dll`.
- Namespace Imports (uno por línea): `System`, `System.Data`, `System.Data.Odbc`, `System.IO`, `System.Security.Cryptography`, `System.Text`, `System.Text.RegularExpressions`.
- En Global Code de PostgreSQL pegar solo el interior de la región `Global Code`, sin `#region`, clase ni `using`. El objeto Hash no necesita Global Code.
- Crear una página por acción, conectar Start → Code → End y publicarla. Pegar en el Code stage **solo el cuerpo** del método correspondiente, excluyendo firma y llaves exteriores. Las firmas del archivo son para probar la compilación fuera de BP.

## 3. Data Items y mapeos del Code stage

En Inputs/Outputs del Code stage usar exactamente estos nombres; mapear cada entrada al Data Item del mismo nombre y cada salida con Store In.

| Acción | Entradas | Salidas |
|---|---|---|
| Ejecutar Consulta | connStr: Text; sql: Text; parametros: Collection con nombre: Text y valor | resultado: Collection |
| Ejecutar Comando | connStr: Text; sql: Text; parametros: Collection con nombre: Text y valor | filasAfectadas: Number |
| Ejecutar Función | connStr: Text; funcion: Text; argumentos: Collection con valor | resultado: Collection |
| Carga Masiva | connStr: Text; tabla: Text; datos: Collection; tamanoLote: Number, inicial 500 | filasInsertadas: Number |
| Calcular Hash | ruta: Text | hash: Text |

Las Collections llegan como DataTable; Number es decimal. Dejar resultado como colección sin campos prefijados para recibir las columnas SQL. `valor` conserva el tipo de la celda: Number → decimal, Flag → bool, Date/DateTime → DateTime, Text → string; null/DBNull → NULL SQL. Una cadena vacía sigue siendo texto vacío. No escribir el texto `NULL`. Para NULL tipado ambiguo usar un cast explícito en SQL (`CAST(? AS date)`, por ejemplo). En colecciones BP de tipo fijo todos los valores de esa columna comparten tipo: separar consultas si se necesitan tipos distintos, o convertir mediante casts explícitos en SQL.

El orden de las filas de parametros/argumentos debe coincidir con los `?`; `nombre` es descriptivo y ODBC lo ignora. No interpolar nunca valores en sql. Ejemplo: `SELECT * FROM api.v_profesional_mes WHERE persona_id = CAST(? AS bigint)`. Una fila de parametros contiene nombre `persona_id`, valor numérico de prueba.

Para funciones usar el esquema desplegado por Andrés (consultar la base, no asumir `api`). Se aceptan identificadores simples `esquema.funcion` o `funcion`. Para Carga Masiva usar columnas SQL exactas del contrato, por ejemplo `stg.buk_fila`, incluyendo `carga_id`; no los encabezados originales del Excel. Solo se aceptan tablas `stg.*`. No se aplica lógica asistencial aquí.

Las excepciones OdbcException se propagan sin reemplazar su mensaje original PostgreSQL. Usar Recover/Resume de BP para registrar la falla sin registrar connStr ni claves. Cada lote se confirma por separado: si falla un lote, los anteriores permanecen cargados; no reintentar todo a ciegas. No se devuelve un contador fiable al salir por excepción. Conciliar la carga antes de reintentar.

## 4. Acción Armar Conexion (sin clave en código)

1. En Credential Manager crear `PlanBot_Postgres` con el usuario `bot_carga` y la clave asignada por el administrador; autorizar el proceso/runtime.
2. Crear variable de entorno BP `ConnStrSinClave` (Text): `Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;`. Es una variable de Blue Prism, no una variable del sistema Windows.
3. Crear acción `Armar Conexion`: leer esa variable en Data Item `baseConexion` y usar **Credentials > Get Login**, credencial `PlanBot_Postgres`, salidas `usuario` (Text), `clave` (Password). Pasarlas al Code stage (clave como Text en su frontera de código); salida `connStr` Text. Pegar:

```csharp
OdbcConnectionStringBuilder constructor = new OdbcConnectionStringBuilder(baseConexion);
constructor["Uid"] = usuario;
constructor["Pwd"] = clave;
connStr = constructor.ConnectionString;
```

El builder escapa claves que contienen `;` o llaves. La cadena resultante equivale a `Driver={PostgreSQL Unicode(x64)};Server=localhost;Port=5432;Database=planbot;Uid=<usuario>;Pwd=<clave>;`. Desactivar el registro de parámetros/etapas sensibles, no mostrar connStr, vaciar clave y connStr al terminar. Nunca guardar secretos en archivos ni en el repositorio.

## 5. Primera prueba

Ejecutar Armar Conexion, luego Ejecutar Consulta con `sql = SELECT 1 AS prueba` y parametros vacía (con sus columnas). Esperar una fila, columna prueba = 1. Ejecutar Check Code en ambos objetos antes de publicar y probar en el Runtime Resource de la demo. Comprobar también una consulta inválida y verificar que Recover conserva el mensaje PostgreSQL.

Para hash, el archivo debe haber terminado de copiarse antes de procesarlo: FileShare.ReadWrite permite lectura mientras otro proceso escribe y, por sí solo, no garantiza un contenido estable. Calcular una vez que tamaño/fecha se estabilicen o mediante renombrado atómico al directorio de entrada.

## 6. Limpiar y validar dotación en memoria

Crear objetos `PlanBot_Limpieza`, `PlanBot_Validador` y `PlanBot_Reglas`. Mantener las References del apartado 2. Añadir Namespace Imports `System.Globalization` y `System.Collections.Generic` (los demás siguen disponibles). Cada archivo contiene su propio Global Code: pegar solo el contenido de su región en el objeto correspondiente y solo el cuerpo del método público en el Code stage. No pegar `using`, firma ni clase. `Probar_CodeStages.cs` es un programa de pruebas y no se pega en BP; Microsoft.VisualBasic se usa solo en ese programa para leer CSV, no en los objetos del robot.

| Acción | Entradas exactas | Salidas exactas |
|---|---|---|
| Limpiar Dotacion | datos: Collection | limpias: Collection; filasDescartadas: Number |
| Validar Dotacion | limpias: Collection; institutos: Collection (it); cargos: Collection (cargo_origen); cargaId: Number | validas: Collection; errores: Collection |
| Transformar Distribucion | rango: Collection | param_cargo: Collection; alertas: Collection |

Dejar las colecciones de salida sin campos prefijados. Leer Dotacion_2026 desde A1 (incluyendo fila vacía) o A2 con Get Worksheet As Collection **sin consumir la primera fila útil como nombres**: el código localiza la cabecera IT/PersonaId/Periodo y sabe que pertenece a la fila 2 del Excel. Así `fila` mantiene el número original aunque se quiten blancos y cabeceras repetidas. También admite encabezados ya convertidos a nombres de columna, pero en ese modo presupone que la primera fila de datos corresponde a la fila 3, sin filas omitidas por el VBO. No usar rangos recortados a mitad de hoja, pues ya no se puede inferir la fila original. filasDescartadas cuenta todos los registros excluidos de datos (incluyendo cabecera inicial y blancos anteriores). datos no se modifica.

Limpiar Dotacion entrega las 16 columnas de `stg.buk_fila` sin carga_id, más `fila`. Descarta Fecha de Nacimiento, Tipo_Trab_161225, Reg_SIC y cualquier columna ajena al contrato. Si falta o se duplica una cabecera requerida, falla antes de cargar. Los tipos originales se conservan hasta validar.

Obtener institutos y cargos desde los catálogos vigentes aprobados por Andrés, con columnas `it` y `cargo_origen`. No validar contra una lista escrita en el código ni contra la propia entrada en producción (eso se usa únicamente como catálogo del ensayo local). La comparación de cargos ignora mayúsculas y espacios exteriores, conserva acentos. Los catálogos vacíos producen una excepción.

Validar Dotacion devuelve una fila por **cada error**, por lo que con_error debe contarse por **filas originales distintas**, no por cantidad de errores. `persona_id` queda NULL en el error cuando no se puede convertir, y `valor` guarda el dato rechazado. Una fila con cualquier error no entra a validas. Se marca como duplicada la segunda y siguientes apariciones de persona_id + it + periodo, incluso si la primera tenía otro error; la primera conserva su propio resultado. Fechas aceptadas: DateTime, serial Excel numérico, ISO yyyy-MM-dd (también hora sin zona) y fecha chilena día/mes/año o día-mes-año. No se infieren fechas de texto numérico. Fecha Ingreso inválida también se informa; Fecha Término, si existe, debe ser **estrictamente posterior**. Los límites 1–45 de horas corresponden a la validación pedida para esta entrada, no al cálculo de la jornada legal. Ndias vacío queda NULL; si se informa debe ser entero int.

validas contiene exactamente las 17 columnas del contrato: carga_id bigint, persona_id bigint, it/ndias int, horas_semanales decimal, fechas en texto ISO yyyy-MM-dd y los demás textos. No contiene `fila`: esa columna solo viaja a errores. Los números son valores .NET, no texto dependiente de la región; al exportarlos usar InvariantCulture para obtener punto decimal. Se acepta coma o punto decimal sin separadores de miles.

**Antes de enviar validas a Carga Masiva**, convertir las tres columnas de fecha ISO a DateTime en una colección auxiliar para que ODBC enlace tipos de fecha en lugar de varchar. Crear un Code stage con entrada `validas` (Collection), salida `datosCarga` (Collection) y pegar este cuerpo; no insertar valores de fecha concatenados en SQL:

```csharp
datosCarga = validas.Clone();
string[] fechasCarga = { "periodo", "fecha_ingreso", "fecha_termino" };
foreach (string campo in fechasCarga) datosCarga.Columns[campo].DataType = typeof(DateTime);
foreach (DataRow origen in validas.Rows)
{
    DataRow destino = datosCarga.NewRow();
    foreach (DataColumn columna in validas.Columns)
    {
        string campo = columna.ColumnName;
        if (Array.IndexOf(fechasCarga, campo) >= 0 && !origen.IsNull(campo))
            destino[campo] = DateTime.ParseExact((string)origen[campo], "yyyy-MM-dd", CultureInfo.InvariantCulture);
        else destino[campo] = origen[campo];
    }
    datosCarga.Rows.Add(destino);
}
```

Cargar datosCarga en `stg.buk_fila` y errores en `stg.error_fila`, ambos con el mismo cargaId. Conservar errores para la cola y el informe de carga. No registrar el Excel entero ni credenciales en Session Logs.

## 7. Transformar Distribucion

Leer **A7:N92** de Distribucion_NAC como 14 columnas posicionales, **sin primera fila como nombres de campo**. A=cod_esp, B=cargo, C=unidad, D/E=minutos; F–H tramo 1, I–K tramo 2, L–N tramo 3. Cada cargo no vacío produce tres filas; vacíos numéricos son 0. Porcentaje numérico de Excel 0.65 permanece 0.65; texto `65%` se convierte a 0.65; texto `65` permanece 65 y genera alerta de suma. Se aceptan coma/punto sin miles. Un texto no numérico o minutos fraccionarios/negativos produce excepción, sin inventar un cero.

alertas incluye cargo, tramo, suma y motivo cuando abs(suma−1) > 0.001. Mostrar y resolver las alertas antes de aprobar reglas. param_cargo no incluye carga_id: añadirlo con el ID de P00 antes de Carga Masiva hacia `stg.param_cargo`. No alterar nombres del contrato ni aplicar reglas nuevas en el robot.

## 8. Pruebas locales

`Probar_CodeStages.cs` permite comprobar los objetos sin BP. Exportar las hojas Dotacion_2026 de `01_original.xlsx` y `03_errores.xlsx` a CSV UTF-8 preservando **todas las filas** desde A1 y las celdas vacías; fechas como yyyy-MM-dd. Los CSV son temporales, no se suben al repositorio. Compilar los tres objetos y el programa con csc, referencias System.Data.dll, System.Xml.dll y Microsoft.VisualBasic.dll (solo lector CSV del ensayo). Ejecutar `prueba.exe original.csv errores.csv data\buk\esperado_errores.csv`.

El ensayo verifica las cinco combinaciones persona/campo del CSV; los motivos son mensajes claros del validador, no textos literales fijados por contrato. También prueba varios errores en una fila, número decimal chileno, NULL, duplicado con fecha DateTime frente a texto ISO, tres tramos y alerta por vacíos. Check Code y la integración ODBC/colas deben probarse además en el Runtime Resource de Lucas; compilar localmente no certifica el release de Blue Prism.
