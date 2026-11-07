// Pantalla Profesional (C-06): buscador por persona_id, ficha, tabla mes a mes, meta mensual y cambios.
// Solo se muestra persona_id: nunca nombres ni RUT.
import { el, tarjetaKpi, tablaDatos, tarjetaGrafico, opcionBase, idUnico } from '../ui.js';
import { getData } from '../api.js';
import { irA } from '../router.js';
import { num, pct, fecha, nombreMes, nombreArea } from '../formato.js';
import { cargoLegible, tipoCambio, describirCambio } from '../textoCambios.js';
import { lecturaFacil, plural } from '../lectura.js';

const MESES = Array.from({ length: 12 }, (_, i) => i + 1);
const rangoMeses = (meses) => (meses.length === 1 || meses[0] === meses.at(-1)
  ? nombreMes(meses[0]) : `${nombreMes(meses[0])} a ${nombreMes(meses.at(-1))}`);

export async function render(contenedor, filtros) {
  const persona = filtros.persona?.[0] ?? null;
  contenedor.append(el('h1', { tabindex: '-1' }, persona ? `Profesional ${persona}` : 'Profesional'));

  const [todos, institutos] = await Promise.all([
    getData('v_profesional_mes', {}), getData('v_instituto_area_mes', {}),
  ]);
  const nombreInstituto = new Map(institutos.map((f) => [f.it, f.instituto]));
  contenedor.append(buscador(todos, nombreInstituto, persona));

  if (persona === null) {
    lecturaFacil(contenedor, [
      'Aquí puedes buscar a un profesional por su número de ID.',
      'Escribe el número o elígelo de la lista.',
      'Solo se muestran números de ID, nunca nombres.',
    ]);
    contenedor.append(el('p', { class: 'estado estado-vacio' },
      'Escriba el ID de un profesional (solo números) o elíjalo de la lista para ver su ficha.'));
    return;
  }

  const [filas, cambios] = await Promise.all([
    getData('v_profesional_mes', { persona: [persona] }),
    getData('v_cambios', { persona: [persona] }),
  ]);
  if (!filas.length) {
    contenedor.append(el('p', { class: 'estado estado-vacio', role: 'status' },
      `No hay datos de planificación para el profesional ${persona}. Revise el ID.`));
    if (cambios.length) contenedor.append(lineaDeTiempo(cambios));
    return;
  }

  filas.sort((x, y) => x.mes - y.mes || x.it - y.it);
  const t = totales(filas);
  const mesMayor = MESES.filter((m) => filas.some((f) => f.mes === m))
    .reduce((a, b) => (sumaMeta(filas, b) > sumaMeta(filas, a) ? b : a));
  const ultimo = filas.at(-1);
  lecturaFacil(contenedor, [
    `Este es el profesional ${persona}.`,
    `Trabaja en ${nombreInstituto.get(ultimo.it) ?? `IT ${ultimo.it}`} como ${cargoLegible(ultimo.cargo)}.`,
    `Su meta del año es ${num(t.meta)} atenciones.`,
    `Su mes con más meta es ${nombreMes(mesMayor)}.`,
    cambios.length
      ? `Tuvo ${plural(cambios.length, 'cambio', 'cambios')} este año: ${[...cambios].sort((a, b) => a.mes_vigencia - b.mes_vigencia)
        .map((c) => `${tipoCambio(c.tipo).texto.toLowerCase()} en ${nombreMes(c.mes_vigencia)}`).join(', ')}.`
      : 'No tuvo cambios este año.',
  ]);
  contenedor.append(ficha(filas, nombreInstituto));
  contenedor.append(tarjetasResumen(filas));
  const rejilla = el('div', { class: 'grilla grilla-graficos' });
  rejilla.append(graficoMeta(persona, filas, cambios).elemento);
  rejilla.append(lineaDeTiempo(cambios));
  contenedor.append(rejilla);
  contenedor.append(tablaMensual(persona, filas, nombreInstituto));
}

// ---------- Buscador con sugerencias ----------
function buscador(todos, nombreInstituto, actual) {
  const info = new Map();
  for (const f of todos) info.set(f.persona_id, f); // la última fila de cada persona sirve de pista
  const ids = [...info.keys()].sort((a, b) => a - b);
  const idInput = idUnico('persona');
  const idLista = idUnico('personas');
  const idError = idUnico('error');

  const input = el('input', {
    type: 'search', id: idInput, list: idLista, inputmode: 'numeric', autocomplete: 'off',
    placeholder: 'Ej.: 104512', 'aria-describedby': idError, value: actual ?? '',
  });
  const lista = el('datalist', { id: idLista }, ids.map((id) => {
    const f = info.get(id);
    return el('option', { value: String(id), label: `${nombreInstituto.get(f.it) ?? `IT ${f.it}`} · ${cargoLegible(f.cargo)}` });
  }));
  const error = el('p', { id: idError, class: 'error-campo', role: 'alert' });

  const form = el('form', { class: 'buscador', role: 'search', 'aria-label': 'Buscar profesional' },
    el('div', { class: 'campo' }, el('label', { for: idInput }, 'ID del profesional'), input, lista),
    el('button', { type: 'submit', class: 'boton-primario' }, 'Buscar'),
    error);
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const texto = input.value.trim();
    if (!/^\d+$/.test(texto)) {
      error.textContent = 'Escriba solo números, por ejemplo 104512.';
      input.setAttribute('aria-invalid', 'true');
      input.focus();
      return;
    }
    error.textContent = '';
    input.removeAttribute('aria-invalid');
    irA('profesional', { persona: [Number(texto)] });
  });
  return form;
}

// ---------- Ficha ----------
/** Tramos consecutivos con el mismo instituto, cargo y área. */
function tramos(filas) {
  const out = [];
  for (const f of filas) {
    const ultimo = out.at(-1);
    if (ultimo && ultimo.it === f.it && ultimo.cargo === f.cargo && ultimo.area === f.area) ultimo.meses.push(f.mes);
    else out.push({ it: f.it, cargo: f.cargo, area: f.area, meses: [f.mes] });
  }
  return out;
}

function ficha(filas, nombreInstituto) {
  const lista = (valores) => [...new Set(valores)].join(', ');
  const inst = (it) => nombreInstituto.get(it) ?? `IT ${it}`;
  const ultimo = filas.at(-1);
  const segmentos = tramos(filas);
  const mesesConDatos = [...new Set(filas.map((f) => f.mes))].sort((a, b) => a - b);

  const dl = el('dl', { class: 'ficha-datos' },
    el('div', {}, el('dt', {}, 'Cargo'), el('dd', {}, lista(filas.map((f) => cargoLegible(f.cargo))))),
    el('div', {}, el('dt', {}, 'Área'), el('dd', {}, lista(filas.map((f) => nombreArea(f.area))))),
    el('div', {}, el('dt', {}, filas.some((f) => f.it !== ultimo.it) ? 'Institutos' : 'Instituto'),
      el('dd', {}, lista(filas.map((f) => inst(f.it))))),
    el('div', {}, el('dt', {}, 'Meses con planificación'), el('dd', {}, `${mesesConDatos.length} de 12 (${rangoMeses(mesesConDatos)})`)));

  const ficha = el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-ficha' },
    el('h2', { id: 'titulo-ficha' }, 'Ficha'), dl);
  if (segmentos.length > 1) {
    ficha.append(el('h3', {}, 'Trayectoria durante el año'),
      el('ul', { class: 'trayectoria' }, segmentos.map((s) => el('li', {},
        el('strong', {}, `${rangoMeses(s.meses)}: `),
        `${inst(s.it)} · ${cargoLegible(s.cargo)} · ${nombreArea(s.area)}`))));
  }
  return ficha;
}

const sumaMeta = (filas, mes) => filas.filter((f) => f.mes === mes).reduce((s, f) => s + f.meta, 0);

function totales(filas) {
  const t = { hc: 0, hd: 0, ate: 0, ateInd: 0, meta: 0, pctPond: 0 };
  for (const f of filas) {
    t.hc += f.horas_contratadas;
    t.hd += f.foja * f.horas_contratadas;
    t.ate += f.atenciones_dir;
    t.ateInd += f.atenciones_dir_ind;
    t.meta += f.meta;
    t.pctPond += f.pct_dir_final * f.horas_contratadas;
  }
  return { ...t, foja: t.hc ? t.hd / t.hc : null, pctDir: t.hc ? t.pctPond / t.hc : null };
}

function tarjetasResumen(filas) {
  const t = totales(filas);
  return el('div', { class: 'grilla grilla-kpi', role: 'group', 'aria-label': 'Resumen del año' },
    tarjetaKpi({ titulo: 'Atenciones directas', valor: num(t.ate), detalle: 'Suma de los meses con planificación' }),
    tarjetaKpi({ titulo: 'Meta de gestión', valor: num(t.meta), detalle: 'Atenciones que se espera cumplir' }),
    tarjetaKpi({ titulo: '% FOJA', valor: pct(t.foja), detalle: 'Ponderado por horas contratadas' }),
    tarjetaKpi({ titulo: 'Horas contratadas', valor: num(t.hc), detalle: 'Suma de los meses con planificación' }));
}

// ---------- Gráfico de meta mensual ----------
function graficoMeta(persona, filas, cambios) {
  const metaMes = MESES.map((m) => filas.filter((f) => f.mes === m).reduce((s, f) => s + f.meta, 0));
  const hayDato = MESES.map((m) => filas.some((f) => f.mes === m));
  const marcas = cambios.filter((c) => c.mes_vigencia >= 1 && c.mes_vigencia <= 12)
    .map((c) => ({ xAxis: c.mes_vigencia - 1, label: { formatter: tipoCambio(c.tipo).texto } }));

  const opcion = opcionBase({
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => num(v) },
    grid: { left: 8, right: 16, top: 56, bottom: 8, containLabel: true },
    xAxis: { type: 'category', data: MESES.map((m) => nombreMes(m, true)) },
    yAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) }, max: (v) => Math.ceil((v.max * 1.18) / 10) * 10 },
    series: [{
      name: 'Meta de gestión', type: 'bar', barMaxWidth: 40,
      data: metaMes.map((v, i) => (hayDato[i] ? v : null)),
      label: { show: true, position: 'top', formatter: ({ value }) => num(value) },
      markLine: marcas.length ? {
        symbol: 'none', silent: true, lineStyle: { color: '#3e4c59', width: 2, type: 'dashed' },
        label: { color: '#1f2933', fontWeight: 600, position: 'end', rotate: 0, distance: 4 }, data: marcas,
      } : undefined,
    }],
  });
  const conDatos = MESES.filter((m, i) => hayDato[i]);
  const mayor = conDatos.reduce((a, b) => (metaMes[b - 1] > metaMes[a - 1] ? b : a));
  return tarjetaGrafico({
    titulo: 'Meta de gestión por mes',
    ariaLabel: `Gráfico de barras con la meta de gestión mensual del profesional ${persona}. `
      + `El mes con mayor meta es ${nombreMes(mayor)} con ${num(metaMes[mayor - 1])} atenciones. `
      + (marcas.length ? `Líneas verticales marcan los cambios: ${cambios.map((c) => `${tipoCambio(c.tipo).texto} en ${nombreMes(c.mes_vigencia)}`).join(', ')}.` : ''),
    nota: marcas.length ? 'Las líneas punteadas marcan el mes en que rige un cambio.' : null,
    opcion,
    tabla: {
      caption: `Meta de gestión mensual del profesional ${persona}`,
      columnas: [
        { titulo: 'Mes', campo: 'mes', formato: (m) => nombreMes(m) },
        { titulo: 'Meta de gestión', valor: (r) => (hayDato[r.mes - 1] ? metaMes[r.mes - 1] : null), numerica: true, formato: num },
      ],
      filas: MESES.map((mes) => ({ mes })),
    },
  });
}

// ---------- Línea de tiempo de cambios ----------
function lineaDeTiempo(cambios) {
  const seccion = el('section', { class: 'tarjeta', 'aria-labelledby': 'titulo-cambios' },
    el('h2', { id: 'titulo-cambios' }, 'Cambios detectados'));
  if (!cambios.length) {
    seccion.append(el('p', { class: 'estado-vacio' }, 'Este profesional no tiene cambios registrados.'));
    return seccion;
  }
  const orden = [...cambios].sort((a, b) => a.mes_vigencia - b.mes_vigencia);
  seccion.append(el('ol', { class: 'linea-tiempo' }, orden.map((c) => {
    const t = tipoCambio(c.tipo);
    return el('li', {},
      el('span', { class: 'hito', 'aria-hidden': 'true' }, t.icono),
      el('div', {},
        el('p', { class: 'hito-titulo' }, el('strong', {}, t.texto), ` · rige desde ${nombreMes(c.mes_vigencia)}`),
        el('ul', { class: 'hito-detalle' }, describirCambio(c.antes, c.despues).map((linea) => el('li', {}, linea))),
        el('p', { class: 'hito-pie' }, `Carga ${c.carga_id} · detectado el ${fecha(c.detectado_en)}`)));
  })));
  return seccion;
}

// ---------- Tabla mes a mes ----------
function tablaMensual(persona, filas, nombreInstituto) {
  const variasIt = new Set(filas.map((f) => f.it)).size > 1;
  const variosCargos = new Set(filas.map((f) => f.cargo)).size > 1;
  const t = totales(filas);
  const datos = [
    ...filas.map((f) => ({
      mes: f.mes, instituto: nombreInstituto.get(f.it) ?? `IT ${f.it}`, cargo: cargoLegible(f.cargo),
      hc: f.horas_contratadas, pctDir: f.pct_dir_final, ate: f.atenciones_dir, ateInd: f.atenciones_dir_ind,
      meta: f.meta, foja: f.foja,
    })),
    { total: true, hc: t.hc, pctDir: t.pctDir, ate: t.ate, ateInd: t.ateInd, meta: t.meta, foja: t.foja },
  ];
  const columnas = [
    { titulo: 'Mes', valor: (r) => (r.total ? 'Total' : nombreMes(r.mes)) },
    ...(variasIt ? [{ titulo: 'Instituto', campo: 'instituto' }] : []),
    ...(variosCargos ? [{ titulo: 'Cargo', campo: 'cargo' }] : []),
    { titulo: 'Horas contratadas', campo: 'hc', numerica: true, formato: (v) => num(v, 1) },
    { titulo: '% directo final', campo: 'pctDir', numerica: true, formato: (v) => pct(v, 1) },
    { titulo: 'Atenciones directas', campo: 'ate', numerica: true, formato: num },
    { titulo: 'Directas + indirectas', campo: 'ateInd', numerica: true, formato: num },
    { titulo: 'Meta', campo: 'meta', numerica: true, formato: num },
    { titulo: '% FOJA', campo: 'foja', numerica: true, formato: (v) => pct(v, 1) },
  ];
  const tabla = tablaDatos({ caption: `Profesional ${persona}: planificación mes a mes`, columnas, filas: datos });
  tabla.querySelector('tbody tr:last-child')?.classList.add('fila-total');
  return el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-mensual' },
    el('h2', { id: 'titulo-mensual' }, 'Detalle mes a mes'), el('div', { class: 'tabla-scroll' }, tabla));
}
