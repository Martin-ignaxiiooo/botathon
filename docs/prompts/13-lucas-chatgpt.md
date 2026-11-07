# Lucas · ChatGPT · Blue Prism 7.5.1 (VM de la Botathon)

Flujo: pega el ARRANQUE completo como primer mensaje de un chat nuevo. Después, al empezar cada historia, pega su prompt. Si el chat se pone lento o largo, abre uno nuevo, pega el ARRANQUE y luego la historia en que vas.
El código C# de los objetos te lo entrega César (archivos de bluePrism\codigo\ con su LEEME.md).

## ARRANQUE

Hola. Vas a ser mi tutor y copiloto de Blue Prism durante una hackathon de 16 horas. Lee todo antes de responder.

1. EL PROYECTO. Botathon 2026, desafío "Cada hora cuenta" de Teletón Chile. Construimos "PlanBot", que reemplaza un Excel manual de planificación asistencial: calcula para cada profesional y mes cuántas horas dedica a atención directa, indirecta y no asistencial, y cuántas atenciones debe hacer (meta = 90 %). Datos ficticios: cada persona se identifica solo con persona_id. Tres partes: (1) BLUE PRISM, mi parte: recibe los Excel que se dejan en carpetas, los limpia, valida fila por fila, informa errores, carga lo válido en PostgreSQL y llama funciones SQL que recalculan todo. Yo NO calculo nada en Blue Prism. (2) POSTGRESQL, lo programa Andrés. (3) DASHBOARD WEB, lo programa César. El jurado exige que Blue Prism sea central y visible: en la demo se deja un Excel en una carpeta y el robot lo procesa solo.

2. MI ENTORNO. Blue Prism 7.5.1 en una VM Windows (Studio, Control Room, System). PostgreSQL 16 en la misma VM, base "planbot", puerto 5432. Conexión por ODBC (driver "PostgreSQL Unicode(x64)") con un objeto propio cuyo código C# me da César. Soy principiante: explícame como a alguien que recién empieza.

3. CONFIGURACIÓN. Carpetas: C:\PlanBot\entrada\planificacion, C:\PlanBot\entrada\buk, C:\PlanBot\entrada\parametros, C:\PlanBot\entrada\asignaciones, C:\PlanBot\procesados, C:\PlanBot\errores, C:\PlanBot\reportes. Colas: Q_BUK_FILAS, Q_ASIGNACIONES, Q_REPORTES (máx. 3 intentos). Credencial: PlanBot_Postgres (usuario bot_carga); nunca contraseñas en los procesos. Variables de entorno: RutaBase, ConnStrSinClave, CorreoPlanificacion, CorreoGP.

4. LOS EXCEL. (A) "Nac - Base contratos x mes.xlsx", hoja "Dotacion_2026": fila 1 vacía, encabezados en la FILA 2, ~878 filas vacías y un encabezado repetido; una fila por persona y mes (~3.100 filas útiles). Columnas: IT, Instituto, PersonaId, Área, Nombre Sub-área, Centro de Costo, Fecha de Nacimiento, Periodo, Tipo de Contrato, Tipo_Trab_161225, Fecha Ingreso Compañía, Fecha Término, Horas Semanales, Cargo, Tipo_Trabajador, Días de la Jornada, Reg_SIC, Cod_Esp, Ndias. (B) "Nac - Planificación Asistencial x mes.xlsx": Distribucion_NAC A7:N92 (código, cargo, unidad, minutos directa e indirecta, % directo/indirecto/NAS de 3 tramos en F-H, I-K, L-N) y R7:T39 (asignaciones); Parámetros S3:AD14 (calendario) y F3:I25 (grupal); Excepciones A2:W19. Archivos de prueba (los prepara César): 01_original.xlsx, 02_cambios.xlsx, 03_errores.xlsx.

5. CONTRATO CON LA BASE (no inventar ni renombrar columnas). Solo escribo en: stg.carga(carga_id autonumérico, tipo 'buk'|'planificacion'|'parametros'|'asignaciones', archivo, hash único, recibido_en, estado, leidas, validas, con_error); stg.buk_fila(carga_id, it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp); stg.error_fila(carga_id, fila, persona_id, campo, valor, motivo); stg.param_cargo(carga_id, cod_esp, cargo, unidad, min_directa, min_indirecta, tramo, pct_dir, pct_ind, pct_nas); stg.param_asignacion(carga_id, tipo, horas_semana, requiere_dmn, descripcion); stg.param_calendario(carga_id, mes, zona, dias, inhabiles, dias_habiles, semanas); stg.param_grupal(carga_id, cod_esp, grupo_it, pct_grupal, pacientes_grupo); stg.excepcion(carga_id, persona_id, it, mes, horas); stg.asignacion(...). Funciones que llamo: cargar_parametros(carga_id), cargar_dotacion(carga_id), detectar_cambios(carga_id), mes_minimo_afectado(carga_id), recalcular(desde_mes), cuadratura(). Vistas para informes: api.v_errores_carga, api.v_cambios, api.v_profesional_mes. Antes de recalcular: SELECT set_config('planbot.motivo', '<motivo>', false).

6. LO QUE CONSTRUYO, EN ORDEN. Objetos: "PlanBot - PostgreSQL" (Ejecutar Consulta, Ejecutar Comando, Ejecutar Función, Carga Masiva, Armar Conexion) y "PlanBot - Archivos" (Listar Nuevos, Calcular Hash, Archivar). Procesos: A-01 entorno; A-04 P01 Recepción; A-05 P02 Limpieza y validación (el más importante); A-06 P00 Extraer reglas; A-07 P03-P04 Cambios y recálculo; A-08 P05 Informe; proceso maestro "PlanBot Ciclo BUK"; A-09 P06 Cuadratura; A-13 programación en Control Room y release v1.0. Extras: A-10 parámetros con simulación, A-11 asignaciones.

7. BUENAS PRÁCTICAS. Manejo de excepciones en cada proceso y página (Block + Recover + registro + Resume); distinguir excepción de negocio y de sistema; rutas, correos y conexión desde Environment Variables y contraseña desde Credentials; SQL siempre con parámetros (?); nombres en español; probar con Step y Run; exportar cada objeto o proceso (File > Export) al terminar.

8. HORARIO. 0-1 h A-01 · 1-2 h objeto Archivos · 2-2:30 P01 · 2:30-3:30 objeto PostgreSQL · 3:30-6:30 P02 · 6:30-8 P00 · 8-9 P03-P04 · 9-10 P05 · 10-11 P06 y pruebas · 11-13 extras · 13-14:30 programación y release · 14:30-16 ensayo.

9. CÓMO TRABAJAR CONMIGO. De a una historia: primero un resumen (páginas, Data Items, colecciones) y luego pasos numerados: qué pestaña, qué etapa arrastrar, cómo nombrarla, qué objeto y acción, qué entradas y salidas. Usa nombres exactos de objetos de Blue Prism (MS Excel VBO, Utility - File Management, Utility - Collection Manipulation, Work Queues, Credentials, Environment). Si no estás seguro de que una acción exista en 7.5.1, dímelo y da una alternativa. Si hace falta C#, dime qué pedirle a César. Si te pego un error, dime la causa probable y cómo arreglarlo. Al final de cada historia, una lista de verificación. Español, claro y sin relleno.

Empecemos con A-01.

## A-01 · Preparar el entorno
Guíame para: (1) revisar la VM: versión de Blue Prism, si hay Excel instalado, permisos de administrador, y en PowerShell "systeminfo | findstr /i Hyper-V" y "wsl --status"; (2) crear las carpetas de C:\PlanBot; (3) crear en System > Workflow > Work Queues las colas Q_BUK_FILAS, Q_ASIGNACIONES y Q_REPORTES con clave "Clave" y máximo 3 intentos; (4) crear en System > Security > Credentials la credencial PlanBot_Postgres; (5) crear en System > Processes > Environment Variables: RutaBase, ConnStrSinClave, CorreoPlanificacion, CorreoGP. Dame una lista para marcar.

## A-03 · Objeto PlanBot - Archivos
Guíame para crear el Business Object "PlanBot - Archivos" con: Listar Nuevos (entrada carpeta; salida colección de .xlsx ordenados por fecha con Utility - File Management > Get Files), Calcular Hash (entrada ruta; salida hash; code stage C# del archivo PlanBot_Archivos_Hash.cs que me dio César), Archivar (entradas ruta y destino "procesados" o "errores"; mueve agregando fecha y hora al nombre; si está en uso reintenta 3 veces cada 5 segundos y luego lanza excepción de negocio "Archivo en uso"). Explica cómo probar cada acción desde Object Studio.

## A-04 · P01 Recepción BUK
Guíame para crear "PlanBot P01 Recepcion BUK": (1) Listar Nuevos en C:\PlanBot\entrada\buk; (2) por cada archivo, Calcular Hash; (3) con PlanBot - PostgreSQL > Ejecutar Consulta revisar si existe: SELECT count(*) FROM stg.carga WHERE hash = ?; (4) si existe, Archivar en errores con motivo "archivo repetido"; (5) si no, abrir con MS Excel VBO y verificar la hoja Dotacion_2026 (si no está, rechazar "no es la base de contratos"); (6) si es válido, INSERT INTO stg.carga(tipo, archivo, hash, estado) VALUES ('buk', ?, ?, 'recibido') RETURNING carga_id y guardar carga_id para el siguiente proceso. Con manejo de excepciones.

## A-02 · Objeto PlanBot - PostgreSQL
César me dio el código C# (PlanBot_PostgreSQL.cs y su LEEME.md). Guíame para: (1) instalar psqlODBC de 64 bits y verlo en "Orígenes de datos ODBC (64 bits)"; (2) crear el objeto y configurar Code Options según el LEEME; (3) crear cada acción con sus Data Items y su Code stage; (4) crear "Armar Conexion" con Credentials > Get Login (PlanBot_Postgres) y la variable ConnStrSinClave; (5) probar con SELECT 1. Te pego el LEEME y el código: [pegar aquí].

## A-05 · P02 Limpieza y validación
Guíame para "PlanBot P02 Validacion BUK" (recibe carga_id y ruta), en páginas Leer, Limpiar, Validar, Cargar:
1) MS Excel VBO: Create Instance, Open Workbook, Get Worksheet Range As Collection desde A2 de la hoja Dotacion_2026 (los encabezados están en la fila 2).
2) Limpiar: quitar filas con PersonaId vacío y filas donde "Tipo de Contrato" dice "Tipo de Contrato" (encabezado repetido); contar las quitadas.
3) Renombrar columnas a: it, instituto, persona_id, area, sub_area, centro_costo, periodo, tipo_contrato, tipo_trabajador, fecha_ingreso, fecha_termino, horas_semanales, cargo, dias_jornada, ndias, cod_esp (y quitar las que no van: Fecha de Nacimiento, Tipo_Trab_161225, Reg_SIC).
4) Validar en un Loop: persona_id numérico; periodo fecha; horas_semanales entre 1 y 45; fecha_termino posterior a fecha_ingreso si existe; it y cargo existentes (consultar una vez SELECT it FROM param.instituto y SELECT cargo_origen FROM param.cargo_homologado). Errores a una colección Errores (fila, persona_id, campo, valor, motivo) y a la cola Q_BUK_FILAS como excepción con su motivo; válidas a una colección Validas.
5) Carga Masiva de Validas en stg.buk_fila (agregando carga_id) y de Errores en stg.error_fila.
6) Ejecutar Función cargar_dotacion(carga_id) y UPDATE stg.carga SET leidas=?, validas=?, con_error=?, estado='validado' WHERE carga_id=?.
7) Cerrar Excel siempre, también con error (Recover).
Si validar fila por fila con la cola es muy lento (más de 5 minutos), dime cómo validar en memoria y mandar a la cola solo las filas con error.

## A-06 · P00 Extraer reglas
Guíame para "PlanBot P00 Extraer Reglas" sobre la planilla dejada en C:\PlanBot\entrada\planificacion: registra stg.carga tipo 'planificacion'; lee con Get Worksheet Range As Collection: Distribucion_NAC A7:N92 → una fila por cargo y tramo (3 tramos: F-H, I-K, L-N) → stg.param_cargo; Distribucion_NAC R7:T39 → stg.param_asignacion; Parámetros S3:AD14 → stg.param_calendario (zona "general"); Parámetros F3:I25 → stg.param_grupal; Excepciones A2:W19 → stg.excepcion (una fila por persona, instituto y mes). Valida que dir+ind+nas sumen 1 por cargo y tramo (las que no, a stg.error_fila). Al final Ejecutar Función cargar_parametros(carga_id).

## A-07 + A-08 · Cambios, recálculo e informe
Guíame para: (1) "PlanBot P03-P04 Cambios": recibe carga_id; Ejecutar Función detectar_cambios(carga_id) (colección de cambios); luego mes_minimo_afectado(carga_id); SELECT set_config('planbot.motivo', 'Carga BUK ' || ?, false); recalcular(mes); guarda la duración; UPDATE stg.carga SET estado='procesado'. (2) "PlanBot P05 Informe": crea C:\PlanBot\reportes\informe_carga_<carga_id>.xlsx con hojas Errores (SELECT * FROM api.v_errores_carga WHERE carga_id = ?) y Cambios (api.v_cambios); intenta enviarlo por correo a CorreoGP y CorreoPlanificacion; si falla el correo, solo registra "correo no disponible" y sigue. (3) Proceso maestro "PlanBot Ciclo BUK": P01 → P02 → P03-P04 → P05 por cada archivo nuevo.

## A-09 + A-13 · Cuadratura, programación y release
Guíame para: (1) "PlanBot P06 Cuadratura": Ejecutar Función cuadratura(), leer el % de coincidencia y escribir un informe en C:\PlanBot\reportes; (2) programar "PlanBot Ciclo BUK" cada 5 minutos en Control Room (Schedules); (3) exportar todo como release: System > Release Manager > paquete "PlanBot" con procesos y objetos > release v1.0 > exportar .bprelease; (4) lista de verificación antes de la demo: colas vacías, carpetas de entrada limpias, credencial vigente, Digital Worker conectado.

## A-10 · Cambios de parámetros con simulación (extra)
Guíame para "PlanBot P07-P09 Parametros": detectar un Excel en C:\PlanBot\entrada\parametros con una hoja Motivo; cargar sus tablas en stg.param_* con una carga tipo 'parametros'; insertar un escenario en calc.escenario (Andrés me dirá las columnas); Ejecutar Función simular(escenario_id) y escribir el impacto en un Excel en reportes; esperar aprobación (respuesta "APROBADO" por correo o un archivo C:\PlanBot\entrada\parametros\APROBADO.txt); luego aplicar_escenario(escenario_id) y recalcular(1).

## A-11 · Asignaciones especiales (extra)
Guíame para "PlanBot P10 Asignaciones": leer una plantilla Excel de C:\PlanBot\entrada\asignaciones (persona_id, it, tipo, horas, desde, motivo, solicitante); rechazar si la persona ya tiene 2 asignaciones y más de 30 h semanales o si el tipo no está en param.asignacion_catalogo; si requiere visto bueno de la Dirección Médica Nacional, dejarla pendiente en Q_ASIGNACIONES; al aprobarse, insertar en stg.asignacion, recalcular y avisar al solicitante.
