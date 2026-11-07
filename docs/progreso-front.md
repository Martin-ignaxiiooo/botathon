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

## En curso
- —

## Siguiente
- C-08 Cuadratura, luego C-10, C-09, C-11

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

## Notas de C-05
- % FOJA agregado = Σ horas_dir / Σ horas_contratadas (ponderado), en la tabla y en los totales.
- Tabulator no ordena con teclado por defecto: `hacerOrdenablePorTeclado` (instituto.js) da `tabindex` a los encabezados y activa Enter/Espacio. Hay además «Ver como tabla simple» (tabla HTML equivalente). Si C-06/C-07 usan Tabulator, reutilizar esa función (conviene moverla a ui.js).
- El área elegida y el selector de métrica no van en el hash (estado local de la pantalla).

## Notas de C-06
- La pantalla pide `v_profesional_mes` completo solo para armar las sugerencias del buscador (con cientos de profesionales en la base real puede ser pesado: si pasa, pedir a Andrés una vista liviana de personas).
- `describirCambio` (profesional.js) convierte los jsonb `antes`/`despues` en texto; si el cambio trae `instituto`, oculta `it`. Los tipos de cambio conocidos (alta, baja, cambio_jornada, cambio_cargo, cambio_it) tienen etiqueta; otros se muestran con el nombre del tipo. C-07 puede reutilizarlo (conviene moverlo a un módulo común).

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
