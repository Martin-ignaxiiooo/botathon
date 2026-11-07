// Pantalla Cuadratura (C-08): cuánto coincide el sistema con el Excel actual.
// v_cuadratura trae solo diferencias (persona × campo × mes). Los porcentajes se calculan sobre el total de
// profesionales del Excel (config.totalProfesionalesExcel): una comparación por profesional para cada campo
// sin mes y una por profesional y mes para cada campo mensual.
import config from '../config.js';
import { el, tablaDatos, tarjetaGrafico, opcionBase, vacio, idUnico } from '../ui.js';
import { getData } from '../api.js';
import { hashPara } from '../router.js';
import { num, pct, nombreMes, MESES_CORTOS } from '../formato.js';

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

// Causas conocidas (puntos abiertos de docs/reglas.md) con una explicación corta.
const CAUSAS = {
  redondeo: { texto: 'Redondeo', explicacion: 'El Excel y el sistema difieren en una unidad por cómo se redondea hacia abajo el resultado.' },
  regla_ene_abr: { texto: 'Regla de enero a abril', explicacion: 'El Excel solo guarda el cálculo semanal de mayo a diciembre; enero a abril se calcula con las horas de la jornada de ese período y la regla exacta sigue abierta.' },
  descuento_julio: { texto: 'Descuento de julio', explicacion: 'En el Excel julio descuenta menos días que agosto a diciembre; hay que confirmar la regla con los mentores.' },
  asignacion_no_calza: { texto: 'Asignaciones que no calzan', explicacion: 'El % no asistencial con asignaciones no coincide, posiblemente por cambios de jornada durante el año.' },
  atencion_grupal: { texto: 'Atención grupal', explicacion: 'La fórmula de atención grupal (ED, AS, UTAC, UEDA, ULAB) depende del % grupal y de los pacientes por grupo según Santiago/Concepción u otros institutos.' },
  colacion_contrato: { texto: 'Colación en contrato', explicacion: 'El beneficio de colación de 15 minutos (0,25 h por día) está en 0 para algunos cargos en el Excel.' },
};
const causaInfo = (c) => CAUSAS[c] ?? { texto: c ?? 'Sin causa', explicacion: 'Causa todavía sin descripción.' };

/** Porcentaje que nunca redondea hacia 100 %: 99,96 % se muestra como 99,9 %. */
const pctCoincidencia = (fraccion) => pct(Math.floor(fraccion * 1000 + 1e-9) / 1000, 1);

function formatoValor(campo, v) {
  if (v === null || v === undefined) return '—';
  const tipo = CAMPOS[campo]?.tipo;
  if (tipo === 'pct') return pct(v, 1);
  if (tipo === 'dec') return num(v, 1);
  return num(v, Number.isInteger(Number(v)) ? 0 : 1);
}
function formatoDiferencia(campo, d) {
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

export async function render(contenedor) {
  const todas = await getData('v_cuadratura', {});
  const dif = todas.filter((f) => Number(f.diferencia) !== 0); // por si la vista incluye filas que sí coinciden
  const total = config.totalProfesionalesExcel;

  contenedor.append(el('h1', { tabindex: '-1' }, 'Cuadratura con el Excel actual'));
  if (!todas.length) {
    const caja = el('div');
    contenedor.append(caja);
    return vacio(caja, 'No hay datos de cuadratura. Cargue el resultado esperado (esperado.csv) y ejecute la cuadratura.');
  }

  const conDiferencias = new Set(dif.map((f) => f.persona_id)).size;
  const coinciden = Math.max(0, total - conDiferencias);
  contenedor.append(tarjetaGrande(coinciden, total, conDiferencias, dif.length));

  const graficos = el('div', { class: 'grilla grilla-graficos' });
  graficos.append(graficoPorCampo(dif, total).elemento, graficoPorMes(dif, total).elemento);
  contenedor.append(graficos);

  contenedor.append(seccionCausas(dif), seccionTabla(dif));
}

function tarjetaGrande(coinciden, total, conDiferencias, nDif) {
  const todoOk = conDiferencias === 0;
  return el('section', { class: 'tarjeta tarjeta-grande', 'aria-labelledby': 'titulo-cuadratura' },
    el('h2', { id: 'titulo-cuadratura', class: 'solo-lectores' }, 'Resultado de la cuadratura'),
    el('p', { class: 'cifra-grande' },
      el('span', { class: 'cifra-n' }, num(coinciden)), ` de ${num(total)} profesionales coinciden al 100 % con el Excel actual`),
    el('p', { class: 'tarjeta-detalle' },
      `${pctCoincidencia(coinciden / total)} de los profesionales. ${todoOk
        ? 'No hay diferencias.'
        : `${num(conDiferencias)} ${conDiferencias === 1 ? 'profesional tiene' : 'profesionales tienen'} diferencias (${num(nDif)} en total).`}`),
    el('p', { class: `estado-texto ${todoOk ? 'estado-ok' : 'estado-alerta'}` },
      el('span', { 'aria-hidden': 'true' }, todoOk ? '✓' : '!'), todoOk ? 'Todo coincide' : 'Hay diferencias por revisar'));
}

function graficoPorCampo(dif, total) {
  const filas = Object.keys(CAMPOS).map((campo) => {
    const n = dif.filter((f) => f.campo === campo).length;
    const comparaciones = total * (CAMPOS[campo].mensual ? 12 : 1);
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
    nota: `El eje empieza en ${num(min)} % para que se vean las diferencias pequeñas. Base: ${num(total)} profesionales por campo (y por mes en los campos mensuales).`,
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

function graficoPorMes(dif, total) {
  const filas = MESES.map((mes) => {
    const n = dif.filter((f) => f.mes === mes).length;
    return { mes, diferencias: n, fraccion: 1 - n / (total * CAMPOS_MENSUALES) };
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
    nota: `Solo campos mensuales (${CAMPOS_MENSUALES}). El eje empieza en ${num(min)} %. Base: ${num(total)} profesionales por campo y mes.`,
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
  const causas = [...conteo].sort((a, b) => b[1] - a[1]);
  return el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-causas' },
    el('h2', { id: 'titulo-causas' }, '¿Por qué hay diferencias?'),
    causas.length
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
    [...conteo].sort((a, b) => b[1] - a[1]).map(([causa, n]) =>
      el('option', { value: causa ?? '' , 'data-causa': 'x' }, `${causaInfo(causa).texto} (${num(n)})`)));
  const estado = el('p', { class: 'nota-grafico', role: 'status' });
  const zonaTabla = el('div', { class: 'tabla-scroll' });

  const dibujar = () => {
    const causa = select.value;
    const filas = [...(causa ? dif.filter((f) => (f.causa ?? '') === causa) : dif)]
      .sort((a, b) => String(a.causa).localeCompare(String(b.causa)) || a.persona_id - b.persona_id || (a.mes ?? 0) - (b.mes ?? 0));
    estado.textContent = `Mostrando ${num(filas.length)} de ${num(dif.length)} diferencias.`;
    zonaTabla.replaceChildren(filas.length ? tablaDatos({
      caption: `Diferencias entre el Excel y el sistema${causa ? ` · causa: ${causaInfo(causa).texto}` : ''}`,
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
  select.addEventListener('change', dibujar);
  dibujar();

  return el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-diferencias' },
    el('h2', { id: 'titulo-diferencias' }, 'Diferencias'),
    el('div', { class: 'campo campo-filtro' }, el('label', { for: idSelect }, 'Filtrar por causa'), select),
    estado, zonaTabla);
}
