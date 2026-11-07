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

## En curso
- —

## Siguiente
- C-11 Exportar CSV e imprimir

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
