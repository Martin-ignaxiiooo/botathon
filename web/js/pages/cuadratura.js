// Pantalla Cuadratura (C-08): cuánto coincide el sistema con el Excel actual.
// v_cuadratura (api.cuadratura()) trae solo las diferencias (persona × campo × mes) con su causa probable.
// Los porcentajes se calculan contra las filas del plan (v_profesional_mes): una comparación por persona-instituto
// para cada campo sin mes y una por persona-instituto y mes para cada campo mensual. Igual que en el back, las
// filas que el Excel trae y el sistema no (sistema nulo: otro instituto, sin dotación) no cuentan como diferencia
// de cálculo. Con esa regla el titular reproduce el valor de api.cuadratura() (95,55 % en la base de demo).
import config from '../config.js';
import { el, tablaDatos, tarjetaGrafico, opcionBase, vacio, idUnico } from '../ui.js';
import { getData } from '../api.js';
import { hashPara } from '../router.js';
import { num, pct, nombreMes, MESES_CORTOS } from '../formato.js';
import { lecturaFacil } from '../lectura.js';

const MESES = Array.from({ length: 12 }, (_, i) => i + 1);

// Campos de esperado.csv (Contrato 1): `mensual` indica si se compara mes a mes.
const CAMPOS = {
  pct_dir_final: { texto: '% directo final', tipo: 'pct' },
  pct_ind_final: { texto: '% indirecto final', tipo: 'pct' },
  ate_dir_semana: { texto: 'Atenciones directas por semana', tipo: 'num' },
  ate_ind_semana: { texto: 'Atenciones indirectas por semana', tipo: 'num' },
  ate_semana_total: { texto: 'Atenciones por semana (total)', tipo: 'num' },
  horas_semana_dic: { texto: 'Horas semanales en diciembre', tipo: 'num' },
  prom_pond_horas: { texto: 'Promedio ponderado de horas', tipo: 'dec' },
  semhab: { texto: 'Semanas hábiles', tipo: 'dec', mensual: true },
  plan_ate_dir: { texto: 'Atenciones directas planificadas', tipo: 'num', mensual: true },
  plan_ate_dir_ind: { texto: 'Atenciones directas + indirectas', tipo: 'num', mensual: true },
  meta: { texto: 'Meta del mes', tipo: 'num', mensual: true },
  meta_dir_ind: { texto: 'Meta directas + indirectas', tipo: 'num', mensual: true },
};
const nombreCampo = (c) => CAMPOS[c]?.texto ?? c;
const CAMPOS_MENSUALES = Object.keys(CAMPOS).filter((c) => CAMPOS[c].mensual).length;

// Causas probables de calc.cuadratura, con las descripciones oficiales de Andrés. La base usa la primera que
// aplica, en este orden; las pantallas las muestran en el mismo orden.
const CAUSAS = {
  diferencia_explicada: { texto: 'Diferencia explicada', explicacion: 'Diferencia ya analizada y aceptada tal cual (hoy solo 134744/11: el Excel dice 15 atenciones semanales y la fórmula da 14).' },
  ajuste_individual: { texto: 'Ajuste individual', explicacion: 'El Excel tiene un ajuste hecho a mano para esta persona que el reporte de RR.HH. no trae.' },
  periodo_ene_abr: { texto: 'Enero a abril', explicacion: 'De enero a abril el Excel usa un cálculo semanal distinto; el sistema aplica la regla vigente.' },
  dias_adicionales: { texto: 'Días adicionales', explicacion: 'El Excel cuenta otras semanas hábiles (días adicionales, vacaciones o feriados distintos).' },
  multi_it: { texto: 'Más de un instituto', explicacion: 'La persona trabaja en más de un instituto, o el Excel la tiene en un instituto distinto al del reporte.' },
  grupal: { texto: 'Atención grupal', explicacion: 'La persona hace atención grupal y el Excel la calcula de otra forma.' },
  otra: { texto: 'Sin causa conocida', explicacion: 'Sin causa conocida todavía; incluye personas del Excel que no vienen en el reporte.' },
};
const ORDEN_CAUSAS = Object.keys(CAUSAS);
/** Posición de una causa en el orden oficial; las desconocidas van al final. */
const posCausa = (c) => { const i = ORDEN_CAUSAS.indexOf(c); return i < 0 ? ORDEN_CAUSAS.length : i; };
const causaInfo = (c) => CAUSAS[c] ?? { texto: c ?? 'Sin causa', explicacion: 'Causa todavía sin descripción.' };

/** Porcentaje que nunca redondea hacia 100 %: 99,96 % se muestra como 99,9 %. */
const pctCoincidencia = (fraccion) => pct(Math.floor(fraccion * 1000 + 1e-9) / 1000, 1);
/** Igual, con 2 decimales (para el titular): 0,95553 -> "95,55 %". */
const pctCoincidencia2 = (fraccion) => `${num(Math.floor(fraccion * 10000 + 1e-9) / 100, 2)} %`;
const MES_INICIO_COMPARACION = 5; // el Excel guarda el cálculo semanal solo de mayo a diciembre
const tieneSistema = (f) => f.sistema !== null && f.sistema !== undefined;

function formatoValor(campo, v) {
  if (v === null || v === undefined) return '—';
  const tipo = CAMPOS[campo]?.tipo;
  if (tipo === 'pct') return pct(v, 1);
  if (tipo === 'dec') return num(v, 1);
  return num(v, Number.isInteger(Number(v)) ? 0 : 1);
}
function formatoDiferencia(campo, d) {
  if (d === null || d === undefined) return '—'; // el sistema no tiene la fila: no hay diferencia numérica
  const n = Number(d);
  const signo = n > 0 ? '+' : n < 0 ? '−' : '';
  const abs = Math.abs(n);
  if (CAMPOS[campo]?.tipo === 'pct') return `${signo}${num(abs * 100, 1)} pp`;
  return `${signo}${num(abs, Number.isInteger(abs) ? 0 : 1)}`;
}

/** Mínimo del eje: deja ver diferencias pequeñas (se avisa en la nota del gráfico). */
function minimoEje(porcentajes) {
  const minimo = Math.min(...porcentajes);
  return minimo >= 100 ? 0 : Math.max(0, Math.floor(minimo) - 1);
}

/** Filas del plan que sirven de base de comparación. */
function baseComparacion(plan, totalExcel) {
  const porMes = new Map();
  const pares = new Set();
  for (const f of plan) {
    porMes.set(f.mes, (porMes.get(f.mes) ?? 0) + 1);
    pares.add(`${f.persona_id}|${f.it}`);
  }
  // Sin plan (no debería pasar) se usa el total de profesionales del Excel como respaldo
  return { filas: plan.length || totalExcel * 12, pares: pares.size || totalExcel, porMes, plan };
}

/** % de atenciones directas planificadas de mayo a diciembre que coinciden con el Excel. */
function coincidenciaPrincipal(dif, base) {
  const filas = base.plan.filter((f) => f.mes >= MES_INICIO_COMPARACION).length;
  if (!filas) return null;
  const diferencias = dif.filter((f) => f.campo === 'plan_ate_dir' && f.mes >= MES_INICIO_COMPARACION && tieneSistema(f)).length;
  return { fraccion: 1 - diferencias / filas, diferencias, filas };
}

export async function render(contenedor) {
  const [todas, plan] = await Promise.all([getData('v_cuadratura', {}), getData('v_profesional_mes', {})]);
  // Una fila es diferencia salvo que `diferencia` sea exactamente 0 (null = el sistema no tiene la fila)
  const dif = todas.filter((f) => f.diferencia === null || f.diferencia === undefined || Number(f.diferencia) !== 0);
  const total = config.totalProfesionalesExcel;

  contenedor.append(el('h1', { tabindex: '-1' }, 'Cuadratura con el Excel actual'));
  if (!todas.length) {
    const caja = el('div');
    contenedor.append(caja);
    return vacio(caja, 'No hay datos de cuadratura. Cargue el resultado esperado (esperado.csv) y ejecute la cuadratura.');
  }

  const base = baseComparacion(plan, total);
  const principal = coincidenciaPrincipal(dif, base);
  const conDiferencias = new Set(dif.map((f) => f.persona_id)).size;
  const coinciden = Math.max(0, total - conDiferencias);
  const porCausa = new Map();
  dif.forEach((d) => porCausa.set(d.causa, (porCausa.get(d.causa) ?? 0) + 1));
  const causaComun = [...porCausa].sort((a, b) => b[1] - a[1])[0];
  lecturaFacil(contenedor, [
    principal ? `${pctCoincidencia2(principal.fraccion)} de las atenciones de mayo a diciembre coinciden con el Excel.` : null,
    conDiferencias ? `${num(conDiferencias)} profesionales tienen alguna diferencia; ${num(coinciden)} de ${num(total)} no tienen ninguna.` : 'No hay diferencias.',
    causaComun ? `La causa más común es «${causaInfo(causaComun[0]).texto}»: ${num(causaComun[1])} casos.` : null,
    'Cada diferencia trae una causa probable, explicada más abajo.',
    'Puedes filtrar la tabla de diferencias por causa.',
  ]);
  contenedor.append(tarjetaGrande({ principal, coinciden, total, conDiferencias, nDif: dif.length }));

  const graficos = el('div', { class: 'grilla grilla-graficos' });
  graficos.append(graficoPorCampo(dif, base).elemento, graficoPorMes(dif, base).elemento);
  contenedor.append(graficos);

  contenedor.append(seccionCausas(dif), seccionTabla(dif));
}

function tarjetaGrande({ principal, coinciden, total, conDiferencias, nDif }) {
  const todoOk = conDiferencias === 0;
  return el('section', { class: 'tarjeta tarjeta-grande', 'aria-labelledby': 'titulo-cuadratura' },
    el('h2', { id: 'titulo-cuadratura', class: 'solo-lectores' }, 'Resultado de la cuadratura'),
    principal
      ? el('p', { class: 'cifra-grande' },
        el('span', { class: 'cifra-n' }, pctCoincidencia2(principal.fraccion)),
        ' de las atenciones planificadas de mayo a diciembre coinciden con el Excel actual')
      : el('p', { class: 'cifra-grande' },
        el('span', { class: 'cifra-n' }, num(coinciden)), ` de ${num(total)} profesionales coinciden al 100 % con el Excel actual`),
    el('p', { class: 'tarjeta-detalle' }, principal
      ? `Se compara persona por persona y mes por mes (${num(principal.filas)} comparaciones, ${num(principal.diferencias)} con diferencia); cada diferencia tiene una causa probable más abajo.`
      : `${todoOk ? 'No hay diferencias.' : `${num(conDiferencias)} profesionales tienen diferencias (${num(nDif)} en total).`}`),
    principal ? el('p', { class: 'tarjeta-detalle' },
      todoOk ? 'Ningún profesional tiene diferencias.'
        : `${num(coinciden)} de ${num(total)} profesionales no tienen ninguna diferencia en ningún campo; ${num(conDiferencias)} tienen alguna (${num(nDif)} diferencias en total).`) : null,
    el('p', { class: `estado-texto ${todoOk ? 'estado-ok' : 'estado-alerta'}` },
      el('span', { 'aria-hidden': 'true' }, todoOk ? '✓' : '!'), todoOk ? 'Todo coincide' : 'Hay diferencias por revisar'));
}

function graficoPorCampo(todasDif, base) {
  const dif = todasDif.filter(tieneSistema);
  const sinSistema = todasDif.length - dif.length;
  const filas = Object.keys(CAMPOS).map((campo) => {
    const n = dif.filter((f) => f.campo === campo).length;
    const comparaciones = CAMPOS[campo].mensual ? base.filas : base.pares;
    return { campo, nombre: nombreCampo(campo), diferencias: n, fraccion: 1 - n / comparaciones };
  }).sort((a, b) => a.fraccion - b.fraccion || a.nombre.localeCompare(b.nombre, 'es'));
  const min = minimoEje(filas.map((f) => f.fraccion * 100));

  const opcion = opcionBase({
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => pctCoincidencia(v / 100) },
    grid: { left: 8, right: 64, top: 8, bottom: 8, containLabel: true },
    xAxis: { type: 'value', min, max: 100, minInterval: 1, splitNumber: 4, axisLabel: { formatter: (v) => `${num(v)} %` } },
    yAxis: { type: 'category', inverse: true, data: filas.map((f) => f.nombre), axisLabel: { width: 190, overflow: 'break' } },
    series: [{
      name: '% de coincidencia', type: 'bar', barMaxWidth: 22, data: filas.map((f) => f.fraccion * 100),
      label: { show: true, position: 'right', formatter: ({ value }) => pctCoincidencia(value / 100) },
    }],
  });
  const peor = filas[0];
  return tarjetaGrafico({
    titulo: 'Coincidencia por campo', alto: 420,
    ariaLabel: `Gráfico de barras con el porcentaje de coincidencia con el Excel en cada uno de los ${filas.length} campos. `
      + (peor.diferencias ? `El campo con menor coincidencia es «${peor.nombre}» con ${pctCoincidencia(peor.fraccion)}.` : 'Todos los campos coinciden al 100 %.'),
    nota: `El eje empieza en ${num(min)} % para que se vean las diferencias pequeñas. Base: ${num(base.pares)} profesionales-instituto por campo y ${num(base.filas)} filas mes a mes en los campos mensuales.${sinSistema ? ` No cuenta las ${num(sinSistema)} filas que el Excel trae y el sistema no.` : ''}`,
    opcion,
    tabla: {
      caption: 'Coincidencia con el Excel por campo',
      columnas: [
        { titulo: 'Campo', campo: 'nombre' },
        { titulo: 'Diferencias', campo: 'diferencias', numerica: true, formato: num },
        { titulo: '% de coincidencia', campo: 'fraccion', numerica: true, formato: pctCoincidencia },
      ],
      filas,
    },
  });
}

function graficoPorMes(todasDif, base) {
  const dif = todasDif.filter(tieneSistema);
  const filas = MESES.map((mes) => {
    const n = dif.filter((f) => f.mes === mes).length;
    const comparaciones = (base.porMes.get(mes) ?? 0) * CAMPOS_MENSUALES;
    return { mes, diferencias: n, fraccion: comparaciones ? 1 - n / comparaciones : 1 };
  });
  const min = minimoEje(filas.map((f) => f.fraccion * 100));
  const opcion = opcionBase({
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => pctCoincidencia(v / 100) },
    grid: { left: 8, right: 8, top: 56, bottom: 8, containLabel: true },
    xAxis: { type: 'category', data: MESES_CORTOS },
    yAxis: { type: 'value', min, max: 100, minInterval: 1, splitNumber: 4, axisLabel: { formatter: (v) => `${num(v)} %` } },
    series: [{
      name: '% de coincidencia', type: 'bar', barMaxWidth: 32, data: filas.map((f) => f.fraccion * 100),
      label: {
        show: true, position: 'top', rotate: 90, align: 'left', verticalAlign: 'middle', distance: 6, fontSize: 11,
        formatter: ({ value }) => pctCoincidencia(value / 100),
      },
    }],
  });
  const peor = filas.reduce((a, b) => (b.fraccion < a.fraccion ? b : a));
  return tarjetaGrafico({
    titulo: 'Coincidencia por mes', alto: 420,
    ariaLabel: 'Gráfico de barras con el porcentaje de coincidencia con el Excel en cada mes, para los campos mensuales. '
      + (peor.diferencias ? `El mes con menor coincidencia es ${nombreMes(peor.mes)} con ${pctCoincidencia(peor.fraccion)}.` : 'Todos los meses coinciden al 100 %.'),
    nota: `Solo campos mensuales (${CAMPOS_MENSUALES}). El eje empieza en ${num(min)} %. Base: las filas del plan de cada mes por cada campo mensual.`,
    opcion,
    tabla: {
      caption: 'Coincidencia con el Excel por mes',
      columnas: [
        { titulo: 'Mes', campo: 'mes', formato: (m) => nombreMes(m) },
        { titulo: 'Diferencias', campo: 'diferencias', numerica: true, formato: num },
        { titulo: '% de coincidencia', campo: 'fraccion', numerica: true, formato: pctCoincidencia },
      ],
      filas,
    },
  });
}

function seccionCausas(dif) {
  const conteo = new Map();
  dif.forEach((f) => conteo.set(f.causa, (conteo.get(f.causa) ?? 0) + 1));
  const extra = [...conteo.keys()].filter((c) => !(c in CAUSAS));
  const causas = [...ORDEN_CAUSAS, ...extra].map((c) => [c, conteo.get(c) ?? 0]);
  return el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-causas' },
    el('h2', { id: 'titulo-causas' }, '¿Por qué hay diferencias?'),
    el('p', { class: 'nota-grafico' }, 'A cada diferencia se le asigna la primera causa que aplica, en este orden.'),
    dif.length
      ? el('dl', { class: 'causas' }, causas.map(([causa, n]) => el('div', {},
        el('dt', {}, `${causaInfo(causa).texto} (${num(n)})`), el('dd', {}, causaInfo(causa).explicacion))))
      : el('p', { class: 'estado-vacio' }, '✓ No hay diferencias que explicar.'));
}

function seccionTabla(dif) {
  const conteo = new Map();
  dif.forEach((f) => conteo.set(f.causa, (conteo.get(f.causa) ?? 0) + 1));
  const idSelect = idUnico('causa');
  const select = el('select', { id: idSelect },
    el('option', { value: '' }, `Todas (${num(dif.length)})`),
    [...conteo].sort((a, b) => posCausa(a[0]) - posCausa(b[0])).map(([causa, n]) =>
      el('option', { value: causa ?? '' , 'data-causa': 'x' }, `${causaInfo(causa).texto} (${num(n)})`)));
  const estado = el('p', { class: 'nota-grafico', role: 'status' });
  const zonaTabla = el('div', { class: 'tabla-scroll' });
  const zonaMas = el('div', { class: 'acciones' });
  const PASO = 100; // con la base real hay más de mil diferencias: se muestran de a 100
  let limite = PASO;

  const dibujar = () => {
    const causa = select.value;
    const todas = [...(causa ? dif.filter((f) => (f.causa ?? '') === causa) : dif)]
      .sort((a, b) => posCausa(a.causa) - posCausa(b.causa) || a.persona_id - b.persona_id || (a.mes ?? 0) - (b.mes ?? 0));
    const filas = todas.slice(0, limite);
    estado.textContent = `Mostrando ${num(filas.length)} de ${num(todas.length)} diferencias${causa ? ` de esta causa (${num(dif.length)} en total)` : ''}.`;
    zonaMas.replaceChildren(...(todas.length > limite
      ? [el('button', { type: 'button', onclick: () => { limite += PASO; dibujar(); } }, `Mostrar ${num(Math.min(PASO, todas.length - limite))} más`)]
      : []));
    zonaTabla.replaceChildren(filas.length ? tablaDatos({
      caption: `Diferencias entre el Excel y el sistema${causa ? ` · causa: ${causaInfo(causa).texto}` : ''}${todas.length > filas.length ? ` (primeras ${num(filas.length)} de ${num(todas.length)})` : ''}`,
      columnas: [
        { titulo: 'Profesional', valor: (f) => f.persona_id, formato: (id) => el('a', { href: hashPara('profesional', { persona: [id] }) }, String(id)) },
        { titulo: 'Campo', campo: 'campo', formato: nombreCampo },
        { titulo: 'Mes', campo: 'mes', formato: (m) => (m ? nombreMes(m) : '—') },
        { titulo: 'Excel', valor: (f) => f, numerica: true, formato: (f) => formatoValor(f.campo, f.excel) },
        { titulo: 'Sistema', valor: (f) => f, numerica: true, formato: (f) => formatoValor(f.campo, f.sistema) },
        { titulo: 'Diferencia', valor: (f) => f, numerica: true, formato: (f) => formatoDiferencia(f.campo, f.diferencia) },
        { titulo: 'Causa', campo: 'causa', formato: (c) => causaInfo(c).texto },
      ],
      filas,
    }) : el('p', { class: 'estado-vacio' }, 'No hay diferencias para esta causa.'));
  };
  select.addEventListener('change', () => { limite = PASO; dibujar(); });
  dibujar();

  return el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-diferencias' },
    el('h2', { id: 'titulo-diferencias' }, 'Diferencias'),
    el('div', { class: 'campo campo-filtro' }, el('label', { for: idSelect }, 'Filtrar por causa'), select),
    estado, zonaTabla, zonaMas);
}
