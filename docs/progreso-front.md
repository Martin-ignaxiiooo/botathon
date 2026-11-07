# Progreso FRONT (César · Claude Code, Codex de respaldo)
Última actualización: 2026-11-06 · por: Claude Code
Rama actual: main (todo fusionado)

## Hecho (fusionado en main)
- D-02 extractor (data\extraer.py) y CSV en data\csv
- D-03 mocks: `web\mock\*.json` (8 vistas + escenarios.json), generados con `python web\mock\generar_mocks.py` (semilla fija)
- C-02 esqueleto: `web\index.html`, `css\base.css`, `js\{config,api,router,formato,ui,main}.js`, stubs en `js\pages\`, ECharts 5.6.0 y Tabulator 6.7.1 en `vendor\` (ver `vendor\LEEME.txt`)
- Contrato v1.1: `v_instituto_area_mes` con horas_contratadas/dir/ind/nas; mocks regenerados (la suma por mes cuadra con `v_nacional_mes`)
- C-03 Nacional: 6 tarjetas, líneas atenciones/meta con marca de cambio de jornada, barras de meta por instituto (clic → `#instituto?it=`), horas apiladas por área; cada gráfico con aria-label y «Ver datos»
- C-04 filtros: `js\filtros.js` (instituto múltiple, área, cargo, mes desde/hasta, tipo; estado en el hash; «Limpiar filtros»; evento `filtros-cambiaron`), aplicado en Nacional
- C-05 Instituto: tabla Tabulator área × mes (métrica atenciones/meta/% FOJA, ordenable con clic o teclado, fila de totales), meta mensual apilada por área, profesionales del área elegida con enlace a `#profesional?persona=`

- C-06 Profesional: buscador por persona_id con sugerencias (datalist), ficha con trayectoria, tarjetas, meta mensual con marcas de cambios, línea de tiempo desde `v_cambios`, tabla mes a mes con total

- C-07 Cambios y errores: lista de cargas (archivo, errores, cambios, estado con ícono y texto), detalle por carga (`#cambios?carga=N`) con resumen, tabla de errores y tabla de cambios; textos de cambios compartidos en `js	extoCambios.js`

- C-08 Cuadratura: tarjeta «N de 471 profesionales coinciden al 100 %», % de coincidencia por campo y por mes, explicación de causas y tabla de diferencias filtrable por causa

- C-10 Accesibilidad: botones «Lectura fácil» y «Letra grande» (aria-pressed, se recuerdan en el navegador), resumen de 3 a 5 frases en cada pantalla, auditoría WCAG 2.1 A/AA con axe-core (0 violaciones en 18 combinaciones de pantalla y estado)

- C-09 Parámetros y escenarios: reglas vigentes por tabla con búsqueda, escenarios con impacto antes/después, Aprobar/Rechazar con diálogo accesible que pide motivo (axe: 0 violaciones, también con el diálogo abierto)
- `scripts\servir_web.ps1` ahora funciona también en Windows PowerShell 5.1 (antes solo en PowerShell 7)

- C-11 Exportar CSV e imprimir: `js/exportar.js` (botón por tabla), `js/impresion.js` + `@media print` (cabecera con título, fecha y filtros), botón «Imprimir»

- Pulido para la demo (revisado contra `docs/demo.md`): insignia de origen de datos en el encabezado, Nacional con «Última carga», hora de lectura, botón «Actualizar datos» y variación de las tarjetas respecto de la carga anterior, Cambios abre la carga más reciente
- Corrección de ESLint del CI (`window.MutationObserver`, `window.HashChangeEvent`): `npx eslint@9.39.1 --config .github/eslint.config.js 'web/js/**/*.js'` sin errores

- Prueba con la base real y correcciones (rama `feat/front-api`): claves de parámetros, `area` = sede → agrupar por cargo, valores JSON, cargo nulo, textos de cambios (ver «Prueba con la base real»)

- Gráficos de horas con la 4.ª categoría «Ausencias y feriados» = horas_contratadas − (horas_dir + horas_ind + horas_nas), para que las barras sumen lo contratado (decisión de César: las ausencias no se cargan a NAS). El filtro «Tipo de hora» la incluye y Lectura fácil la explica. Mocks: la parte que no es dir/ind/NAS es la colación (≈3 %).

- Cuadratura con datos reales (B-10): titular **95,55 %** = % de atenciones directas planificadas de mayo a diciembre que coinciden con el Excel; se calcula en el front como 1 − (diferencias de `plan_ate_dir` mes ≥ 5 con `sistema` no nulo) / (filas de `v_profesional_mes` mes ≥ 5) = 1 − 158/3.553, igual al valor de `api.cuadratura()` (comprobado con la base local; `api.cuadratura()` no es llamable por `web_lectura`, así que el valor no sale de una vista). Frase para cada una de las 7 causas de `calc.cuadratura` (`ajuste_individual`, `diferencia_explicada`, `periodo_ene_abr`, `dias_adicionales`, `multi_it`, `grupal`, `otra`; en la base de demo aparecen 6, falta `dias_adicionales`). Gráficos por campo y por mes con denominadores del plan y sin contar las filas con `sistema` nulo (358: la persona figura en otro instituto o sin dotación); la tabla muestra de a 100 diferencias (hay 1.518). Mocks con los códigos de causa reales.
  - Ojo: `v_cuadratura` guarda la comparación del momento en que se ejecutó `api.cuadratura()`; si después se carga otro BUK sin volver a ejecutarla, el titular mezcla un plan nuevo con diferencias viejas. Para mostrarla, ejecutar `SELECT api.cuadratura();` justo antes.

- Capturas para la presentación en `docs\capturas\` (12 PNG a escala 2 + `LEEME.md` con el estado de datos de cada una), tomadas con la base real local; herramienta repetible en `web\dev\capturar.ps1` + `web\dev\captura.html`. La 09 (escenario y diálogo) usa datos de prueba porque la base real no tiene escenarios; la 11 (impresión) es una emulación de `@media print`, no un PDF.
- Detector de «área = sede» tolerante (≥ 95 % de las filas): tras un `cambio_it` la persona conserva el `area` de su sede anterior (p. ej. 71146 queda con instituto Puerto Montt y area Santiago), lo que antes hacía reaparecer el filtro Área y agrupar por sede. **Observación para el back:** `area` no se actualiza al trasladar a una persona.

- Cuadratura: las 7 causas con las **descripciones oficiales de Andrés**, mostradas en el orden en que la base las evalúa (diferencia_explicada, ajuste_individual, periodo_ene_abr, dias_adicionales, multi_it, grupal, otra; las 7 aparecen aunque tengan 0 casos) y la tabla/filtro en ese mismo orden; titular 95,55 %.
- Escenarios reales (B-12): Parámetros usa `rpc/listar_escenarios` (POST `{}`, sin token) y `rpc/decidir_escenario` (POST `{"escenario_id":..,"decision":"aprobar"|"rechazar","motivo":".."}`). **Modo planificador:** botón «Ingresar como planificador» abre un diálogo donde se pega el token JWT; se guarda solo en `sessionStorage` (`planbot-token-planificador`; nunca en el repo, en `config.js` ni en `localStorage`) y se envía como `Authorization: Bearer` únicamente en `decidir_escenario`; estado «Modo planificador activo · el token vence…» con «Salir»; token vencido → «Ingresar de nuevo». Sin token (solo en modo api) Aprobar/Rechazar quedan inactivos (`aria-disabled`) con la nota «Requiere ingresar como planificador» y al pulsarlos piden el token. Errores traducidos: 401 sin token → «Requiere ingresar como planificador», 401 `PGRST301` → token no válido (formato o firma), `PGRST303`/expired → token venció, 403 → rol sin permiso, 400 → mensaje de negocio del back (p. ej. «el escenario 2 ya está aprobado»). En modo mock no se pide token.
  - **Falta en `main` para que decidir funcione en la VM** (está en la rama `origin/feat/C-01-jwt`): `api\postgrest.conf` con `jwt-secret`, `database\views\zz_permisos_jwt.sql` (`GRANT planificador TO web_lectura WITH INHERIT FALSE, SET TRUE`) y `scripts\token_planificador.ps1`. En la base local apliqué ese SQL a mano, PostgREST corre con `PGRST_JWT_SECRET` del `.env` y usé una copia del script (`C:\tools\token_planificador.ps1`, fuera del repo).
  - **Probado con la base real:** listar (3 escenarios de ejemplo), sin token, token con formato inválido, firma incorrecta (401), token vencido (interfaz), aprobar de verdad el escenario 1 con motivo (pendiente → aprobado, el foco vuelve al escenario) y salir. El escenario 1 se restableció a «pendiente» por SQL en la base local para las capturas. **No probado:** respuesta 403 (rol no permitido) ni 401 por vencimiento medido por el servidor (están mapeados en el código). axe 0 violaciones en sin token, diálogo de token, modo planificador y diálogo de decisión.
  - El token nunca se muestra en pantalla (campo oculto) y las capturas se tomaron con un token de 2 horas generado en local.

- Pasada final (8-nov, tras PR #10): base local actualizada con `instalar_sin_docker.ps1 -SinPruebas`, token con `scripts	oken_planificador.ps1` del repo (copia de `C:	ools` borrada), prueba de escenarios repetida sin diferencias (sin token, formato inválido, firma incorrecta, vencido, aprobar real, salir) y captura 09 rehecha con datos reales. axe 0 violaciones en 18 combinaciones en modo api y en modo mock, 0 mensajes de consola, ESLint del CI sin errores, vistas `v_kpi`/nacional/instituto/profesional cuadran (621.256 atenciones, 556.772 de meta). Las capturas 01–08 y 11 conservan los valores del estado 01+02 (622.271 / 557.689), como indica su LEEME.

## En curso
- —

## Siguiente
- Ensayo completo de `docs/demo.md` en la VM con Blue Prism; si el back cambia `area` a la especialidad, revisar Nacional e Instituto

## Cómo probar el front
- Servir sin bloquear: `.\scripts\servir_web.ps1` (puerto 8080 por defecto, en segundo plano; `-Detener` lo apaga, `-Puerto` cambia el puerto). Es la única excepción a las carpetas de Claude Code en `AGENTS.md` (`scripts\` es del BACK); autorizada por César.
- Recorrido de la demo verificado con mocks (Edge sin ventana, sin errores de consola): Nacional → clic en barra → Instituto → área → profesional → Cambios y errores → carga 2 → Cuadratura.
- Modo api: `config.js` ya trae `apiUrl: 'http://localhost:3000'`; se activa con `?modo=api` en la URL (por defecto `mock`).
- Revisión sin ventana: Edge headless (`msedge --headless=new --virtual-time-budget=6000 --dump-dom http://localhost:8080/#nacional`) y `--enable-logging=stderr` para ver la consola.
- Modo de datos: `?modo=api` en la URL fuerza PostgREST (`config.js`); por defecto es mock.

## Filtros (C-04): cómo funcionan
- Claves del hash: `it`, `area`, `cargo`, `desde`, `hasta` (1 y 12 no se guardan), `tipo` (directa|indirecta|nas). Se muestran en las pantallas con `filtros: true` en `PAGINAS` (router.js).
- Flujo: control → evento `filtros-cambiaron` {pagina, filtros} → router actualiza el hash → la pantalla se redibuja. El router solo mueve el foco al `h1` si cambió de pantalla, no si cambiaron los filtros. Los enlaces del menú de pantallas con filtros arrastran los filtros actuales.
- Exporta `resumenFiltros(f)` y `hayFiltros(f)` (útiles para C-11: imprimir/exportar con los filtros aplicados).
- `v_kpi` y `v_nacional_mes` no admiten it/area/cargo: con esos filtros (o con meses) Nacional deriva tarjetas y línea mensual desde `v_instituto_area_mes`; la «Última carga» sigue viniendo de `v_kpi`. Sin filtros usa las vistas nacionales.
- `tipo` solo afecta al gráfico de horas por área (series visibles y tabla); las atenciones son siempre directas.

## Notas de C-05
- % FOJA agregado = Σ horas_dir / Σ horas_contratadas (ponderado), en la tabla y en los totales.
- Tabulator no ordena con teclado por defecto: `hacerOrdenablePorTeclado` (instituto.js) da `tabindex` a los encabezados y activa Enter/Espacio. Hay además «Ver como tabla simple» (tabla HTML equivalente). Si C-06/C-07 usan Tabulator, reutilizar esa función (conviene moverla a ui.js).
- El área elegida y el selector de métrica no van en el hash (estado local de la pantalla).

## Notas de C-06
- La pantalla pide `v_profesional_mes` completo solo para armar las sugerencias del buscador (con cientos de profesionales en la base real puede ser pesado: si pasa, pedir a Andrés una vista liviana de personas).
- `describirCambio` (profesional.js) convierte los jsonb `antes`/`despues` en texto; si el cambio trae `instituto`, oculta `it`. Los tipos de cambio conocidos (alta, baja, cambio_jornada, cambio_cargo, cambio_it) tienen etiqueta; otros se muestran con el nombre del tipo. C-07 puede reutilizarlo (conviene moverlo a un módulo común).

## Notas de C-08
- `v_cuadratura` solo trae diferencias. N = `config.totalProfesionalesExcel` (471) − personas distintas con diferencia ≠ 0 (si la vista incluyera filas que coinciden, se ignoran).
- % de coincidencia por campo = 1 − diferencias / (471 para campos sin mes, 471×12 para campos mensuales); por mes = 1 − diferencias / (471×5 campos mensuales). Es una aproximación: confirmar con Andrés la base real de comparaciones. Los porcentajes se truncan (99,96 % se ve 99,9 %, nunca 100,0 %) y el eje de los gráficos no parte en 0 (se avisa en la nota).
- Causas conocidas (redondeo, regla_ene_abr, descuento_julio, asignacion_no_calza, atencion_grupal, colacion_contrato) vienen de `docseglas.md` (puntos abiertos); una causa nueva se muestra con su nombre y «Causa todavía sin descripción». Los valores reales de `causa` los define Andrés.

## Accesibilidad (C-10)
- Auditoría: `web\dev\auditoria-a11y.html` corre axe-core (A y AA de WCAG 2.1) sobre cada pantalla en estado normal y con lectura fácil + letra grande, con «Ver datos» abierto. Hay que bajar axe-core 4.10.2 a `web\dev\axe.min.js` (está en .gitignore; la URL está en el comentario del archivo). Resultado final: 0 violaciones. Los chequeos «incompletos» son solo íconos decorativos (aria-hidden).
- Contraste: todos los pares texto/fondo del CSS dan ≥ 4,5:1 (el menor es el estado «ok», 5,5:1); colores de gráficos ≥ 3:1 contra blanco; foco 5,3:1.
- Correcciones hechas: ARIA de Tabulator (`accesibilizarTabulator` en ui.js: zona con scroll como `rowgroup`, orden por teclado), tablas con scroll horizontal enfocables y con nombre (`vigilarDesbordes`), estado «activado» de los botones del encabezado también con «✓», textos de los gráficos más grandes con letra grande (`ampliarTexto`).
- Lectura fácil: cada pantalla llama `lecturaFacil(contenedor, frases)` (js\lectura.js); la caja existe siempre y el CSS la muestra solo con el botón activado. Solo Parámetros queda sin frases hasta C-09.
- No se probó con lector de pantalla real ni con teclado físico: se verificó con axe, el árbol de roles y eventos simulados. Conviene un recorrido manual con Tab y NVDA antes de la demo. Los `ResizeObserver` no se entregan en Edge headless con tiempo virtual (solo afecta a pruebas automáticas).

## Notas para la demo (lo que hace el front en cada minuto de `docs/demo.md`)
- URL: `http://localhost:8080/?modo=api#nacional` (levantar con `.{BS}scripts{BS}servir_web.ps1`). El encabezado muestra «● En vivo: base de datos» o «◌ Datos de prueba (mock)»: confirmar que diga «En vivo» antes de empezar. Si la API falla se muestra un aviso rojo y la pantalla queda vacía; **nunca** se cambia en silencio a datos de prueba.
- 0:00 Nacional: «Última carga» (con hora), dotación, atenciones, meta y FOJA. Anotar los valores antes de cargar `02`.
- 1:00–2:00 tras procesar `02`: botón «Actualizar datos» (o F5). Aparece «Hay una carga nueva» y las tarjetas muestran ▲/▼ con lo que cambió respecto de la carga anterior (se compara por pestaña con la última carga vista; sin filtros). Si se recarga la pestaña con F5 se conserva; si se cierra la pestaña se pierde.
- 2:00–3:00: Cambios abre solo la carga más reciente (cambios y errores con persona, campo, fila y motivo); para ir directo a otra: `?modo=api#cambios?carga=<carga_id>`. Profesional: `#profesional?persona=71555` (jornada 40 → 30 en mayo, marcada en el gráfico) y `#profesional?persona=71146` (traslado, con columna de instituto).
- Teclado: Tab muestra el «Saltar al contenido», el menú y los filtros con foco visible; «Lectura fácil», «Letra grande» e «Imprimir» están en el encabezado.
- Dependencias con la base real: comprobadas el 7-nov con la base local de César (ver «Prueba con la base real»).
- Sin lector de pantalla real ni PDF real verificados: ensayar «Imprimir → Guardar como PDF» y un recorrido con Tab antes de presentar.

## Prueba con la base real (7-nov, base local de César)
- **Back local:** rama `integracion/local` (solo local, NO se sube) = main + `origin/feat/B-07-B-08-cambios` + `origin/feat/B-09-vistas`. PostgreSQL 16 propio en `C:\dev\pgcesar` puerto **5434** (los servicios `postgresql-x64-16/18` de Windows no se tocaron: no tenía la clave de `postgres`), base `planbot_local`, creada con `scripts\instalar_sin_docker.ps1`; PostgREST 12.2.3 (la misma versión del compose) en `C:\tools\postgrest`, puerto 3000, esquema `api`, rol `web_lectura`, CORS `http://localhost:8080`. `.env` local (ignorado por git) con claves aleatorias. Se cargó `01_original` (+ semilla), `02_cambios` (con `detectar_cambios` y `recalcular`) y `03_errores` encima. Respaldo tras 01: `C:\dev\pgcesar\snapshot_01.dump` (`pg_restore`).
- **Control:** `C:\tools\planbot_local.ps1 estado|iniciar|detener` (fuera del repo). Detener a mano: `Get-Process postgrest | Stop-Process` y `& 'C:\Program Files\PostgreSQL\16\bin\pg_ctl.exe' stop -D C:\dev\pgcesar\data -m fast`. PostgREST necesita `C:\Program Files\PostgreSQL\16\bin` en el PATH (libpq.dll). Hace falta `pip install --user openpyxl` para `cargar_buk_prueba.ps1`.
- **Cuadra:** `v_kpi` = 622.271 atenciones, 557.689 meta (con 01 solo: 621.637 y 557.114), 821.427 h, 443 de dotación, FOJA 49,0 %; coincide con la suma de `v_nacional_mes`, `v_instituto_area_mes` y `v_profesional_mes`, y las tarjetas de Nacional muestran esos mismos valores. Las vistas responden en 15–160 ms.
- **Lo que no coincidía con lo supuesto y se corrigió en `web\`:**
  1. Claves de `param.general`: son `meta` (0.9), `jornada_ene_abr` (44) y `jornada_may_dic` (42) (la marca «Jornada 42 h» sale del inicio del último período, mayo). Quedan los nombres antiguos solo como respaldo. Los mocks ya usan las claves reales.
  2. **`area` es la sede, igual que `instituto`** (columna Área del BUK); la especialidad está en `cargo` (15 cargos). Se agregó `js\dimension.js`: si area == instituto, las pantallas agrupan por **cargo** (Nacional «Horas por cargo», Instituto «cargo × mes» con top 5 + «Otros» en el gráfico apilado) y se oculta el filtro Área y el campo Área de la ficha. Si el back cambia `area` a la especialidad, vuelve a agrupar por área sin tocar nada. **Sugerencia para Andrés:** exponer la especialidad (sub-área o `unidad` de param.cargo) en `area`.
  3. `v_parametros_vigentes.valor` es texto; en cargo_distribucion, asignacion_catalogo, calendario_mes y grupal es **JSON en texto** (se interpreta y se muestra `clave: valor · ...`). Tablas reales: param.general, param.cargo_distribucion, param.asignacion_catalogo, param.calendario_mes, param.grupal (325 reglas).
  4. `cargo` puede venir `null` (filas con cargo sin homologar, p. ej. 71146 tras cargar 03): se muestra «Sin cargo». `area` también puede venir nula.
  5. `v_cambios`: tipos reales vistos: alta, baja, cambio_jornada, cambio_cargo, cambio_it (+ cambio_vigencia en el código del back, con etiqueta «Cambio de vigencia»). `antes`/`despues` son objetos con pocas claves: alta `antes: null`; **baja `despues: null`** (se muestra «→ ya no figura»); cambio_it trae solo `{"it": 131}` (se traduce al nombre del instituto con los nombres de `v_instituto_area_mes`); cambio_jornada `{"horas_semanales": 40}`; cambio_cargo `{"cargo": ...}`.
  6. Con 15 institutos el gráfico de metas crece en alto y queda al lado del de cargos.
- **Estado de las demás vistas reales:** `v_errores_carga` trae archivo (carga 5: 5 errores con fila, persona, campo y motivo); `v_cambios` no trae archivo (la carga 4 sale «Archivo no informado»); `v_cuadratura` está vacía (falta `cuadratura()` del back): la pantalla muestra su aviso; no hay RPC de escenarios: «todavía no están disponibles».
- **Observación para el back (no es del front):** `horas_dir + horas_ind + horas_nas` = 705.026 h contra 821.427 contratadas: la diferencia son las ausencias (no se cargan a NAS), así que las barras de horas no suman las contratadas.
- **Verificación:** recorrido completo con `?modo=api` (Nacional, Instituto y sus profesionales, 4 fichas de profesional, Cambios cargas 4 y 5, Parámetros, Cuadratura) sin errores de consola; axe 0 violaciones en las 18 combinaciones también con la base real (`web\dev\auditoria-a11y.html?modo=api`); ESLint del CI sin errores.

## Notas de C-11
- El CSV sale de la tabla HTML que ya está en pantalla (también las de «Ver datos», aunque estén ocultas): lo exportado es lo mismo que se ve, con números es-CL (`1.234,5`); sirve para abrir en Excel en español. No exporta los datos crudos de la vista.
- No se pudo generar/ver un PDF real (no hay poppler); la vista de impresión se revisó emulando las reglas `@media print` en pantalla (ancho A4). Conviene un «Imprimir → Guardar como PDF» manual antes de la demo.

## Notas de C-09 (escenarios: falta definir el contrato con Andrés)
- El front espera dos funciones SQL expuestas por PostgREST; nombres provisorios en `config.rpc` (`rpc/listar_escenarios`, `rpc/decidir_escenario`). Hasta que existan, en modo api la sección de escenarios dice «todavía no están disponibles» y las reglas vigentes funcionan igual.
  - `listar_escenarios()` devuelve filas con: escenario_id, descripcion, parametro, valor_actual, valor_propuesto, estado (pendiente|borrador|aprobado|aplicado|rechazado), creado_por, creado_en, decision_motivo, impacto (jsonb: arreglo de {it, instituto, atenciones_antes, atenciones_despues, meta_antes, meta_despues, diferencia_meta}).
  - `decidir_escenario(escenario_id, decision, motivo)` con decision = 'aprobar' | 'rechazar'; el motivo debe quedar en la auditoría (`planbot.motivo`), que el front no puede fijar por PostgREST.
  - Son funciones nuevas fuera del Contrato 2: requieren PR con etiqueta `contrato` aprobado por Andrés y César.
- En modo mock las decisiones viven solo en memoria (se pierden al recargar). Aprobar en el front solo cambia el estado; aplicar el escenario lo hace Blue Prism (`aplicar_escenario`, P09).
- Lectura fácil y letra grande funcionan en esta pantalla; el diálogo es un `<dialog>` modal nativo (Esc cierra, el foco vuelve al botón).

## Nota sobre el backlog
- Al cerrar C-07 marqué por error D-04, D-05, D-06 y C-01 (son de Codex y Andrés) por reemplazar un bloque de líneas; ya se devolvieron a «[ ]». Quien las termine debe marcarlas.

## API de los módulos (para quien siga)
- `getData(vista, filtros)`: filtros `{it:[], area:[], cargo:[], persona:[], carga:[], desde, hasta}`; cada vista solo aplica los filtros que tiene (tabla `FILTRABLES` en api.js). `leerMock(nombre)` para JSON que no son vistas (escenarios).
- Router: `hashPara(pagina, filtros)`, `irA(pagina, filtros)`, `filtrosDesdeParams`; evento `pagina-cambio` en `document` tras cada render. Cada pantalla es `js\pages\<id>.js` con `render(contenedor, filtros)` (puede ser async); su `h1` lleva `tabindex="-1"` para recibir el foco.
- ui.js: `el`, `avisar`, `cargando`, `mostrarError`, `vacio`, `tarjetaKpi`, `tablaDatos`, `botonVerDatos`, `tarjetaGrafico` (gráfico con aria-label + "Ver datos"; se crea cuando el contenedor tiene tamaño), `opcionBase`, `liberarGraficos` (lo llama el router), `registrarLiberador(fn)` (p. ej. destruir una tabla Tabulator al cambiar de pantalla).

## Errores conocidos / decisiones
- Trabajar en modo mock hasta que B-09 esté en main.
- Supuestos de los mocks (cambiarlos solo regenerando con el script):
  - 15 profesionales (persona_id 6 dígitos ficticios) en 3 institutos (131 Santiago, 81 Concepción, 11 Arica; Arica sin área FI) y 4 áreas/cargos (KI KINESIOLOGO, TO TERAPEUTA OCUPACIONAL, FI MEDICO FISIATRA, ED EDUCADOR). `instituto` va con nombre completo, no la sigla.
  - Todo sale de `v_profesional_mes` (167 filas, hay altas/bajas/cambios): las demás vistas son sumas de ahí. `meta` por persona = floor(atenciones × 0.9); en agregados `meta` es la suma de las metas individuales (puede diferir en pocas unidades de floor(suma × 0.9)).
  - Jornada: desde mayo las horas bajan 4 % (factor 0.96). Febrero tiene vacaciones (pocas semanas hábiles). FOJA por persona 0,51–0,63; agregados ponderados por horas contratadas.
  - `v_kpi`: atenciones_plan = Σ atenciones_dir del año; meta = Σ meta; horas_contratadas = Σ anual; dotacion = personas con fila en diciembre (14; una baja en octubre); foja = Σ horas directas / Σ horas contratadas.
  - Carga 1 (`buk_2026-10.xlsx`): 5 errores. Carga 2: 5 cambios (cambio_cargo, cambio_it, cambio_jornada, baja, alta); `antes`/`despues` son objetos JSON (alta trae `antes: null`). Tipos de cambio inventados: confirmar con Andrés los valores reales de `tipo`.
  - `v_parametros_vigentes.valor` es texto (ej. "0.9"); tablas `param.general|cargo|asignacion|calendario|grupal`.
  - `v_cuadratura`: 30 diferencias de 11 personas; causas: redondeo, regla_ene_abr, descuento_julio, asignacion_no_calza, atencion_grupal, colacion_contrato (los "471" de la tarjeta es constante del front).
  - `escenarios.json` NO es contrato (lo definirá Andrés): escenario_id, descripcion, parametro, valor_actual, valor_propuesto, estado (pendiente|aprobado), creado_por, creado_en, decision_motivo, impacto[] por instituto (atenciones y meta antes/después).
- Hueco resuelto: horas por área (contrato v1.1).
- Hueco abierto (sigue sin resolver en el contrato): `v_cambios` no trae `archivo` ni hay vista de cargas con estado. La pantalla Cambios toma el archivo de `v_errores_carga` (si la carga no tuvo errores muestra «Archivo no informado») y deduce el estado de los conteos (con errores / con cambios / sin novedades). Pedir a Andrés una vista de cargas (carga_id, archivo, tipo, estado, recibido_en, leidas, validas, con_error) o agregar `archivo` a `v_cambios`.
- Nacional lee `meta_gestion`, `mes_cambio_jornada` y `jornada_legal_horas_desde_mayo` de `v_parametros_vigentes` (nada fijo en el código). Si en la base real esas claves se llaman distinto, la tarjeta cae a meta/atenciones y la marca de jornada desaparece: confirmar nombres de clave con Andrés.
