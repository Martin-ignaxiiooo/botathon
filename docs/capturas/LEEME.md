# Capturas para la presentación

Capturas del dashboard a **alta resolución (escala 2: 2880 px de ancho)**, tomadas el 7-nov-2026 con Edge sin ventana contra la **base real local** (PostgreSQL 16 + PostgREST, vistas `api.*` de Andrés) salvo la 09, que usa datos de prueba. Solo se ven `persona_id`, nunca nombres ni RUT.

| Archivo | Qué muestra | Estado de los datos |
|---|---|---|
| `01-nacional.png` | Panorama nacional: tarjetas, atenciones y meta por mes con «Jornada 42 h», meta por instituto y horas por cargo con «Ausencias y feriados» | Base real tras cargar `01_original` y `02_cambios` (622.271 atenciones, 557.689 de meta, 49,0 % FOJA, 443 de dotación) |
| `02-nacional-efecto-carga-02.png` | Igual, con el efecto de la carga 02 (▲ +634 atenciones, ▲ +575 de meta, ▲ +306,4 horas) | Se parte de los valores que tenía la base tras `01` (621.637 / 557.114 / 821.120,7 h) como «carga anterior» |
| `03-instituto-santiago.png` | Instituto Santiago: meta por mes apilada por cargo y tabla cargo × mes con totales | Base real (01 + 02) |
| `03b-instituto-santiago-profesionales.png` | Lo mismo, eligiendo un cargo para ver sus profesionales con enlace a la ficha | Base real (01 + 02) |
| `04-profesional-71555-cambio-jornada.png` | Ficha, meta mensual con la marca «Cambio de jornada» (mayo, 40 → 30 h), línea de tiempo de cambios y tabla mes a mes | Base real (01 + 02) |
| `05-profesional-71146-traslado.png` | Profesional trasladado de Santiago a Puerto Montt en julio | Base real (01 + 02) |
| `06-cambios-carga-02.png` | Cambios y errores de la carga de `02_cambios`: los 5 cambios (cargo, alta, jornada, baja, instituto) con antes y después | Base real, carga 16 |
| `07-errores-carga-03.png` | Cambios y errores de la carga de `03_errores`: los 5 errores con fila, profesional, campo y motivo | Base real, carga 17 (cargada después de las demás capturas) |
| `08-parametros-reglas-vigentes.png` | Reglas vigentes por tabla (325 reglas); abajo, «escenarios todavía no disponibles» | Base real |
| `09-parametros-escenario-dialogo-datos-de-prueba.png` | Escenario con su impacto antes/después y el diálogo accesible de Rechazar con motivo | **Datos de prueba (mock)**: la base real aún no tiene las funciones SQL de escenarios (el encabezado dice «Datos de prueba») |
| `10-cuadratura.png` | Cuadratura con el Excel: **95,55 %** de las atenciones de mayo a diciembre coinciden, coincidencia por campo y mes, causas y diferencias | Base real tras `01` y `SELECT api.cuadratura();`, tomada **antes** de cargar `02` (la cuadratura se calculó sobre el estado de `01`) |
| `11-vista-impresion-nacional.png` | Vista de impresión de Nacional (ancho A4, sin menú ni botones, con título, fecha y filtros) | **Emulada** aplicando las reglas `@media print` en pantalla; no es un PDF real |

Los números de carga (16 y 17) son los de la base local de César; en la demo serán otros.

## Cómo repetirlas

1. Levantar el back (PostgreSQL + PostgREST en :3000) y la web: `.\scripts\servir_web.ps1`.
2. `.\web\dev\capturar.ps1 -Nombre 01-nacional -Ruta '#nacional'` (opciones: `-Modo api|mock`, `-Paso ninguno|efecto|profesionales|dialogo|impresion`, `-Ancho`, `-Alto`, `-Prev '<json del KPI anterior>'`). Mide el alto de la pantalla y captura a escala 2 en esta carpeta. La página auxiliar es `web\dev\captura.html`.
3. Para el efecto de la carga 02: guardar `v_kpi` tras cargar `01`, cargar `02` (con `detectar_cambios` y `recalcular`) y pasar ese JSON en `-Prev`.
