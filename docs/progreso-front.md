# Progreso FRONT (César · Claude Code, Codex de respaldo)
Última actualización: 2026-11-06 · por: Claude Code
Rama actual: main

## Hecho (fusionado en main)
- D-02 extractor (data\extraer.py) y CSV en data\csv
- D-03 mocks: `web\mock\*.json` (8 vistas + escenarios.json), generados con `python web\mock\generar_mocks.py` (semilla fija)

- C-02 esqueleto: `web\index.html`, `css\base.css`, `js\{config,api,router,formato,ui,main}.js`, stubs en `js\pages\`, ECharts 5.6.0 y Tabulator 6.7.1 en `vendor\` (ver `vendor\LEEME.txt`)

## En curso
- —

## Siguiente
- C-03 Nacional (antes: resolver con Andrés el hueco de horas por área), luego C-04 a C-07, C-10, C-09, C-11

## Cómo probar el front
- Servir sin bloquear: `Start-Process -WindowStyle Hidden python -ArgumentList '-m','http.server','8080' -WorkingDirectory web` y verificar con `Invoke-WebRequest http://localhost:8080 -UseBasicParsing`. Detenerlo al terminar.
- Revisión sin ventana: Edge headless (`msedge --headless=new --virtual-time-budget=6000 --dump-dom http://localhost:8080/#nacional`) y `--enable-logging=stderr` para ver la consola.
- Modo de datos: `?modo=api` en la URL fuerza PostgREST (`config.js`); por defecto es mock.

## Filtros (C-04): cómo funcionan
- Claves del hash: `it`, `area`, `cargo`, `desde`, `hasta` (1 y 12 no se guardan), `tipo` (directa|indirecta|nas). Se muestran en las pantallas con `filtros: true` en `PAGINAS` (router.js).
- Flujo: control → evento `filtros-cambiaron` {pagina, filtros} → router actualiza el hash → la pantalla se redibuja. El router solo mueve el foco al `h1` si cambió de pantalla, no si cambiaron los filtros. Los enlaces del menú de pantallas con filtros arrastran los filtros actuales.
- Exporta `resumenFiltros(f)` y `hayFiltros(f)` (útiles para C-11: imprimir/exportar con los filtros aplicados).
- `v_kpi` y `v_nacional_mes` no admiten it/area/cargo: con esos filtros (o con meses) Nacional deriva tarjetas y línea mensual desde `v_instituto_area_mes`; la «Última carga» sigue viniendo de `v_kpi`. Sin filtros usa las vistas nacionales.
- `tipo` solo afecta al gráfico de horas por área (series visibles y tabla); las atenciones son siempre directas.

## API de los módulos (para quien siga)
- `getData(vista, filtros)`: filtros `{it:[], area:[], cargo:[], persona:[], carga:[], desde, hasta}`; cada vista solo aplica los filtros que tiene (tabla `FILTRABLES` en api.js). `leerMock(nombre)` para JSON que no son vistas (escenarios).
- Router: `hashPara(pagina, filtros)`, `irA(pagina, filtros)`, `filtrosDesdeParams`; evento `pagina-cambio` en `document` tras cada render. Cada pantalla es `js\pages\<id>.js` con `render(contenedor, filtros)` (puede ser async); su `h1` lleva `tabindex="-1"` para recibir el foco.
- ui.js: `el`, `avisar`, `cargando`, `mostrarError`, `vacio`, `tarjetaKpi`, `tablaDatos`, `botonVerDatos`, `tarjetaGrafico` (gráfico con aria-label + "Ver datos"; se crea cuando el contenedor tiene tamaño), `opcionBase`, `liberarGraficos` (lo llama el router).

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
- Huecos del Contrato 3 detectados (consultar con Andrés antes de C-03/C-07, no los cambiamos):
  1. C-03 pide horas directas/indirectas/NAS por **área**, pero `v_nacional_mes` no trae área y `v_instituto_area_mes` no trae horas.
  2. `v_cambios` no trae `archivo`: una carga sin errores no tiene nombre de archivo disponible.
