# César · Claude Code (Sonnet) · FRONT — carpeta bothaton

Modelo: Sonnet. Usa modo plan (Shift+Tab) en C-02 y C-09. `/clear` entre historias.
Flujo: pega el ARRANQUE una vez; luego, por cada historia, `/clear` + "Lee AGENTS.md y docs\progreso-front.md." + el prompt de la historia.

## ARRANQUE (primera sesión)

Soy César, del equipo 33 de la Botathon 2026. Programo el FRONT de PlanBot. Lee AGENTS.md, docs\contexto.md, docs\contratos.md (sobre todo el Contrato 3, vistas api.*) y docs\progreso-front.md.
En paralelo trabajan Andrés (base de datos SQL, otro computador) y mi Codex (carpeta ..\bothaton-codex: C# para Blue Prism, bases de prueba, CI, README). Tú SOLO modificas web\ y docs\progreso-front.md (y marcas tus historias en docs\backlog.md). No toques database\, api\, scripts\, data\, tests\, .github\ ni bluePrism\.
Entorno: Windows 11, PowerShell 7, rutas con \. Sin GitHub por ahora: por historia, rama local feat/<ID>, commit Conventional Commits (feat(web): ...), git checkout main y git merge --no-ff feat/<ID>. Sin push ni PR hasta que te avise.
Front: página única estática, HTML + JavaScript con módulos ES, sin framework ni build; ECharts 5 y Tabulator 6 descargados a web\vendor\ (sin depender de internet en la demo); web\js\config.js con { modo: 'mock'|'api', apiUrl: 'http://localhost:3000' }; web\js\api.js con getData(vista, filtros); router por #hash; pantallas en web\js\pages\ (nacional, instituto, profesional, cambios, parametros, cuadratura); barra de filtros común sincronizada con la URL.
Accesible (punto de la rúbrica): lang="es", landmarks, skip link, foco visible, todo con teclado, aria-label en gráficos con botón "Ver datos" (tabla), contraste AA, estados con texto y no solo color, botón "Lectura fácil". Números es-CL (miles con punto, decimales con coma, porcentajes con 1 decimal). Diseño sobrio y profesional, CSS propio con variables, paleta institucional neutra (azules y grises), tipografía del sistema.
Después de cada historia: sirve web\ con `python -m http.server 8080` desde web\, revisa que no haya errores en consola, marca la historia en docs\backlog.md, actualiza docs\progreso-front.md (Hecho / En curso / Siguiente / Errores conocidos), commit y merge, y detente con un resumen de 3 líneas. Si te acercas al límite de uso, actualiza el progreso y haz commit antes de cortar.
Empieza con la historia D-03 (abajo).

## D-03 · Mocks
Crea un JSON por vista en web\mock\ (v_kpi, v_nacional_mes, v_instituto_area_mes, v_profesional_mes, v_cambios, v_errores_carga, v_parametros_vigentes, v_cuadratura) con las columnas EXACTAS del Contrato 3 de docs\contratos.md, como arreglos JSON igual que los devuelve PostgREST. Datos: institutos 131 San, 81 Con, 11 Ari; áreas KI, TO, FI, ED; cargos KINESIOLOGO, TERAPEUTA OCUPACIONAL, MEDICO FISIATRA, EDUCADOR; 12 meses; 15 profesionales con persona_id ficticios de 6 dígitos. Coherencia: meta = floor(atenciones × 0.9); FOJA entre 0.45 y 0.65; atenciones de mayo a diciembre un 4 % menores (jornada 42 h); febrero con menos atenciones (vacaciones). v_kpi debe cuadrar con la suma de v_instituto_area_mes. Incluye 2 cargas en v_errores_carga/v_cambios (una con 5 errores y otra con 5 cambios de tipos distintos) y 30 filas en v_cuadratura con causas variadas. Escribe también web\mock\LEEME.md explicando cada archivo.

## C-02 · Esqueleto (modo plan)
Muéstrame primero el plan de archivos. Crea: web\index.html (lang="es", header con el nombre "PlanBot · Planificación asistencial", nav lateral con Nacional, Instituto, Profesional, Cambios, Parámetros, Cuadratura; main; skip link), web\css\base.css (variables de color, tipografía legible de 16 px, foco visible, layout responsive con grid, tarjetas, tablas), web\js\config.js, web\js\api.js (getData(vista, filtros): modo mock lee web\mock\<vista>.json y filtra en memoria; modo api arma la query PostgREST: it=in.(..), mes=gte.x&mes=lte.y, area=eq.X; maneja errores y devuelve [] con aviso), web\js\router.js (#nacional por defecto, parámetros en el hash), web\js\formato.js (números, porcentajes y fechas es-CL), web\js\ui.js (estados de carga, mensajes de error, componente tarjeta KPI, botón "Ver datos" que convierte una serie en tabla accesible). Descarga ECharts 5 (echarts.min.js) y Tabulator 6 (tabulator.min.js y tabulator.min.css) a web\vendor\ con Invoke-WebRequest desde jsdelivr. Cada página es un módulo con export function render(contenedor, filtros).

## C-03 · Pantalla Nacional
web\js\pages\nacional.js: (1) fila de 6 tarjetas desde v_kpi: atenciones planificadas, meta de gestión (90 %), % FOJA, horas contratadas, dotación, última carga; (2) gráfico de líneas ECharts desde v_nacional_mes: atenciones directas y meta por mes (ene–dic) con una línea vertical en mayo y etiqueta "Jornada 42 h"; (3) barras horizontales de meta anual por instituto (desde v_instituto_area_mes agrupado), ordenadas de mayor a menor, clic navega a #instituto?it=<it>; (4) barras apiladas por área con horas directas, indirectas y NAS. Cada gráfico con aria-label descriptivo, título visible y botón "Ver datos". Gráficos responsivos (resize).

## C-04 · Filtros globales
web\js\filtros.js: barra común arriba del contenido con instituto (selección múltiple), área, cargo, mes desde y hasta, tipo de atención (directa, indirecta, NAS). Opciones cargadas de v_instituto_area_mes. Estado sincronizado con el hash (#pagina?it=131,81&area=KI&desde=1&hasta=12), botón "Limpiar filtros", evento 'filtros-cambiaron' al que se suscriben las páginas. Etiquetas visibles y accesibles por teclado. Aplica los filtros en nacional.js.

## C-05 · Pantalla Instituto
web\js\pages\instituto.js: título con el instituto elegido (o "Todos"); tabla Tabulator área × mes (columnas ene..dic + total) con atenciones directas, meta y FOJA (selector de métrica), ordenable, con fila de totales y exportable; gráfico de meta mensual del instituto; clic en un área muestra abajo la lista de profesionales de esa área (desde v_profesional_mes) con enlace a #profesional?persona=<id>.

## C-06 · Pantalla Profesional
web\js\pages\profesional.js: buscador por persona_id (con sugerencias de los ids existentes); ficha con cargo, área e instituto(s); tabla mes a mes desde v_profesional_mes (horas contratadas, % directo final, atenciones directas, directas + indirectas, meta, FOJA); gráfico de barras mensual de meta; línea de tiempo de cambios desde v_cambios (tipo, mes de vigencia, antes → después, carga). Nunca mostrar nombres ni RUT: solo persona_id.

## C-07 · Pantalla Cambios y errores
web\js\pages\cambios.js: lista de cargas (agrupando v_errores_carga y v_cambios por carga_id) con archivo, cantidad de errores, cantidad de cambios y estado con texto e ícono ("Procesada", "Con errores"); al elegir una carga, dos tablas Tabulator: errores (fila, persona_id, campo, motivo) y cambios (tipo, persona_id, IT, mes de vigencia, antes, después). Resumen arriba: "Esta carga trajo N cambios y M errores".

## CAMBIO A DATOS REALES (cuando Andrés entregue las vistas)
Ya están las vistas reales de Andrés en la base (PostgREST en http://localhost:3000). Cambia web\js\config.js a modo 'api'. Prueba cada pantalla contra la API, corrige diferencias de nombres o tipos (los números pueden venir como texto: conviértelos), y verifica que la pantalla Nacional cuadra con v_kpi. Anota en docs\progreso-front.md cualquier diferencia con el contrato para avisarle a Andrés.

## C-08 · Pantalla Cuadratura
web\js\pages\cuadratura.js: tarjeta grande "N de 471 profesionales coinciden al 100 % con el Excel actual" (calculada desde v_cuadratura); barras de % de coincidencia por campo y por mes; tabla de diferencias (persona_id, campo, mes, Excel, sistema, diferencia, causa) filtrable por causa; texto explicativo corto de cada causa.

## C-10 · Accesibilidad y lectura fácil
Revisa todo web\ contra WCAG 2.1 AA: navegación completa con Tab y Enter, foco visible, orden lógico, aria-label en gráficos y botones de solo ícono, contraste AA (corrige variables de color), estados con texto, tablas con encabezados th y caption. Agrega botón "Lectura fácil" en el header que muestra en cada pantalla un resumen en 3 a 5 frases cortas generado con los datos ("Este mes la meta nacional es 120.000 atenciones. Santiago tiene la meta más alta."). Agrega un botón para aumentar el tamaño de letra. Escribe docs\progreso-front.md con la lista de lo revisado.

## C-09 · Parámetros y simulación (modo plan)
web\js\pages\parametros.js: tablas de reglas vigentes desde v_parametros_vigentes agrupadas por tabla (distribución por cargo y tramo, minutos, asignaciones, calendario, generales) con su versión y fecha; sección "Escenarios": lista de escenarios con impacto antes/después por instituto (en modo mock usa un JSON web\mock\escenarios.json; en modo api la función RPC que defina Andrés, déjalo configurable) y botones Aprobar/Rechazar que abren un diálogo accesible pidiendo motivo. Muéstrame el plan antes.

## C-11 · Exportar e imprimir
Botón "Exportar CSV" en cada tabla visible (Tabulator download) y hoja de estilos @media print que oculte navegación y filtros y muestre título, fecha y filtros aplicados.
