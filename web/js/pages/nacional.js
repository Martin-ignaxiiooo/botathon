// Pantalla Nacional (C-03): tarjetas KPI, evolución mensual, meta por instituto y horas por área.
import { el, tarjetaKpi, tarjetaGrafico, opcionBase, vacio } from '../ui.js';
import { getData } from '../api.js';
import { hashPara, irA } from '../router.js';
import { num, pct, fecha, fechaHora, nombreMes, nombreArea } from '../formato.js';

const COLORES_HORAS = ['#124a82', '#2f80c9', '#7b8794']; // directas, indirectas, NAS

const sumar = (filas, campo) => filas.reduce((t, f) => t + Number(f[campo] || 0), 0);

/** Suma `campos` agrupando por `clave` y devuelve [{clave, ...sumas}]. */
function agrupar(filas, clave, campos) {
  const mapa = new Map();
  for (const f of filas) {
    const k = f[clave];
    if (!mapa.has(k)) mapa.set(k, { [clave]: k, ...Object.fromEntries(campos.map((c) => [c, 0])) });
    const acc = mapa.get(k);
    campos.forEach((c) => { acc[c] += Number(f[c] || 0); });
  }
  return [...mapa.values()];
}

export async function render(contenedor, filtros) {
  const [kpis, porMes, porInstArea, parametros] = await Promise.all([
    getData('v_kpi', filtros),
    getData('v_nacional_mes', filtros),
    getData('v_instituto_area_mes', filtros),
    getData('v_parametros_vigentes'),
  ]);

  contenedor.append(el('h1', { tabindex: '-1' }, 'Panorama nacional'));
  const kpi = kpis[0];
  if (!kpi && !porMes.length && !porInstArea.length) {
    contenedor.append(el('div', {}));
    return vacio(contenedor.lastChild, 'No hay datos para mostrar. Revise los filtros o cargue un archivo de BUK.');
  }

  // Constantes de negocio: se leen de los parámetros vigentes, no se escriben en el código.
  const param = (clave) => parametros.find((p) => p.clave === clave)?.valor;
  const metaPct = Number(param('meta_gestion')) || (kpi?.atenciones_plan ? kpi.meta / kpi.atenciones_plan : null);
  const mesJornada = Number(param('mes_cambio_jornada')) || null;
  const horasJornada = Number(param('jornada_legal_horas_desde_mayo')) || null;

  if (kpi) contenedor.append(tarjetas(kpi, metaPct));

  const graficos = el('div', { class: 'grilla grilla-graficos' });
  contenedor.append(graficos);
  if (porMes.length) graficos.append(graficoMensual(porMes, mesJornada, horasJornada));
  if (porInstArea.length) {
    graficos.append(graficoInstitutos(porInstArea, filtros), graficoAreas(porInstArea));
  }
}

function tarjetas(kpi, metaPct) {
  return el('div', { class: 'grilla grilla-kpi', role: 'group', 'aria-label': 'Indicadores nacionales' },
    tarjetaKpi({ titulo: 'Atenciones planificadas', valor: num(kpi.atenciones_plan), detalle: 'Atenciones directas del año' }),
    tarjetaKpi({
      titulo: metaPct ? `Meta de gestión (${pct(metaPct, 0)})` : 'Meta de gestión',
      valor: num(kpi.meta), detalle: 'Atenciones que se espera cumplir en el año',
    }),
    tarjetaKpi({ titulo: '% FOJA', valor: pct(kpi.foja), detalle: 'Horas disponibles para atención directa / horas contratadas' }),
    tarjetaKpi({ titulo: 'Horas contratadas', valor: num(kpi.horas_contratadas), detalle: 'Suma de las horas del año' }),
    tarjetaKpi({ titulo: 'Dotación', valor: num(kpi.dotacion), detalle: 'Profesionales con contrato en el último mes' }),
    tarjetaKpi({
      titulo: 'Última carga', valor: fecha(kpi.ultima_carga), compacta: true,
      detalle: `Último archivo de BUK procesado (${fechaHora(kpi.ultima_carga).split(', ')[1]} h)`,
    }));
}

function graficoMensual(filas, mesJornada, horasJornada) {
  const datos = [...filas].sort((a, b) => a.mes - b.mes);
  const meses = datos.map((f) => nombreMes(f.mes, true));
  const indiceCambio = datos.findIndex((f) => f.mes === mesJornada);
  const etiquetaCambio = horasJornada ? `Jornada ${num(horasJornada)} h` : 'Cambio de jornada';

  const maximo = datos.reduce((a, b) => (b.atenciones_dir > a.atenciones_dir ? b : a));
  const minimo = datos.reduce((a, b) => (b.atenciones_dir < a.atenciones_dir ? b : a));

  const opcion = opcionBase({
    tooltip: { trigger: 'axis', valueFormatter: (v) => num(v) },
    legend: { top: 0 },
    grid: { left: 8, right: 24, top: 64, bottom: 8, containLabel: true },
    xAxis: { type: 'category', data: meses, boundaryGap: false },
    yAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) } },
    series: [
      {
        name: 'Atenciones directas', type: 'line', data: datos.map((f) => f.atenciones_dir), symbolSize: 7,
        lineStyle: { width: 3 },
        markLine: indiceCambio >= 0 ? {
          symbol: 'none', silent: true,
          lineStyle: { color: '#3e4c59', type: 'solid', width: 2 },
          label: { formatter: etiquetaCambio, color: '#1f2933', fontWeight: 600, position: 'end', rotate: 0, distance: 6 },
          data: [{ xAxis: indiceCambio }],
        } : undefined,
      },
      {
        name: 'Meta de gestión', type: 'line', data: datos.map((f) => f.meta), symbol: 'diamond', symbolSize: 8,
        lineStyle: { width: 3, type: 'dashed' }, itemStyle: { color: '#7b8794' },
      },
    ],
  });

  return tarjetaGrafico({
    titulo: 'Atenciones y meta por mes',
    clase: 'ancho-completo',
    ariaLabel: `Gráfico de líneas con las atenciones directas planificadas y la meta de gestión de cada mes. `
      + `El mes con más atenciones es ${nombreMes(maximo.mes)} con ${num(maximo.atenciones_dir)} y el con menos es `
      + `${nombreMes(minimo.mes)} con ${num(minimo.atenciones_dir)}.`
      + (indiceCambio >= 0 ? ` Una línea vertical marca ${nombreMes(mesJornada)}: ${etiquetaCambio.toLowerCase()}.` : ''),
    nota: indiceCambio >= 0 ? `La línea vertical marca el mes en que cambia la jornada (${nombreMes(mesJornada)}).` : null,
    opcion,
    tabla: {
      caption: 'Atenciones directas y meta de gestión por mes',
      columnas: [
        { titulo: 'Mes', campo: 'mes', formato: (m) => nombreMes(m) },
        { titulo: 'Atenciones directas', campo: 'atenciones_dir', numerica: true, formato: num },
        { titulo: 'Meta de gestión', campo: 'meta', numerica: true, formato: num },
      ],
      filas: datos,
    },
  }).elemento;
}

function graficoInstitutos(filas, filtros) {
  const porIt = agrupar(filas, 'it', ['meta']).map((r) => ({
    ...r, instituto: filas.find((f) => f.it === r.it).instituto,
  })).sort((a, b) => b.meta - a.meta);
  const total = sumar(porIt, 'meta');

  const opcion = opcionBase({
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => num(v) },
    grid: { left: 8, right: 56, top: 8, bottom: 8, containLabel: true },
    xAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) } },
    yAxis: { type: 'category', inverse: true, data: porIt.map((r) => r.instituto) },
    series: [{
      name: 'Meta anual', type: 'bar', data: porIt.map((r) => r.meta), barMaxWidth: 36,
      label: { show: true, position: 'right', formatter: ({ value }) => num(value) },
      cursor: 'pointer',
    }],
  });

  return tarjetaGrafico({
    titulo: 'Meta anual por instituto',
    ariaLabel: `Gráfico de barras horizontales con la meta anual de cada instituto, de mayor a menor. `
      + porIt.map((r) => `${r.instituto}: ${num(r.meta)}`).join('; ') + `. Total: ${num(total)}.`,
    nota: 'Haga clic en una barra, o use «Ver datos», para abrir el detalle del instituto.',
    opcion,
    alClic: (e) => irA('instituto', { ...filtros, it: [porIt[e.dataIndex].it] }),
    tabla: {
      caption: 'Meta anual por instituto, de mayor a menor',
      columnas: [
        { titulo: 'Instituto', campo: 'instituto' },
        { titulo: 'Meta anual', campo: 'meta', numerica: true, formato: num },
        {
          titulo: 'Detalle',
          valor: (r) => r,
          formato: (r) => el('a', { href: hashPara('instituto', { ...filtros, it: [r.it] }) }, `Ver ${r.instituto}`),
        },
      ],
      filas: porIt,
    },
  }).elemento;
}

function graficoAreas(filas) {
  const campos = ['horas_dir', 'horas_ind', 'horas_nas'];
  const porArea = agrupar(filas, 'area', campos).sort((a, b) =>
    campos.reduce((t, c) => t + b[c], 0) - campos.reduce((t, c) => t + a[c], 0));
  const nombres = porArea.map((r) => nombreArea(r.area));
  const series = [['Horas directas', 'horas_dir'], ['Horas indirectas', 'horas_ind'], ['Horas NAS (no asistenciales)', 'horas_nas']];

  const opcion = opcionBase({
    color: COLORES_HORAS,
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => `${num(v)} h` },
    legend: { top: 0 },
    grid: { left: 8, right: 8, top: 40, bottom: 8, containLabel: true },
    xAxis: { type: 'category', data: nombres, axisLabel: { interval: 0, width: 90, overflow: 'break' } },
    yAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) } },
    series: series.map(([nombre, campo]) => ({
      name: nombre, type: 'bar', stack: 'horas', data: porArea.map((r) => Math.round(r[campo])),
      itemStyle: { borderColor: '#ffffff', borderWidth: 1 }, barMaxWidth: 64,
    })),
  });

  return tarjetaGrafico({
    titulo: 'Horas por área',
    ariaLabel: 'Gráfico de barras apiladas con las horas directas, indirectas y no asistenciales (NAS) de cada área en el año. '
      + porArea.map((r) => `${nombreArea(r.area)}: ${num(r.horas_dir)} directas, ${num(r.horas_ind)} indirectas y ${num(r.horas_nas)} NAS`).join('; ') + '.',
    opcion,
    tabla: {
      caption: 'Horas del año por área, según tipo de hora',
      columnas: [
        { titulo: 'Área', campo: 'area', formato: nombreArea },
        { titulo: 'Horas directas', campo: 'horas_dir', numerica: true, formato: num },
        { titulo: 'Horas indirectas', campo: 'horas_ind', numerica: true, formato: num },
        { titulo: 'Horas NAS', campo: 'horas_nas', numerica: true, formato: num },
        { titulo: 'Total', valor: (r) => campos.reduce((t, c) => t + r[c], 0), numerica: true, formato: num },
      ],
      filas: porArea,
    },
  }).elemento;
}
