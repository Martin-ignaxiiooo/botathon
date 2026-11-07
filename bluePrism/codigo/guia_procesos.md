# Construir PlanBot Ciclo BUK · Blue Prism 7.5.1

Guía de construcción, no un release ya importado. Crear cinco procesos con estos nombres: **P01 Recibir BUK**, **P02 Cargar BUK**, **P03-P04 Cambios y Recalculo**, **P05 Cerrar Carga**, **PlanBot Ciclo BUK**. Cada ítem de cola representa un archivo, no una persona. Ejecutar un solo consumidor durante la demo: cargar_dotacion reemplaza la foto completa y dos cargas simultáneas pueden interferirse.

Las acciones C# van en **Object Studio**, nunca en Process Studio. Preparar los cinco BO del [LEEME](LEEME.md), publicar las acciones y ejecutar Check Code. Pegar el cuerpo de cada método sin firma/clase. No se requiere Npgsql. Los .cs usan sintaxis compatible con C# 7.3/.NET 4.7; las pruebas externas no sustituyen Check Code/ODBC en el Runtime.

Fuente de las sentencias ODBC: [database/demo/llamadas_robot.sql](../../database/demo/llamadas_robot.sql), publicada en main por el PR #14 (60fb288), y su ensayo tests/sql/100_llamadas_robot.sql. Usar las sentencias de los comentarios **ODBC:** con `?`, no las variables `:carga_id`/`\gset` de psql ni los valores de ejemplo. La tabla del apartado 7 vincula cada llamada de esta guía con el paso exacto de ese archivo.

## Ruta mínima para la demo · UN proceso «PlanBot - Cargar BUK»

Es el camino más corto para mostrar Blue Prism cargando un BUK: **un solo proceso, sin P04 ni maestro, sin cola**. Todo el código para copiar y pegar está en esta carpeta; esta sección dice qué objeto crear, qué etapa poner y qué pasar. Las sentencias SQL son las de [database/demo/llamadas_robot.sql](../../database/demo/llamadas_robot.sql) (pasos 1 a 9, texto de los comentarios **ODBC:**). Las secciones 1 a 8 de abajo describen la versión completa (P01–P05 + maestro) y siguen vigentes; esta ruta reutiliza sus acciones C# sin cambiar sus nombres de entradas y salidas.

### A. Objetos (Object Studio) y de dónde sale el código

Code Options de todos: Language **C#**. Pegar solo el interior de la región *Global Code* en el Global Code, y solo el **cuerpo** del método (sin firma ni llaves exteriores) en cada Code stage. Cada acción = una página Start → Code → End, publicada. Ejecutar **Check Code** en cada objeto.

| Objeto BP | Archivo | References | Namespaces | Acciones |
|---|---|---|---|---|
| **PlanBot - PostgreSQL** | [PlanBot_Odbc.cs](PlanBot_Odbc.cs) (Global Code + 5 acciones) y, para 3 auxiliares, [PlanBot_PostgreSQL.cs](PlanBot_PostgreSQL.cs) | System.dll, System.Data.dll, System.Xml.dll | System, System.Data, System.Data.Odbc, System.Security, System.Runtime.InteropServices, System.Text, System.Text.RegularExpressions | Conectar, Ejecutar, Consultar, Insertar Tabla, Desconectar (de PlanBot_Odbc.cs) + **Crear Parametros, Leer Numero Resultado, Preparar Carga** (cuerpos de PlanBot_PostgreSQL.cs; no usan Global Code; **no** pegar las demás acciones de ese archivo) |
| **PlanBot - Excel** | [PlanBot_LeerExcel.cs](PlanBot_LeerExcel.cs) | System.dll, System.Data.dll, System.Xml.dll, **System.IO.Compression.dll** | System, System.Collections.Generic, System.Data, System.Globalization, System.IO, System.IO.Compression, System.Xml | Leer Excel |
| PlanBot_Archivos_Hash | [PlanBot_Archivos_Hash.cs](PlanBot_Archivos_Hash.cs) | System.dll | System, System.IO, System.Security.Cryptography | Calcular Hash |
| PlanBot_Limpieza | [PlanBot_Limpieza.cs](PlanBot_Limpieza.cs) | System.dll, System.Data.dll | System, System.Data, System.Globalization, System.Text | Limpiar Dotacion |
| PlanBot_Validador | [PlanBot_Validador.cs](PlanBot_Validador.cs) | System.dll, System.Data.dll | System, System.Data, System.Globalization, System.Collections.Generic | Validar Dotacion |

(El nombre «PlanBot - PostgreSQL» reemplaza al `PlanBot_PostgreSQL` de las secciones 1–8: en esta ruta **no** se usan connStr, Armar Conexion ni la variable ConnStrSinClave.)

**Entradas y salidas de las acciones nuevas** (nombre exacto = Data Item del mismo nombre en la página):

| Acción | Entradas | Salidas |
|---|---|---|
| Conectar | usuario **Text**; clave **Password**; servidor Text; puerto Text; baseDatos Text (los tres últimos vacíos = `localhost`, `5432`, `planbot`) | conectado **Flag** |
| Ejecutar | sql **Text** (con `?`); parametros **Collection** (nombre Text, valor, tipo Text opcional) | filasAfectadas **Number** |
| Consultar | sql **Text** (con `?`); parametros **Collection** | resultado **Collection** (sin campos prefijados); filasResultado **Number** |
| Insertar Tabla | tabla **Text** (`stg.buk_fila` o `stg.error_fila`); datos **Collection**; tamanoLote **Number** (500) | filasInsertadas **Number** |
| Desconectar | — | desconectado **Flag** |
| Leer Excel | ruta **Text**; hoja **Text** | datos **Collection** (sin campos prefijados); filasLeidas **Number** |

Las acciones auxiliares (Crear Parametros, Leer Numero Resultado, Preparar Carga, Calcular Hash, Limpiar Dotacion, Validar Dotacion) conservan las entradas/salidas de la tabla del [LEEME](LEEME.md).

**Cómo se maneja la clave (tipo Password).** Nunca se escribe en un Data Item Text, en un archivo ni en el código.
1. Credential Manager: credencial **PlanBot_Postgres**, usuario `bot_carga`, clave asignada por el administrador; autorizar el proceso «PlanBot - Cargar BUK» y el Runtime Resource.
2. En el proceso: etapa **Credentials › Get Login** (credencial `PlanBot_Postgres`) → `usuario` (Text) y `clave` (**Password**). Crear `clave` como Data Item de tipo Password, con *Exponer globalmente* desactivado.
3. Pasar `clave` a la acción Conectar con **tipo Password** en su input. En el Code stage de Conectar declarar `clave` de tipo Password (Blue Prism lo entrega como `SecureString`; el método `TextoClave` del Global Code la convierte en memoria, la usa solo para armar la conexión dentro de Conectar y libera el búfer; si alguien la declara Text también funciona). La cadena de conexión **nunca** sale de Conectar: las demás acciones usan la conexión abierta que guarda el objeto.
4. Apagar el logging de las etapas Get Login y Conectar (Stage Properties → *Log: Disabled*) y de todo Data Item con `clave`. Los mensajes de error de Conectar solo incluyen el texto del driver, sin la clave ni la cadena.
5. Cerrar siempre con Desconectar (también en la página Error). Al terminar, vaciar `clave` y `usuario` (Calculation `""`).

### B. Excel en la VM: cómo se lee

La VM tiene Python 3.12 con openpyxl, pero **no se sabe si tiene Excel**, y el robot no debe depender de ninguno de los dos. Por eso la ruta usa **Leer Excel** (`PlanBot_LeerExcel.cs`): lee el `.xlsx` directamente con bibliotecas del framework (el archivo es un ZIP con XML), sin Excel, sin Python y sin COM. Probado contra `01_original.xlsx` y `03_errores.xlsx`: entrega la hoja desde A1 (4.003 filas, 20 columnas; la fila 1 vacía y la cabecera en la fila 2, como espera Limpiar Dotacion). Con `01` → 3.123 filas limpias, 3.123 válidas, 0 errores; con `03` → 3.124 leídas y errores con su fila Excel. Los números y fechas llegan como double (una fecha de Excel es un serial; Validar Dotacion lo convierte a fecha).
- **Si en la VM hay Excel**, también sirve el MS Excel VBO (etapas 1–5 de P02, sección 4) en lugar de Leer Excel. Es una alternativa, no un requisito.
- **No usar** `scripts\buk_a_csv.py` ni `openpyxl` en el robot: son herramientas de prueba del repositorio.
- La hoja se llama `Dotacion_2026` (en los tres archivos de `data\buk`).

### C. Proceso «PlanBot - Cargar BUK»

Páginas **Main** y **Error**. Main: Start → Block *Trabajo* (todas las etapas) → End; Recover del bloque → página Error. Colecciones sin campos prefijados y sin datos entre ejecuciones.

**Start (inputs):** `ruta` Text (archivo ya completo, p. ej. `C:\PlanBot\entrada\buk\02_cambios.xlsx`); `institutos` Collection (campo `it` Number) y `cargos` Collection (campo `cargo_origen` Text), los catálogos aprobados de la sección 1 punto 5 (filas en *Initial Values*; no derivarlos del archivo).
**End (outputs):** `cargaId` Number; `leidas`, `filasValidas`, `filasConError` Number; `mesMinimo` Number; `recalculado` Flag.

**Data Items locales:** `usuario` Text; `clave` Password; `hash` Text; `cargaId` Number=0; `datosExcel`, `limpias`, `validas`, `errores`, `datosCarga`, `parametros`, `resultado` Collection; `filasLeidas`, `filasDescartadas`, `filasResultado`, `insertadas`, `filasCore`, `alertas`, `leidas`, `filasValidas`, `filasConError`, `mensajesError`, `mesMinimo`, `leidasBD`, `validasBD`, `conErrorBD` Number=0; `esNulo`, `conectado`, `desconectado`, `recalculado` Flag=False; `estadoBD`, `errorTipo`, `errorDetalle` Text="". Atajos: **P(modo; valores)** = acción *Crear Parametros* (los 8 inputs siempre: modo; texto1/texto2 = "" y numero1..4 = 0 salvo los indicados) → `parametros`; **L(columna→item)** = acción *Leer Numero Resultado* (resultado=[resultado], columna → numero=[item], esNulo=[esNulo], filasResultado=[filasResultado]).

| # | Etapa | Objeto / acción (o tipo) | Qué le pasas → qué sale |
|---|---|---|---|
| 1 | Credencial | Credentials › Get Login | credencial `PlanBot_Postgres` → `usuario`, `clave` (Password) |
| 2 | Conectar | PlanBot - PostgreSQL / Conectar | usuario=[usuario], clave=[clave], servidor="", puerto="", baseDatos="" → conectado |
| 3 | Huella | PlanBot_Archivos_Hash / Calcular Hash | ruta=[ruta] → hash |
| 4 | ¿Duplicado? | P(T1; texto1=[hash]) y PlanBot - PostgreSQL / Consultar | sql: `SELECT carga_id FROM stg.carga WHERE hash = ?` → resultado, filasResultado. Decision [filasResultado]>0 → Exception «Archivo ya cargado (hash repetido); no se vuelve a procesar» (paso 1 de llamadas_robot.sql) |
| 5 | Registrar carga | P(T2; texto1=nombre del archivo, texto2=[hash]) y Consultar | sql: `INSERT INTO stg.carga (tipo, archivo, hash, estado) VALUES ('buk', ?, ?, 'recibida') ON CONFLICT (hash) DO NOTHING RETURNING carga_id`. Si `filasResultado`=0 → Exception «Otro proceso registró este archivo». Si no, L(carga_id→cargaId). El nombre del archivo es `ruta` sin la carpeta (Calculation: `Right([ruta], Len([ruta]) - InStrRev([ruta], "\"))`). Paso 2 |
| 6 | Leer el Excel | PlanBot - Excel / Leer Excel | ruta=[ruta], hoja="Dotacion_2026" → datosExcel, filasLeidas (ver B) |
| 7 | Limpiar | PlanBot_Limpieza / Limpiar Dotacion | datos=[datosExcel] → limpias, filasDescartadas |
| 8 | Validar | PlanBot_Validador / Validar Dotacion | limpias, institutos, cargos, cargaId → validas, errores |
| 9 | Tipar y contar | PlanBot - PostgreSQL / Preparar Carga | validas, limpias, errores → datosCarga, leidas, filasValidas, filasConError, mensajesError (las fechas quedan DateTime) |
| 10 | Guardar errores | PlanBot - PostgreSQL / Insertar Tabla | tabla="stg.error_fila", datos=[errores], tamanoLote=500 → insertadas. Omitir con Decision [mensajesError]=0. Paso 4 |
| 11 | ¿Hay válidas? | Decision | [filasValidas]>0; si no, Exception «Sin filas válidas; no se reemplaza la dotación» |
| 12 | Guardar válidas | PlanBot - PostgreSQL / Insertar Tabla | tabla="stg.buk_fila", datos=[datosCarga], tamanoLote=500 → insertadas. Paso 3 (`datosCarga` ya incluye `carga_id`) |
| 13 | **api.cargar_dotacion** | P(N1; numero1=[cargaId]) y Consultar | sql: `SELECT * FROM api.cargar_dotacion(CAST(? AS bigint))`. L(filas→filasCore) y L(alertas→alertas). Paso 5 |
| 14 | **api.mes_minimo_afectado** | P(N1; numero1=[cargaId]) y Consultar | sql: `SELECT api.mes_minimo_afectado(CAST(? AS bigint)) AS mes_minimo`. L(mes_minimo→mesMinimo) deja `esNulo` en True si es NULL (sin cambios). Paso 6 |
| 15 | ¿Recalcular? | Decision | [esNulo]=False → etapa 16; True → saltar a 17 (`recalculado`=False). **Nunca** llamar recalcular con NULL ni con 0 |
| 16 | **api.recalcular** | P(N2; numero1=[cargaId], numero2=[mesMinimo]) y Consultar | sql (una sola sentencia; el motivo queda en la auditoría): `WITH contexto AS MATERIALIZED (SELECT set_config('planbot.motivo', 'PlanBot Cargar BUK; carga=' || CAST(CAST(? AS bigint) AS text), true) AS motivo) SELECT r.filas, r.ms FROM contexto c CROSS JOIN LATERAL api.recalcular(CASE WHEN c.motivo IS NOT NULL THEN CAST(? AS integer) END) r`. Calculation `recalculado`=True. Paso 7 |
| 17 | Conciliar contadores | P(N1; numero1=[cargaId]) y Consultar | sql: `SELECT leidas, validas, con_error, estado FROM stg.carga WHERE carga_id = CAST(? AS bigint)`. L(leidas→leidasBD), L(validas→validasBD), L(con_error→conErrorBD) (exigir una fila y números no NULL); Calculation `estadoBD`=[resultado.estado]. Paso 5 |
| 18 | ¿Cuadran? | Decision | `estadoBD`="cargada" **y** leidasBD=[leidas] **y** validasBD=[filasValidas] **y** conErrorBD=[filasConError]. Si no → Exception «BD y BP difieren: conciliar la carga [cargaId]» (no corregir por UPDATE) |
| 19 | Desconectar | PlanBot - PostgreSQL / Desconectar | → desconectado. Luego Calculation `clave`="" y `usuario`="" → End |

Notas de datos: Number de BP llega a PostgreSQL como decimal; por eso **siempre** `CAST(? AS bigint)` / `CAST(? AS integer)` en las llamadas a funciones (sin CAST responde «la función no existe»). Los INSERT de Insertar Tabla no necesitan CAST. Las fechas de `stg.buk_fila` salen como **OdbcType.Date** (también `fecha_termino` vacía como DBNull); Insertar Tabla rechaza una columna de fecha que no sea DateTime antes de abrir el primer lote, por eso se pasa `datosCarga` y no `validas`. Las filas rechazadas van a `stg.error_fila` con el motivo del Validador (sin el prefijo `cargar_dotacion:`, que es de la base).

**Página Error (Recover del bloque *Trabajo*):** (1) captura ExceptionType()/ExceptionDetail() en `errorTipo`/`errorDetalle` (logging desactivado); (2) si `cargaId`>0 y `conectado`=True, **marcar error** con *Ejecutar* (en un Recover propio): P(N1; numero1=[cargaId]) y sql `UPDATE stg.carga SET estado = 'error' WHERE carga_id = CAST(? AS bigint)` (paso 9; el robot solo puede cambiar `estado`; los contadores no se tocan); (3) **Desconectar** (otro Recover propio, también si falló la conexión); (4) Resume y Exception con los valores capturados. No repetir las etapas 10–16 automáticamente: puede haber lotes confirmados (cada lote de 500 filas es una transacción). Conciliar con Andrés antes de reintentar.

**Primera prueba (antes del BUK):** etapas 1–2 + Consultar `SELECT 1 AS prueba` (parametros vacía, con sus columnas nombre y valor) + Desconectar: una fila con `prueba`=1. Después, el **ensayo de una fila** (periodo/fecha_ingreso DateTime y fecha_termino vacía) descrito en la sección 6 antes de los lotes completos. **No certificado:** este PC no tiene el driver *PostgreSQL Unicode(x64)*, así que `PlanBot_Odbc.cs` está compilado (csc de .NET Framework 4.x, C# 5) pero no probado contra la base real; la lectura de Excel, la limpieza, la validación y el tipado de fechas sí se probaron con los archivos de `data\buk`.

## 1. Preparación común

1. Confirmar las cinco RPC en api: cargar_parametros, cargar_dotacion, detectar_cambios, mes_minimo_afectado y recalcular. El mínimo es NULL cuando no hay cambios; la primera carga pide mes 1. No llamar funciones sin api ni inventar funciones nuevas. Confirmar también V009 para Q09: el robot puede marcar estado='error'; los contadores los deja cargar_dotacion y **no se actualizan desde BP**.
2. Configurar credencial **PlanBot_Postgres**, usuario bot_carga, y Environment Variable **ConnStrSinClave** como indica LEEME. La acción PlanBot_PostgreSQL → Armar Conexion obtiene usuario/clave con Credentials → Get Login. Desactivar logging de clave, connStr, parámetros sensibles y Excel crudo; no incluirlos en la cola ni en una Exception.
3. Crear carpetas entrada\buk, preparar, procesados y errores bajo C:\PlanBot. Completar la copia en preparar y después moverla a entrada\buk; no encolar un archivo en copia. Cerrar Excel antes de mover el archivo procesado.
4. Crear Work Queue **PlanBot_BUK**, clave ruta, sin reintentos automáticos. Un schedule ejecuta solo el maestro; no programar además P01/P02/P03/P05. P00 carga reglas previamente usando PlanBot_Reglas → Transformar Distribucion, añade carga_id y usa Carga Masiva + api.cargar_parametros; no repetir P00 por cada BUK.
5. Catálogos: **bot_carga no puede consultar param.instituto ni param.cargo_homologado** en las migraciones revisadas. Andrés ejecuta una vez estas exportaciones como owner_planbot. Lucas crea las colecciones iniciales institutos y cargos del maestro, añade una fila por registro exportado en Initial Values y las pasa a P02. Renovarlas si cambia el catálogo; no derivarlas del archivo entrante ni dar al robot la clave del propietario.

```sql
\copy (SELECT it FROM param.instituto ORDER BY it) TO 'C:/PlanBot/respaldo/catalogo_institutos.csv' CSV HEADER
\copy (SELECT cargo_origen FROM param.cargo_homologado ORDER BY cargo_origen) TO 'C:/PlanBot/respaldo/catalogo_cargos.csv' CSV HEADER
```

Es una configuración manual explícita del MVP (16 institutos y 15 cargos en el seed revisado); no hay RPC de catálogos contratada. Si faltan colecciones aprobadas, detener la construcción antes de P02, sin sustituirlas por los valores de BUK.

Crear también las acciones auxiliares del mismo BO PlanBot_PostgreSQL, desde los métodos nuevos de PlanBot_PostgreSQL.cs:

| Acción | Entradas exactas | Salidas exactas |
|---|---|---|
| Crear Parametros | modo Text; texto1/texto2 Text; numero1/numero2/numero3/numero4 Number | parametros Collection |
| Leer Numero Resultado | resultado Collection; columna Text | numero Number; esNulo Flag; filasResultado Number |
| Preparar Carga | validas/limpias/errores Collection | datosCarga Collection; leidas/filasValidas/filasConError/mensajesError Number |

Crear PlanBot_Archivos_Hash → **Mover Archivo**, cuerpo MoverArchivo: ruta Text, carpeta Text, cargaId Number → rutaDestino Text. Añadir System.Data solo al BO PostgreSQL (ya requerido); Hash conserva sus referencias del LEEME. No cambiar nombres de entradas/salidas de las acciones anteriores.

## 2. Convenciones de páginas, parámetros y colecciones

En cada proceso crear **Main** y **Error**. En Main: Start → Block Trabajo (todas las etapas normales) → End. Crear Recover asociado a ese bloque, conectado a la página Error. Error captura ExceptionType()/ExceptionDetail() en errorTipo/errorDetalle Text (inicial "", logging desactivado), hace la limpieza indicada, Resume y Exception con los valores capturados. Si la limpieza falla, un bloque Recover/Resume separado conserva la excepción original. El maestro registra solo un mensaje operativo sin credenciales.

Todas las tablas siguientes son el orden de enlaces de la rama normal. «Proceso» es un Process stage; «Acción» un Action stage. Para asignaciones simples usar Calculation o Multi Calculation. Los nombres a la izquierda son Data Items; constantes Text llevan comillas en el editor BP. Los resultados dinámicos deben ser Collections **sin campos prefijados**. Contadores Number inicial 0; Flag inicial False; Text inicial "" salvo que se indique otro valor. Desactivar exposición global de datos sensibles.

**P(modo; valores)** significa una etapa Acción *PlanBot_PostgreSQL / Crear Parametros*. Mapear siempre los ocho inputs: modo indicado; texto1/texto2="" y numero1..4=0 salvo los valores enumerados en orden. Guardar salida en parametros. T1 usa texto1; T2 texto1/texto2; N1 numero1; N2 numero1/numero2; N4 numero1..4. El BO construye filas posicionales nombre/valor, con tipo Text o Number homogéneo. No construir SQL concatenando Data Items ni añadir comillas alrededor de ?.

**Q(nn)** significa Acción *PlanBot_PostgreSQL / Ejecutar Consulta*: connStr=[connStr], sql=texto Qnn del apartado 7, parametros=[parametros], resultado→[resultado]. Para Q09 usar *Ejecutar Comando*, mismos inputs y filasAfectadas→[filasAfectadas]. El antiguo UPDATE Q08 está retirado. **L(columna→item)** significa Acción *Leer Numero Resultado*: resultado=[resultado], columna literal → numero=[item], esNulo=[esNulo], filasResultado=[filasResultado]. Estos atajos son etapas distintas, no un BO ficticio.

| Collection | Campos y tipos exactos | Inicial |
|---|---|---|
| parametros | nombre Text; valor Text para T*, Number para N* | Dinámica, sustituida en cada P |
| resultado, datosExcel, limpias, validas, errores, datosCarga, cambios | Forma de la acción que las devuelve | Sin esquema inicial |
| institutos | it Number | Filas aprobadas del catálogo |
| cargos | cargo_origen Text | Filas aprobadas del catálogo |
| archivosPrueba, datosItem | ruta Text | archivosPrueba: una fila C:\PlanBot\entrada\buk\01_original.xlsx; datosItem: vacía |

limpias: it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp; más fila Number. Conserva los valores originales para validar. validas/datosCarga: **carga_id + los 16 campos anteriores, sin fila**. Números .NET: carga_id/persona_id bigint, it/ndias int, horas_semanales decimal; otros Text salvo las tres fechas: validas entrega DateTime sin hora; Preparar Carga conserva DateTime en datosCarga (convierte ISO heredado si es necesario). errores: carga_id Number, fila Number, persona_id Number nullable, campo/valor/motivo Text. Un DBNull real no es el texto "NULL".

## 3. P01 Recibir BUK

Start inputs: ruta Text, connStr Text. End outputs: cargaId Number, duplicado Flag. Items locales: hash Text; parametros/resultado Collection; esNulo Flag; filasResultado Number; errorTipo/errorDetalle Text. cargaId=0, duplicado=False en cada inicio.

| Orden / etapa | Tipo, objeto y acción | Entradas → salidas / enlace |
|---|---|---|
| 1 Huella | Acción PlanBot_Archivos_Hash / Calcular Hash | ruta→hash |
| 2 Parámetros buscar | P(T1; hash) | texto1=[hash] |
| 3 Buscar huella | Q01 | resultado dinámico |
| 4 Leer ID | L(carga_id→cargaId) | filasResultado=0: ir a 6; >0: ir a 5 |
| 5 Duplicado | Calculation | duplicado=True → End; no crea ni carga datos |
| 6 Parámetros alta | P(T2; ruta, hash) | texto1=[ruta], texto2=[hash] |
| 7 Registrar | Q02 | INSERT RETURNING; conserva ruta como nombre identificable de archivo |
| 8 Leer ID nuevo | L(carga_id→cargaId) | Una fila: End. Cero filas: otra sesión registró el hash → repetir 2–5 una vez |

Error: ninguna reconexión/reintento de INSERT a ciegas. Si cargaId>0, el maestro puede marcar error; si no llegó el ID, conservar hash/ruta para conciliación. La restricción UNIQUE(hash) y ON CONFLICT cubren la carrera entre búsqueda y alta. Un hash de carga fallida también es repetido: no se elimina para forzar otra ejecución.

## 4. P02 Cargar BUK

Start: ruta Text, connStr Text, cargaId Number, institutos/cargos Collection. End: leidas, filasValidas, filasConError, mensajesError Number. Locales: handle Number=0; libro Text=""; excelAbierto/libroAbierto Flag=False; filasDescartadas/insertadas/filasCore/alertas/filasResultado Number=0; esNulo Flag=False; colecciones de apartado 2; errorTipo/errorDetalle Text; leidasBD/validasBD/conErrorBD Number=0; estadoBD Text="". No conservar datos entre archivos.

| Orden / etapa | Tipo, objeto y acción | Entradas → salidas / enlace |
|---|---|---|
| 1 Excel propio | Acción MS Excel VBO / Create Instance | handle→handle; no conectar a Excel del usuario |
| 1b Instancia creada | Calculation | excelAbierto=True antes de intentar Open Workbook |
| 2 Abrir | Acción MS Excel VBO / Open Workbook | handle=[handle], Filename=[ruta] → Workbook Name=[libro] |
| 2b Libro abierto | Calculation | libroAbierto=True |
| 3 Leer hoja | Acción MS Excel VBO / Get Worksheet As Collection | handle, Workbook Name=[libro], Worksheet Name="Dotacion_2026" → Collection=[datosExcel] |
| 4 Cerrar libro | Acción MS Excel VBO / Close Workbook | handle, Workbook Name=[libro], Save=False |
| 4b Libro cerrado | Calculation | libroAbierto=False |
| 5 Cerrar instancia | Acción MS Excel VBO / Close Instance | handle; excelAbierto=False |
| 6 Limpiar | Acción PlanBot_Limpieza / Limpiar Dotacion | datos=[datosExcel] → limpias, filasDescartadas |
| 7 Validar | Acción PlanBot_Validador / Validar Dotacion | limpias, institutos, cargos, cargaId → validas, errores |
| 8 Tipar/contar | Acción PlanBot_PostgreSQL / Preparar Carga | validas, limpias, errores → datosCarga, leidas, filasValidas, filasConError, mensajesError |
| 9 Guardar errores | Acción PlanBot_PostgreSQL / Carga Masiva | connStr, tabla="stg.error_fila", datos=[errores], tamanoLote=500 → insertadas; INSERT del paso 4 de llamadas_robot.sql, motivo sin prefijo cargar_dotacion: |
| 10 Hay válidas | Decision | filasValidas>0: seguir; False: Exception «Sin filas válidas; no reemplazar dotación» |
| 11 Guardar válidas | Acción PlanBot_PostgreSQL / Carga Masiva | connStr, tabla="stg.buk_fila", datos=[datosCarga], tamanoLote=500 → insertadas; INSERT del paso 3 de llamadas_robot.sql |
| 12 ID para cargar | P(N1; cargaId) | numero1=[cargaId] |
| 13 Cargar core | Q03 | RPC real cargar_dotacion |
| 14 Leer respuesta | L(filas→filasCore), luego L(alertas→alertas) | Dos Action stages; filasCore incluye proyección y **no** es filasValidas |
| 15 Leer cierre BD | P(N1; cargaId), Q04 | SELECT de contadores del paso 5; no UPDATE |
| 16 Leer campos | L(leidas→leidasBD), L(validas→validasBD), L(con_error→conErrorBD); Calculation estadoBD=[resultado.estado] | Exigir una fila y números no NULL en cada lectura |
| 17 Conciliar | Decision | Exigir estadoBD="cargada", leidasBD=leidas, validasBD=filasValidas, conErrorBD=filasConError; si difiere, Exception «BD y BP difieren: conciliar carga»; si coincide, End |

La lectura debe conservar la cabecera Excel de fila 2 en datosExcel (o en sus nombres de columna). No quitar filas antes de Limpiar Dotacion: se perdería fila original. Si el VBO dispone de Use Header, dejar False para conservar cabecera; si no, comprobar que datosExcel contiene IT/PersonaId/Periodo en la fila útil. Preferir valores Value/Value2, no Text formateado. Las etiquetas/inputs del VBO pueden variar con la versión importada: comprobarlos en Object Studio antes de mapear; no existe un VBO universal pegable en este repo. Referencia primaria: [MS Excel VBO User Guide](https://community.blueprism.com/hfgie69872/attachments/hfgie69872/digital-exchange/4467/1/Excel%20Guide.pdf).

Error: si libroAbierto=True intentar Close Workbook; si excelAbierto=True intentar Close Instance, incluso cuando falló Open Workbook. Proteger cada cierre con su propio Recover/Resume para que el fallo al cerrar el libro no impida cerrar la instancia. Solo se cierra el handle propio; conservar y reemitir el error original. Puede haber lotes confirmados. No volver a ejecutar 9–13 automáticamente; no tiene DELETE el robot. Los contadores se leen del back; no se corrigen por UPDATE. Si varios mensajes BP comparten fila y los conteos del back no coinciden con los de Preparar Carga, parar y conciliar. Si hay rechazos adicionales de BD, no inventar una correspondencia entre su fila reenumerada y fila original BP; parar antes del recálculo y conciliar/restaurar con Andrés.

## 5. P03-P04 Cambios y Recalculo

Start: cargaId Number, connStr Text. End: huboRecalculo Flag=False, mesMinimo Number=0, filasPlan/ms Number=0, cambios Collection. Locales: parametros/resultado Collection, esNulo Flag, filasResultado Number, errorTipo/errorDetalle Text. Crear además página **Recalcular**, llamada solo desde Main cuando procede.

| Orden / etapa | Tipo, objeto y acción | Entradas → salidas / enlace |
|---|---|---|
| 1 ID detectar | P(N1; cargaId) | numero1=[cargaId] |
| 2 Detectar | Q05 | Guardar la salida resultado directamente en cambios (sin Calculation); no contar filas como cambio temporal mínimo |
| 3 ID mínimo | P(N1; cargaId) | misma carga |
| 4 Consultar corte | Q06 | resultado de una fila, campo mes_minimo |
| 5 Leer NULL | L(mes_minimo→mesMinimo) | Guardar esNulo; no usar mesMinimo=0 como ausencia |
| 6 ¿Sin cambios? | Decision | esNulo=True → End con huboRecalculo=False; False → validar 1<=mesMinimo<=12 y llamar página Recalcular |
| R1 Contexto y mes | P(N2; cargaId, mesMinimo) | Dos números: primero carga, después mes |
| R2 Recalcular auditado | Q07 | Una sola consulta/conexión: motivo local + api.recalcular |
| R3 Respuesta | L(filas→filasPlan), L(ms→ms) | huboRecalculo=True → fin de página → End |

Error: detener el archivo y propagar. api.recalcular es transaccional para el recálculo, no para todos los lotes de P02. Q07 evita depender de que dos acciones reutilicen la misma conexión del pool. No hacer set_config en una acción separada. No llamar recalcular(NULL) ni recalcular(0).

## 6. P05 Cerrar Carga y maestro

**P05** Start: connStr Text, cargaId/leidas/filasValidas/filasConError/mensajesError Number. End sin datos sensibles. Locales resultado/parametros Collection; leidasBD/validasBD/conErrorBD/filasResultado Number=0; estadoBD Text=""; esNulo Flag=False; errorTipo/errorDetalle Text.

| Orden | Tipo, objeto y acción | Mapeo |
|---|---|---|
| 1 Leer cierre | P(N1; cargaId), Q04 | SELECT leidas/validas/con_error/estado del paso 5 de llamadas_robot.sql |
| 2 Leer contadores | L(leidas→leidasBD), L(validas→validasBD), L(con_error→conErrorBD) | Exigir filasResultado=1 y esNulo=False en cada lectura |
| 3 Leer estado | Calculation | estadoBD=[resultado.estado], única fila |
| 4 Conciliar | Decision | estadoBD="cargada", leidasBD=leidas, validasBD=filasValidas, conErrorBD=filasConError y leidas=filasValidas+filasConError; si difiere, Exception y conciliación con Andrés |
| 5 End | End | No UPDATE ni Q08; solo después de confirmar cierre BD el maestro mueve archivo y completa cola |

cargar_dotacion ya deja estado y contadores (incluye los rechazos de la base). P05 **solo los lee y concilia** con los datos de BP; no usa filasCore proyectadas como válidas ni mensajesError como filas con error. Se conservan los inputs de P05 para compatibilidad con el maestro; mensajesError es informativo. Si la BD agrega rechazos o cuenta distinto una fila con varios errores, detener y conciliar sin sobrescribir sus datos. **Q08 no va**: eliminar la etapa anterior de UPDATE, no dejarla desconectada como alternativa. Error: propagar y no declarar la carga finalizada.

**Maestro PlanBot Ciclo BUK**. Páginas exactas: Main, Encolar Prueba, Archivo, Error. Colecciones institutos/cargos aprobadas, archivosPrueba/datosItem según apartado 2. Items: cola Text="PlanBot_BUK"; encolarPrueba Flag=False; itemId Text=""; status Text=""; attempts Number=0; ruta Text=""; connStr Text="" (logging off); cargaId Number=0; duplicado/cargaCreada/bdConfirmada Flag=False; leidas/filasValidas/filasConError/mensajesError/mesMinimo/filasPlan/ms Number=0; huboRecalculo Flag=False; rutaDestino Text=""; errorTipo/errorDetalle Text=""; parametros/resultado Collection; filasAfectadas Number=0. Entrada de Start opcional: encolarPrueba Flag. No hay código C# en estas páginas.

| Orden/página | Tipo, objeto y acción | Mapeo y siguiente etapa |
|---|---|---|
| M1 Main | Start → Decision encolarPrueba | True: Encolar Prueba; False: M2 |
| E1 Encolar Prueba | Acción interno Work Queues / Add To Queue | Queue Name=[cola], Data=[archivosPrueba]; resto opcional por defecto. Solo para ensayo manual, una fila ya copiada por completo → M2 |
| M2 Main | Acción PlanBot_PostgreSQL / Armar Conexion | connStr→connStr; nunca salida al log |
| M3 Main | Calculation | itemId="" antes de cada adquisición, también en vueltas del bucle |
| M3b Main | Acción interno Work Queues / Get Next Item | Queue Name=[cola], filtros vacíos → Item ID=[itemId], Data=[datosItem], Status=[status], Attempts=[attempts] |
| M4 Main | Decision itemId<>"" | False: borrar connStr y End. True: página Archivo |
| A1 Archivo | Multi Calculation | ruta=[datosItem.ruta]; cargaId=0; cargaCreada=False; bdConfirmada=False; contadores=0; duplicado=False |
| A2 Archivo | Proceso P01 Recibir BUK | ruta, connStr → cargaId, duplicado |
| A3 Archivo | Decision duplicado | True: Update Status «archivo repetido; revisar carga previa», Mover Archivo a C:\PlanBot\errores y Mark Exception sin retry; volver M3. No cambia BD. False: cargaCreada=True → A4 |
| A4 Archivo | Proceso P02 Cargar BUK | ruta, connStr, cargaId, institutos, cargos → leidas/filasValidas/filasConError/mensajesError |
| A5 Archivo | Proceso P03-P04 Cambios y Recalculo | cargaId, connStr → huboRecalculo, mesMinimo, filasPlan, ms, cambios |
| A6 Archivo | Proceso P05 Cerrar Carga | connStr, cargaId y cuatro contadores BP → éxito; asignar bdConfirmada=True |
| A7 Archivo | Acción PlanBot_Archivos_Hash / Mover Archivo | ruta, carpeta="C:\PlanBot\procesados", cargaId → rutaDestino (prefijo ID/tiempo, sin sobrescribir) |
| A8 Archivo | Acción interno Work Queues / Update Status | Item ID=[itemId]; Status="Cargada; revisar errores de fila si los hay" |
| A9 Archivo | Acción interno Work Queues / Mark Completed | Item ID=[itemId] → volver M3 |

El productor de archivos/monitor de carpeta de Lucas puede encolar ruta con el mismo esquema; no se inventa aquí un watcher adicional. Con encolarPrueba=True el maestro añade exactamente la fila de Initial Values; poner False después del ensayo. El candado de Get Next Item protege el ítem; la operación completa sigue siendo serial por foto BUK. Referencia del objeto estándar: [Work Queues](https://documentation.blueprism.com/workhq/en-us/design-studio/internal-business-objects/work-queues-business-object.htm); verificar etiquetas de los parámetros opcionales contra el objeto Enterprise importado.

Error del maestro: Recover del bloque Trabajo de Main (que contiene la referencia a Archivo) → guardar tipo/detalle sin logging → si cargaCreada AND NOT bdConfirmada, ejecutar P(N1; cargaId) y Ejecutar Comando Q09 en bloque protegido → Work Queues / Update Status (Item ID, Status="Error técnico; conciliación manual") → Mark Exception (Item ID, Exception Reason="Revisar carga y Session Log protegido", Retry=False; si aparece Keep Locked=False) → borrar connStr → Resume → End con Exception de tipo/detalle originales. No iniciar otro archivo después de un fallo técnico. Si bdConfirmada=True y falló mover/cola, **no** cambiar el estado SQL a error: el cálculo ya terminó; conservar la entrada para archivado manual. Si no se adquirió itemId, no llamar acciones sobre un ítem vacío.

## 7. SQL exacto para pegar

Referencia canónica: [llamadas_robot.sql](../../database/demo/llamadas_robot.sql). Cada etiqueta remite al número de paso del archivo:

| Llamada de esta guía | Etapa / acción ODBC | Paso canónico |
|---|---|---|
| Q01 | P01, Ejecutar Consulta, T1(hash) | 1 |
| Q02 | P01, Ejecutar Consulta, T2(ruta, hash) | 2 |
| QM-BUK | P02, Carga Masiva, datosCarga | 3 |
| QM-ERROR | P02, Carga Masiva, errores | 4 |
| Q03 | P02, Ejecutar Consulta, N1(cargaId) | 5, cargar_dotacion |
| Q04 | P02/P05, Ejecutar Consulta, N1(cargaId) | 5, SELECT de contadores |
| Q05 | P03, Ejecutar Consulta, N1(cargaId); lista opcional | 6, detectar_cambios |
| Q06 | P03, Ejecutar Consulta, N1(cargaId) | 6, mes_minimo_afectado |
| Q07 | P04, Ejecutar Consulta, N2(cargaId, mesMinimo) | 7 |
| Q08 | **RETIRADO: no crear ninguna etapa UPDATE de cierre** | 5 confirma cierre automáticamente |
| Q09 | Recuperación, Ejecutar Comando, N1(cargaId) | 9; requiere V009 |
| Q10 | P06 opcional, Ejecutar Consulta, parametros vacía | 8 |

**Parámetros:** `?` son posicionales; el orden de las filas de parametros debe coincidir, no lo determina nombre. Un Number de BP llega como Decimal (.NET): usar **CAST(? AS bigint)** para IDs y **CAST(? AS integer)** para meses en RPC. Sin CAST, PostgreSQL busca por ejemplo cargar_dotacion(numeric) y no encuentra la función bigint. Usar Ejecutar Consulta con el SQL explícito, no Ejecutar Función sin casts. En Carga Masiva no hacen falta casts: las columnas del INSERT fijan tipos; fechas como DateTime y NULL como DBNull real. En las tres columnas date de stg.buk_fila, Carga Masiva usa OdbcType.Date, incluido DBNull; si llegan como Text, falla antes de abrir conexión. Nunca concatenar valores ni usar el texto "NULL".

Q01 — paso 1, T1(hash):

```sql
SELECT carga_id FROM stg.carga WHERE hash = ?;
```

Q02 — paso 2, T2(ruta, hash); ruta se almacena en archivo:

```sql
INSERT INTO stg.carga (tipo, archivo, hash, estado) VALUES ('buk', ?, ?, 'recibida')
ON CONFLICT (hash) DO NOTHING RETURNING carga_id;
```

QM-BUK — paso 3, referencia del INSERT que parametriza Carga Masiva:

```sql
INSERT INTO stg.buk_fila (carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo,
        tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada,
        ndias, cod_esp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
```

QM-ERROR — paso 4, referencia de Carga Masiva, seis valores:

```sql
INSERT INTO stg.error_fila (carga_id, fila, persona_id, campo, valor, motivo) VALUES (?, ?, ?, ?, ?, ?);
```

Carga Masiva construye el INSERT a partir de los nombres/orden de columnas de cada DataTable y agrega los valores en ese mismo orden. Comprobar correspondencia columna/valor con las referencias anteriores; no usar el orden físico de stg como sustituto. No ejecutar además estos INSERT manuales para las mismas filas. El prefijo **cargar_dotacion:** en motivo pertenece a rechazos del back; el robot no lo añade. Ambos lotes van antes de Q03; esta guía guarda errores primero para conservarlos ante un fallo posterior.

Q03 — paso 5, N1(cargaId):

```sql
SELECT * FROM api.cargar_dotacion(CAST(? AS bigint));
```

Q04 — paso 5, N1(cargaId), lectura de cierre para P02/P05; reemplaza el antiguo COUNT de mensajes:

```sql
SELECT leidas, validas, con_error, estado FROM stg.carga WHERE carga_id = CAST(? AS bigint);
```

Q05 — paso 6, N1(cargaId), lista opcional para el informe:

```sql
SELECT * FROM api.detectar_cambios(CAST(? AS bigint));
```

Q06 — paso 6, N1(cargaId):

```sql
SELECT api.mes_minimo_afectado(CAST(? AS bigint)) AS mes_minimo;
```

Q07 — paso 7, N2(cargaId, mesMinimo), una única sentencia/conexión:

```sql
WITH contexto AS MATERIALIZED (
    SELECT set_config('planbot.motivo', 'PlanBot Ciclo BUK; carga=' || CAST(CAST(? AS bigint) AS text), true) AS motivo)
SELECT r.filas, r.ms FROM contexto c
CROSS JOIN LATERAL api.recalcular(CASE WHEN c.motivo IS NOT NULL THEN CAST(? AS integer) END) r;
```

La dependencia respecto de c.motivo fuerza evaluar el contexto antes de la RPC. No ejecutar set_config por separado. Q06 NULL implica no llamar Q07: tampoco pasar cero. recalcular ya rehace la cuadratura.

**Q08 retirado**, sin sentencia SQL. No actualizar leidas/validas/con_error ni volver a fijar estado='cargada'; se consulta Q04.

Q09 — paso 9, N1(cargaId), Ejecutar Comando solo en recuperación:

```sql
UPDATE stg.carga SET estado = 'error' WHERE carga_id = CAST(? AS bigint);
```

V009 concede UPDATE(estado) a bot_carga. No cambiar contadores en esta sentencia ni ampliar permisos del robot. Conservar la regla bdConfirmada del maestro para no marcar error por una falla de archivado posterior a una carga confirmada.

Q10 — paso 8, parametros vacía con columnas nombre/valor:

```sql
SELECT api.cuadratura() AS pct_coincidencia;
```

### P06 Cuadratura (opcional)

No es requisito de P01–P05: Q07 ya la rehace. Si se necesita el porcentaje en el informe, crear proceso **P06 Cuadratura**, páginas Main/Error con el mismo patrón Recover/Resume. Input connStr Text; output pctCoincidencia Number=0. Locales parametros (Collection vacía, nombre Text/valor Text), resultado Collection, esNulo Flag=False, filasResultado Number=0 y errorTipo/errorDetalle Text.

Orden: Start → Ejecutar Consulta Q10 → Leer Numero Resultado (columna "pct_coincidencia", numero→pctCoincidencia) → Decision (una fila y no NULL; si no, Exception) → End. Puede invocarse después de P05, con bdConfirmada=True, antes del archivado; no hacer otro recálculo. Si falla, conservar la carga confirmada y reportar el error sin reintentar lotes.

## 8. Ensayo paso a paso (base restaurable, ventana con Andrés)

| Proceso | Con 01_original.xlsx | Con 03_errores.xlsx |
|---|---|---|
| P01 | Copiar archivo terminado a entrada\buk; ejecutar con connStr protegido: obtiene ID>0. Repetir sin cargar otra vez: duplicado=True, ninguna carga nueva. | Restaurar snapshot de ensayo donde 03 no exista; ID nuevo. No alterar hash para reintentar una carga parcial. |
| P02 | Con ID de P01 y catálogos aprobados: 3123 leídas, 3123 válidas, 0 filas con error en el fixture revisado; fechas DateTime. Confirmar core por SQL con Andrés. | Desde estado 01, nuevo P01/ID: 3124 leídas, 3119 válidas, 5 filas con error. Comparar esperado_errores.csv por persona/campo y fila original, no por texto literal. Varias causas en una fila cuentan una vez. |
| P03-P04 | Primera carga: mínimo 1 y recálculo. Para probar NULL, usar una copia con contenido realmente distinto pero misma dotación aprobada por Andrés, o su test SQL de «sin cambios»; reenviar bytes idénticos termina en P01, no prueba esta rama. | 03 se deriva de 01; sus válidas pueden cambiar la foto. No asumir «sin cambios» ni exactamente cinco eventos. No medir errores después de 02 sin restaurar 01. |
| P05 | leidas=3123, validas=3123, con_error=0; filasCore proyectadas no sustituyen válidas. | leidas=3124, validas=3119, con_error=5. Archivo termina en procesados; la fila rechazada queda en stg.error_fila. El ítem se completa con advertencia, no se pierde el informe. |
| Maestro | encolarPrueba=True, archivosPrueba.ruta=01; ver un ítem adquirido y completado, archivo movido, carga y plan. Para otra ejecución poner False. | Restaurar 01; editar la fila Initial Values a 03 y encolar una vez. Revisar cinco errores y archivo archivado; repetir 03 debe dar «archivo repetido», sin nueva carga/plan. |

Los conteos anteriores son referencias de fixtures, no condiciones por persona_id. Guardar hash, carga_id, release, cola y Session Log sin claves, evidencia SQL y captura del dashboard **En vivo** tras Actualizar datos. Probar además: colección catálogo vacía, todas las filas inválidas, desconexión ODBC entre lotes y carpeta destino inexistente. Debe detenerse y conservar trazabilidad; no borrar stg para «arreglarlo».

Antes del jurado ejecutar Check Code, prueba SELECT 1 y este recorrido en el Runtime real. La compilación de los auxiliares y la prueba SQL externa no certifican el MS Excel VBO, los permisos de la credencial BP ni las conexiones ODBC de la VM.

**Pendiente de Lucas — prueba ODBC de una fila:** este PC no tiene PostgreSQL Unicode(x64) registrado. Antes de los lotes, probar Carga Masiva en una carga de ensayo con periodo/fecha_ingreso DateTime y fecha_termino DBNull, verificar los días exactos y el NULL en SQL; repetir con fecha_termino informada. No dar por probada la ruta ODBC por pasar el e2e psql. Mantener connStr/credenciales fuera de logs.
