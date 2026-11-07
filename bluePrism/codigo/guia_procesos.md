# Construir PlanBot Ciclo BUK · Blue Prism 7.5.1

Guía de construcción, no un release ya importado. Crear cinco procesos con estos nombres: **P01 Recibir BUK**, **P02 Cargar BUK**, **P03-P04 Cambios y Recalculo**, **P05 Cerrar Carga**, **PlanBot Ciclo BUK**. Cada ítem de cola representa un archivo, no una persona. Ejecutar un solo consumidor durante la demo: cargar_dotacion reemplaza la foto completa y dos cargas simultáneas pueden interferirse.

Las acciones C# van en **Object Studio**, nunca en Process Studio. Preparar los cinco BO del [LEEME](LEEME.md), publicar las acciones y ejecutar Check Code. Pegar el cuerpo de cada método sin firma/clase. No se requiere Npgsql. Los .cs usan sintaxis compatible con C# 7.3/.NET 4.7; las pruebas externas no sustituyen Check Code/ODBC en el Runtime.

## 1. Preparación común

1. Confirmar las cinco RPC en api: cargar_parametros, cargar_dotacion, detectar_cambios, mes_minimo_afectado y recalcular. El mínimo es NULL cuando no hay cambios; la primera carga pide mes 1. No llamar funciones sin api ni inventar funciones nuevas.
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

**Q(nn)** significa Acción *PlanBot_PostgreSQL / Ejecutar Consulta*: connStr=[connStr], sql=texto Qnn del apartado 7, parametros=[parametros], resultado→[resultado]. Para UPDATE usar *Ejecutar Comando*, mismos inputs y filasAfectadas→[filasAfectadas]. **L(columna→item)** significa Acción *Leer Numero Resultado*: resultado=[resultado], columna literal → numero=[item], esNulo=[esNulo], filasResultado=[filasResultado]. Estos atajos son etapas distintas, no un BO ficticio.

| Collection | Campos y tipos exactos | Inicial |
|---|---|---|
| parametros | nombre Text; valor Text para T*, Number para N* | Dinámica, sustituida en cada P |
| resultado, datosExcel, limpias, validas, errores, datosCarga, cambios | Forma de la acción que las devuelve | Sin esquema inicial |
| institutos | it Number | Filas aprobadas del catálogo |
| cargos | cargo_origen Text | Filas aprobadas del catálogo |
| archivosPrueba, datosItem | ruta Text | archivosPrueba: una fila C:\PlanBot\entrada\buk\01_original.xlsx; datosItem: vacía |

limpias: it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp; más fila Number. Conserva los valores originales para validar. validas/datosCarga: **carga_id + los 16 campos anteriores, sin fila**. Números .NET: carga_id/persona_id bigint, it/ndias int, horas_semanales decimal; otros Text salvo las tres fechas: validas entrega ISO Text, Preparar Carga las convierte a DateTime en datosCarga. errores: carga_id Number, fila Number, persona_id Number nullable, campo/valor/motivo Text. Un DBNull real no es el texto "NULL".

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

Start: ruta Text, connStr Text, cargaId Number, institutos/cargos Collection. End: leidas, filasValidas, filasConError, mensajesError Number. Locales: handle Number=0; libro Text=""; excelAbierto Flag=False; filasDescartadas/insertadas/filasCore/alertas/totalMensajes/esNulo/filasResultado (esNulo es Flag, restantes Number); colecciones de apartado 2; errorTipo/errorDetalle Text. No conservar datos entre archivos.

| Orden / etapa | Tipo, objeto y acción | Entradas → salidas / enlace |
|---|---|---|
| 1 Excel propio | Acción MS Excel VBO / Create Instance | handle→handle; no conectar a Excel del usuario |
| 2 Abrir | Acción MS Excel VBO / Open Workbook | handle=[handle], Filename=[ruta] → Workbook Name=[libro]; excelAbierto=True |
| 3 Leer hoja | Acción MS Excel VBO / Get Worksheet As Collection | handle, Workbook Name=[libro], Worksheet Name="Dotacion_2026" → Collection=[datosExcel] |
| 4 Cerrar libro | Acción MS Excel VBO / Close Workbook | handle, Workbook Name=[libro], Save=False |
| 5 Cerrar instancia | Acción MS Excel VBO / Close Instance | handle; excelAbierto=False |
| 6 Limpiar | Acción PlanBot_Limpieza / Limpiar Dotacion | datos=[datosExcel] → limpias, filasDescartadas |
| 7 Validar | Acción PlanBot_Validador / Validar Dotacion | limpias, institutos, cargos, cargaId → validas, errores |
| 8 Tipar/contar | Acción PlanBot_PostgreSQL / Preparar Carga | validas, limpias, errores → datosCarga, leidas, filasValidas, filasConError, mensajesError |
| 9 Guardar errores | Acción PlanBot_PostgreSQL / Carga Masiva | connStr, tabla="stg.error_fila", datos=[errores], tamanoLote=500 → insertadas |
| 10 Hay válidas | Decision | filasValidas>0: seguir; False: Exception «Sin filas válidas; no reemplazar dotación» |
| 11 Guardar válidas | Acción PlanBot_PostgreSQL / Carga Masiva | connStr, tabla="stg.buk_fila", datos=[datosCarga], tamanoLote=500 → insertadas |
| 12 ID para cargar | P(N1; cargaId) | numero1=[cargaId] |
| 13 Cargar core | Q03 | RPC real cargar_dotacion |
| 14 Leer respuesta | L(filas→filasCore), luego L(alertas→alertas) | Dos Action stages; filasCore incluye proyección y **no** es filasValidas |
| 15 Revisar rechazos BD | P(N1; cargaId), Q04, L(mensajes→totalMensajes) | Si totalMensajes<>mensajesError: Exception «BD agregó/eliminó errores: conciliar carga»; si iguales, End |

La lectura debe conservar la cabecera Excel de fila 2 en datosExcel (o en sus nombres de columna). No quitar filas antes de Limpiar Dotacion: se perdería fila original. Si el VBO dispone de Use Header, dejar False para conservar cabecera; si no, comprobar que datosExcel contiene IT/PersonaId/Periodo en la fila útil. Preferir valores Value/Value2, no Text formateado. Las etiquetas/inputs del VBO pueden variar con la versión importada: comprobarlos en Object Studio antes de mapear; no existe un VBO universal pegable en este repo. Referencia primaria: [MS Excel VBO User Guide](https://community.blueprism.com/hfgie69872/attachments/hfgie69872/digital-exchange/4467/1/Excel%20Guide.pdf).

Error: cerrar solo la instancia Excel creada por este proceso si excelAbierto=True; proteger Close Workbook/Close Instance con su propio Recover/Resume y reemitir el error original. Puede haber lotes confirmados. No volver a ejecutar 9–13 automáticamente; no tiene DELETE el robot. Si hay rechazos adicionales de BD, no inventar una correspondencia entre su fila reenumerada y fila original BP; parar antes del recálculo y conciliar/restaurar con Andrés.

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

**P05** Start: connStr Text, cargaId/leidas/filasValidas/filasConError/mensajesError Number. End sin datos sensibles. Locales resultado/parametros Collection; totalMensajes/filasAfectadas/filasResultado Number; esNulo Flag; errorTipo/errorDetalle Text.

| Orden | Tipo, objeto y acción | Mapeo |
|---|---|---|
| 1 Reconciliar | P(N1; cargaId), Q04, L(mensajes→totalMensajes) | Exigir totalMensajes=mensajesError y leidas=filasValidas+filasConError |
| 2 Cerrar | P(N4; leidas, filasValidas, filasConError, cargaId), Ejecutar Comando Q08 | Los cuatro valores Number en ese orden; exigir filasAfectadas=1 |
| 3 End | End | No mueve archivos ni marca la cola antes de confirmar UPDATE |

P05 cuenta errores **por fila distinta**, no por mensajes, y no usa filasCore (5.338 con original proyectado). El back tiene una corrección de contadores que cuenta mensajes; Q08 cierra con los contadores de BP solo si la BD no agregó rechazos. No oculta nuevos errores ni modifica las funciones. Error: propagar; no declarar la carga finalizada.

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

Q01, T1(hash):
```sql
SELECT carga_id FROM stg.carga WHERE hash = ?;
```
Q02, T2(ruta, hash):
```sql
INSERT INTO stg.carga(tipo,archivo,hash,estado)
VALUES ('buk',?,?,'recibida')
ON CONFLICT (hash) DO NOTHING RETURNING carga_id;
```
Q03, N1(cargaId):
```sql
SELECT * FROM api.cargar_dotacion(CAST(? AS bigint));
```
Q04, N1(cargaId):
```sql
SELECT count(*) AS mensajes FROM stg.error_fila WHERE carga_id=CAST(? AS bigint);
```
Q05, N1(cargaId):
```sql
SELECT * FROM api.detectar_cambios(CAST(? AS bigint));
```
Q06, N1(cargaId):
```sql
SELECT api.mes_minimo_afectado(CAST(? AS bigint)) AS mes_minimo;
```
Q07, N2(cargaId, mesMinimo):
```sql
WITH contexto AS MATERIALIZED (
  SELECT set_config('planbot.motivo',
    'PlanBot Ciclo BUK; carga=' || CAST(CAST(? AS bigint) AS text),true) AS motivo
)
SELECT r.filas,r.ms FROM contexto c
CROSS JOIN LATERAL api.recalcular(
  CASE WHEN c.motivo IS NOT NULL THEN CAST(? AS integer) ELSE NULL END
) r;
```
La dependencia del argumento respecto de c.motivo fuerza evaluar el contexto antes de llamar la RPC; configuración local a la transacción de la consulta, sin contaminar el pool. El resultado contiene solo filas/ms, no una tabla previa set_config.

Q08, N4(leidas, filasValidas, filasConError, cargaId), Ejecutar Comando:
```sql
UPDATE stg.carga SET estado='cargada',leidas=CAST(? AS integer),
 validas=CAST(? AS integer),con_error=CAST(? AS integer)
WHERE carga_id=CAST(? AS bigint);
```
Q09, N1(cargaId), Ejecutar Comando en recuperación:
```sql
UPDATE stg.carga SET estado='error' WHERE carga_id=CAST(? AS bigint);
```

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
