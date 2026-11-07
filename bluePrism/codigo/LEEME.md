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
