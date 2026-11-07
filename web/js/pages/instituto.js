// Pantalla Instituto (C-05): tabla área × mes (Tabulator) con selector de métrica, meta mensual por área
// y, al elegir un área, sus profesionales con enlace a la ficha.
import {
  el, tablaDatos, botonVerDatos, tarjetaGrafico, opcionBase, vacio, registrarLiberador, idUnico, accesibilizarTabulator,
} from '../ui.js';
import { getData } from '../api.js';
import { hashPara } from '../router.js';
import { num, pct, nombreMes, nombreArea, MESES_CORTOS } from '../formato.js';
import { resumenFiltros } from '../filtros.js';
import { lecturaFacil } from '../lectura.js';

const COLORES_AREA = ['#124a82', '#2f80c9', '#7b8794', '#b26b00', '#1b6e3c'];
const METRICAS = [
  { id: 'atenciones', texto: 'Atenciones directas', clave: 'ate', formato: num },
  { id: 'meta', texto: 'Meta de gestión', clave: 'meta', formato: num },
  { id: 'foja', texto: '% FOJA', formato: (v) => pct(v, 1) },
];
const MESES = Array.from({ length: 12 }, (_, i) => i + 1);

const nuevoAcc = () => ({ ate: 0, meta: 0, hd: 0, hc: 0 });
function sumarFila(acc, f) {
  acc.ate += Number(f.atenciones_dir || 0);
  acc.meta += Number(f.meta || 0);
  acc.hd += Number(f.horas_dir || 0);
  acc.hc += Number(f.horas_contratadas || 0);
}
/** Valor de una métrica; el % FOJA se pondera por horas contratadas. null si no hay datos. */
function valorMetrica(acc, metrica) {
  if (!acc) return null;
  if (metrica.id === 'foja') return acc.hc ? acc.hd / acc.hc : null;
  return acc[metrica.clave];
}

/** area -> {area, meses: [acc|null x12], total: acc} y totales generales por mes. */
function armarMatriz(filas) {
  const porArea = new Map();
  const totalMes = Array(12).fill(null);
  const totalGeneral = nuevoAcc();
  for (const f of filas) {
    if (!porArea.has(f.area)) porArea.set(f.area, { area: f.area, meses: Array(12).fill(null), total: nuevoAcc() });
    const a = porArea.get(f.area);
    const i = f.mes - 1;
    a.meses[i] ??= nuevoAcc();
    totalMes[i] ??= nuevoAcc();
    sumarFila(a.meses[i], f);
    sumarFila(a.total, f);
    sumarFila(totalMes[i], f);
    sumarFila(totalGeneral, f);
  }
  return { areas: [...porArea.values()].sort((x, y) => y.total.meta - x.total.meta), totalMes, totalGeneral };
}

function tituloInstituto(filtros, filas) {
  if (!filtros.it.length) return 'Todos';
  const nombres = filtros.it.map((id) => filas.find((f) => f.it === id)?.instituto ?? `IT ${id}`);
  return nombres.length > 3 ? `${nombres.length} institutos`
    : nombres.join(', ').replace(/, ([^,]*)$/, ' y $1');
}

export async function render(contenedor, filtros) {
  const filas = await getData('v_instituto_area_mes', filtros);
  const titulo = tituloInstituto(filtros, filas);
  contenedor.append(el('h1', { tabindex: '-1' }, `Instituto: ${titulo}`));
  if (!filas.length) {
    const caja = el('div');
    contenedor.append(caja);
    return vacio(caja, 'No hay datos para los filtros elegidos. Use «Limpiar filtros» para volver a ver todo.');
  }
  const { areas, totalMes, totalGeneral } = armarMatriz(filas);
  const nombreInstituto = new Map(filas.map((f) => [f.it, f.instituto]));

  const mayorMes = MESES.filter((m) => totalMes[m - 1]).reduce((a, b) => (totalMes[b - 1].meta > totalMes[a - 1].meta ? b : a));
  lecturaFacil(contenedor, [
    `Estás viendo: ${titulo}.`,
    `La meta del período es ${num(totalGeneral.meta)} atenciones.`,
    areas.length > 1 ? `El área con más meta es ${nombreArea(areas[0].area)}: ${num(areas[0].total.meta)}.` : null,
    `El mes con más meta es ${nombreMes(mayorMes)}.`,
    totalGeneral.hc ? `El % FOJA es ${pct(totalGeneral.hd / totalGeneral.hc)}.` : null,
  ]);

  // ---- Gráfico de meta mensual (apilado por área) ----
  contenedor.append(graficoMetaMensual(areas, totalMes).elemento);

  // ---- Tabla área × mes ----
  const zonaTabla = el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-tabla' });
  const tituloTabla = el('h2', { id: 'titulo-tabla' });
  const selector = selectorMetrica((metrica) => dibujarTabla(metrica));
  const contenedorTabla = el('div', { class: 'tabla-tabulator' });
  const zonaSimple = el('div', { class: 'datos-grafico' });
  const botonSimple = botonVerDatos(zonaSimple, 'Ver como tabla simple');
  const nota = el('p', { class: 'nota-grafico' },
    'Haga clic en un encabezado para ordenar (con teclado: Tab hasta el encabezado y Enter). ',
    'Elija un área, con clic o con Enter sobre su nombre, para ver sus profesionales.');
  zonaTabla.append(el('div', { class: 'cab-grafico' }, tituloTabla, botonSimple), selector.elemento, nota, contenedorTabla, zonaSimple);
  contenedor.append(zonaTabla);

  const zonaProfesionales = el('section', { class: 'tarjeta seccion', 'aria-live': 'polite' });
  zonaProfesionales.hidden = true;
  contenedor.append(zonaProfesionales);

  let tabla = null;
  let areaActiva = null;

  function dibujarTabla(metrica) {
    tabla?.destroy();
    tituloTabla.textContent = `Detalle por área y mes: ${metrica.texto}`;
    const fmt = (v) => (v === null || v === undefined ? '—' : metrica.formato(v));
    const datos = areas.map((a) => ({
      area: a.area,
      nombre: nombreArea(a.area),
      ...Object.fromEntries(MESES.map((m) => [`m${m}`, valorMetrica(a.meses[m - 1], metrica)])),
      total: valorMetrica(a.total, metrica),
    }));
    const totales = Object.fromEntries(MESES.map((m) => [`m${m}`, valorMetrica(totalMes[m - 1], metrica)]));
    totales.total = valorMetrica(totalGeneral, metrica);
    const columnaNumerica = (campo, titulo) => ({
      title: titulo, field: campo, sorter: 'number', hozAlign: 'right', headerHozAlign: 'right', minWidth: 78,
      headerSortStartingDir: 'desc',
      formatter: (c) => fmt(c.getValue()),
      bottomCalc: () => totales[campo], bottomCalcFormatter: (c) => fmt(c.getValue()),
    });
    tabla = new Tabulator(contenedorTabla, {
      data: datos,
      layout: 'fitDataFill',
      columns: [
        {
          title: 'Área', field: 'nombre', frozen: true, minWidth: 210, sorter: 'string',
          formatter: (c) => {
            const boton = el('button', { type: 'button', class: 'boton-area', 'aria-pressed': 'false' }, c.getValue());
            return boton;
          },
          bottomCalc: () => 'Total', bottomCalcFormatter: (c) => c.getValue(),
        },
        ...MESES.map((m) => columnaNumerica(`m${m}`, MESES_CORTOS[m - 1])),
        { ...columnaNumerica('total', 'Total'), minWidth: 100 },
      ],
    });
    tabla.on('rowClick', (e, fila) => seleccionarArea(fila.getData().area));
    tabla.on('tableBuilt', () => {
      contenedorTabla.setAttribute('aria-label', `${tituloTabla.textContent}. Tabla ordenable.`);
      accesibilizarTabulator(contenedorTabla);
      marcarActiva();
    });
    tabla.on('renderComplete', marcarActiva);

    // Tabla simple equivalente (accesible)
    zonaSimple.replaceChildren(tablaDatos({
      caption: tituloTabla.textContent,
      columnas: [
        { titulo: 'Área', campo: 'nombre' },
        ...MESES.map((m) => ({ titulo: nombreMes(m, true), campo: `m${m}`, numerica: true, formato: fmt })),
        { titulo: 'Total', campo: 'total', numerica: true, formato: fmt },
      ],
      filas: [...datos, { nombre: 'Total', ...totales }],
    }));
  }

  function marcarActiva() {
    contenedorTabla.querySelectorAll('.tabulator-row').forEach((fila) => {
      const boton = fila.querySelector('.boton-area');
      const activa = boton && boton.textContent === (areaActiva ? nombreArea(areaActiva) : null);
      fila.classList.toggle('fila-activa', Boolean(activa));
      boton?.setAttribute('aria-pressed', String(Boolean(activa)));
    });
  }

  async function seleccionarArea(area) {
    areaActiva = areaActiva === area ? null : area;
    marcarActiva();
    if (!areaActiva) { zonaProfesionales.hidden = true; return; }
    zonaProfesionales.hidden = false;
    zonaProfesionales.replaceChildren(el('p', { role: 'status' }, 'Cargando profesionales…'));
    const profesionales = await getData('v_profesional_mes', { ...filtros, area: [area] });
    if (areaActiva !== area) return; // el usuario eligió otra área mientras cargaba
    dibujarProfesionales(zonaProfesionales, area, profesionales, nombreInstituto, filtros, () => seleccionarArea(area));
  }

  dibujarTabla(METRICAS[0]);
  registrarLiberador(() => { tabla?.destroy(); tabla = null; });
}

function selectorMetrica(alElegir) {
  const nombre = idUnico('metrica');
  const radios = METRICAS.map((m, i) => {
    const id = `${nombre}-${m.id}`;
    const input = el('input', { type: 'radio', name: nombre, id, value: m.id, checked: i === 0 });
    input.addEventListener('change', () => alElegir(m));
    return el('label', { class: 'opcion-radio', for: id }, input, m.texto);
  });
  return {
    elemento: el('fieldset', { class: 'selector-metrica' }, el('legend', {}, 'Métrica de la tabla'), radios),
  };
}

function graficoMetaMensual(areas, totalMes) {
  const meses = MESES.map((m) => MESES_CORTOS[m - 1]);
  const metaDe = (a, i) => a.meses[i]?.meta ?? 0;
  const opcion = opcionBase({
    color: COLORES_AREA,
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => num(v) },
    legend: { top: 0 },
    grid: { left: 8, right: 8, top: 40, bottom: 8, containLabel: true },
    xAxis: { type: 'category', data: meses },
    yAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) } },
    series: areas.map((a) => ({
      name: nombreArea(a.area), type: 'bar', stack: 'meta', data: MESES.map((m, i) => metaDe(a, i)),
      itemStyle: { borderColor: '#ffffff', borderWidth: 1 }, barMaxWidth: 48,
    })),
  });
  const conDatos = MESES.filter((m) => totalMes[m - 1]);
  const maximo = conDatos.reduce((a, b) => (totalMes[b - 1].meta > totalMes[a - 1].meta ? b : a), conDatos[0]);
  return tarjetaGrafico({
    titulo: 'Meta de gestión por mes',
    ariaLabel: `Gráfico de barras apiladas con la meta de gestión de cada mes, dividida por área. `
      + `El mes con mayor meta es ${nombreMes(maximo)} con ${num(totalMes[maximo - 1].meta)} atenciones.`,
    opcion,
    tabla: {
      caption: 'Meta de gestión por mes y área',
      columnas: [
        { titulo: 'Mes', campo: 'mes', formato: (m) => nombreMes(m) },
        ...areas.map((a) => ({ titulo: nombreArea(a.area), valor: (r) => metaDe(a, r.mes - 1), numerica: true, formato: num })),
        { titulo: 'Total', valor: (r) => totalMes[r.mes - 1]?.meta ?? 0, numerica: true, formato: num },
      ],
      filas: MESES.map((mes) => ({ mes })),
    },
  });
}

function dibujarProfesionales(zona, area, filas, nombreInstituto, filtros, alCerrar) {
  const porPersona = new Map();
  for (const f of filas) {
    if (!porPersona.has(f.persona_id)) {
      porPersona.set(f.persona_id, { persona_id: f.persona_id, its: new Set(), cargos: new Set(), acc: nuevoAcc(), pctPond: 0 });
    }
    const p = porPersona.get(f.persona_id);
    p.its.add(f.it);
    p.cargos.add(f.cargo);
    sumarFila(p.acc, { atenciones_dir: f.atenciones_dir, meta: f.meta, horas_dir: f.foja * f.horas_contratadas, horas_contratadas: f.horas_contratadas });
    p.pctPond += f.pct_dir_final * f.horas_contratadas;
  }
  const lista = [...porPersona.values()].sort((a, b) => b.acc.meta - a.acc.meta);
  const encabezado = el('h2', { tabindex: '-1' }, `Profesionales de ${nombreArea(area)}`);
  const cerrar = el('button', { type: 'button', onclick: alCerrar }, 'Ocultar profesionales');
  zona.replaceChildren(
    el('div', { class: 'cab-grafico' }, encabezado, cerrar),
    lista.length
      ? tablaDatos({
        caption: `Profesionales de ${nombreArea(area)} · ${resumenFiltros({ ...filtros, area: [] })} (${lista.length})`,
        columnas: [
          { titulo: 'Profesional', valor: (p) => p, formato: (p) => el('a', { href: hashPara('profesional', { persona: [p.persona_id] }) }, String(p.persona_id)) },
          { titulo: 'Instituto', valor: (p) => [...p.its].map((it) => nombreInstituto.get(it) ?? `IT ${it}`).join(', ') },
          { titulo: 'Cargo', valor: (p) => [...p.cargos].join(', ') },
          { titulo: 'Horas contratadas', valor: (p) => p.acc.hc, numerica: true, formato: num },
          { titulo: '% directo final', valor: (p) => (p.acc.hc ? p.pctPond / p.acc.hc : null), numerica: true, formato: (v) => pct(v, 1) },
          { titulo: 'Atenciones directas', valor: (p) => p.acc.ate, numerica: true, formato: num },
          { titulo: 'Meta', valor: (p) => p.acc.meta, numerica: true, formato: num },
          { titulo: '% FOJA', valor: (p) => valorMetrica(p.acc, METRICAS[2]), numerica: true, formato: (v) => pct(v, 1) },
        ],
        filas: lista,
      })
      : el('p', { class: 'estado-vacio' }, 'No hay profesionales para esta área con los filtros elegidos.'));
  encabezado.focus(); // lleva el foco a la nueva sección para quien navega con teclado o lector de pantalla
}
