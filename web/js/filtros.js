// Barra de filtros común (C-04). El estado vive en el hash (#pagina?it=131,81&area=KI&desde=1&hasta=8).
// Al cambiar un control emite 'filtros-cambiaron' ({pagina, filtros}); el router actualiza el hash y la
// pantalla se vuelve a dibujar. Las opciones salen de v_instituto_area_mes.
import { getData } from './api.js';
import { el } from './ui.js';
import { PAGINAS, hashPara } from './router.js';
import { MESES, nombreArea } from './formato.js';
import { areaEsInstituto } from './dimension.js';

const CLAVES = ['it', 'area', 'cargo', 'desde', 'hasta', 'tipo'];
export const TIPOS = [
  { valor: 'directa', texto: 'Directa' },
  { valor: 'indirecta', texto: 'Indirecta' },
  { valor: 'nas', texto: 'NAS (no asistencial)' },
];

let opciones = null; // {institutos: [{it, instituto}], areas: [], cargos: []}
let promesaOpciones = null;

/** Promesa que se cumple cuando las opciones (nombres de institutos, etc.) ya están cargadas. */
export const esperarOpciones = () => promesaOpciones ?? Promise.resolve();

async function cargarOpciones() {
  const filas = await getData('v_instituto_area_mes', {});
  const institutos = new Map();
  for (const f of filas) institutos.set(f.it, f.instituto);
  return {
    institutos: [...institutos].map(([it, instituto]) => ({ it, instituto })).sort((a, b) => a.instituto.localeCompare(b.instituto, 'es')),
    areas: [...new Set(filas.map((f) => f.area).filter(Boolean))].sort(),
    cargos: [...new Set(filas.map((f) => f.cargo).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'es')),
    areaRedundante: areaEsInstituto(filas), // en el BUK real el área es la sede (= instituto): el filtro no aporta
  };
}

const capitalizar = (t) => t.charAt(0).toUpperCase() + t.slice(1);

/** Texto legible de los filtros activos ("Santiago · Kinesiología (KI) · enero a agosto"). */
export function resumenFiltros(f = {}) {
  const partes = [];
  if (f.it?.length) {
    partes.push(f.it.map((id) => opciones?.institutos.find((i) => i.it === id)?.instituto ?? `IT ${id}`).join(', '));
  }
  if (f.area?.length) partes.push(f.area.map(nombreArea).join(', '));
  if (f.cargo?.length) partes.push(f.cargo.map((c) => capitalizar(c.toLowerCase())).join(', '));
  if (f.desde || f.hasta) partes.push(`${MESES[(f.desde || 1) - 1]} a ${MESES[(f.hasta || 12) - 1]}`);
  if (f.tipo?.length) partes.push(`horas ${f.tipo.map((t) => TIPOS.find((x) => x.valor === t)?.texto.toLowerCase() ?? t).join(', ')}`);
  return partes.length ? partes.join(' · ') : 'todos los datos (sin filtros)';
}

export const hayFiltros = (f = {}) => Boolean(f.it?.length || f.area?.length || f.cargo?.length || f.desde || f.hasta || f.tipo?.length);

function campoSelect({ id, etiqueta, opcionesLista, vacio }) {
  const select = el('select', { id },
    vacio ? el('option', { value: '' }, vacio) : null,
    opcionesLista.map((o) => el('option', { value: o.valor }, o.texto)));
  return { select, campo: el('div', { class: 'campo' }, el('label', { for: id }, etiqueta), select) };
}

function construir(opc, emitir) {
  // Instituto: lista de casillas dentro de un desplegable (selección múltiple accesible con teclado)
  const casillas = opc.institutos.map(({ it, instituto }) => {
    const id = `f-it-${it}`;
    const input = el('input', { type: 'checkbox', id, value: String(it) });
    input.addEventListener('change', () => { actualizarResumenIt(); emitir(); });
    return { it, instituto, input, fila: el('label', { class: 'casilla', for: id }, input, instituto) };
  });
  const valorIt = el('span', {}, 'Todos');
  const resumenIt = el('summary', { class: 'multi-resumen' }, el('span', { class: 'solo-lectores' }, 'Instituto: '), valorIt);
  const detalle = el('details', { class: 'multi' }, resumenIt,
    el('div', { class: 'multi-lista', role: 'group', 'aria-label': 'Institutos' }, casillas.map((c) => c.fila)));
  detalle.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && detalle.open) { detalle.open = false; resumenIt.focus(); }
  });
  document.addEventListener('click', (e) => { if (detalle.open && !detalle.contains(e.target)) detalle.open = false; });
  const actualizarResumenIt = () => {
    const marcados = casillas.filter((c) => c.input.checked);
    valorIt.textContent = !marcados.length ? 'Todos'
      : marcados.length <= 2 ? marcados.map((c) => c.instituto).join(', ') : `${marcados.length} seleccionados`;
  };

  const area = campoSelect({
    id: 'f-area', etiqueta: 'Área', vacio: 'Todas',
    opcionesLista: opc.areas.map((a) => ({ valor: a, texto: nombreArea(a) })),
  });
  const cargo = campoSelect({
    id: 'f-cargo', etiqueta: 'Cargo', vacio: 'Todos',
    opcionesLista: opc.cargos.map((c) => ({ valor: c, texto: capitalizar(c.toLowerCase()) })),
  });
  area.campo.hidden = Boolean(opc.areaRedundante);
  const meses = MESES.map((m, i) => ({ valor: String(i + 1), texto: capitalizar(m) }));
  const desde = campoSelect({ id: 'f-desde', etiqueta: 'Mes desde', opcionesLista: meses });
  const hasta = campoSelect({ id: 'f-hasta', etiqueta: 'Mes hasta', opcionesLista: meses });
  hasta.select.value = '12';
  const tipo = campoSelect({
    id: 'f-tipo', etiqueta: 'Tipo de atención (horas)', vacio: 'Todos',
    opcionesLista: TIPOS.map((t) => ({ valor: t.valor, texto: t.texto })),
  });

  const aviso = el('p', { class: 'solo-lectores', role: 'status' });
  desde.select.addEventListener('change', () => {
    if (Number(desde.select.value) > Number(hasta.select.value)) {
      hasta.select.value = desde.select.value;
      aviso.textContent = 'El mes final se ajustó para no quedar antes del mes inicial.';
    }
    emitir();
  });
  hasta.select.addEventListener('change', () => {
    if (Number(hasta.select.value) < Number(desde.select.value)) {
      desde.select.value = hasta.select.value;
      aviso.textContent = 'El mes inicial se ajustó para no quedar después del mes final.';
    }
    emitir();
  });
  [area, cargo, tipo].forEach((c) => c.select.addEventListener('change', emitir));

  const limpiar = el('button', { type: 'button', class: 'boton-limpiar' }, 'Limpiar filtros');
  limpiar.addEventListener('click', () => { escribir({}); emitir(); });

  const resumen = el('p', { class: 'resumen-filtros' });
  const formulario = el('form', { class: 'barra-filtros', onsubmit: (e) => e.preventDefault() },
    el('div', { class: 'campo campo-multi' }, el('span', { class: 'etiqueta', id: 'f-it-etiqueta' }, 'Instituto'), detalle),
    area.campo, cargo.campo, desde.campo, hasta.campo, tipo.campo, limpiar, aviso);

  /** Lee los controles y devuelve solo las claves de la barra. */
  function leer() {
    const d = Number(desde.select.value);
    const h = Number(hasta.select.value);
    return {
      it: casillas.filter((c) => c.input.checked).map((c) => c.it),
      area: area.select.value ? [area.select.value] : [],
      cargo: cargo.select.value ? [cargo.select.value] : [],
      desde: d > 1 ? d : null,       // 1 y 12 son los extremos: no se guardan en el hash
      hasta: h < 12 ? h : null,
      tipo: tipo.select.value ? [tipo.select.value] : [],
    };
  }

  /** Refleja el estado del hash en los controles. */
  function escribir(f) {
    casillas.forEach((c) => { c.input.checked = f.it?.includes(c.it) ?? false; });
    actualizarResumenIt();
    area.select.value = f.area?.[0] && opc.areas.includes(f.area[0]) ? f.area[0] : '';
    cargo.select.value = f.cargo?.[0] && opc.cargos.includes(f.cargo[0]) ? f.cargo[0] : '';
    desde.select.value = String(f.desde || 1);
    hasta.select.value = String(f.hasta || 12);
    tipo.select.value = f.tipo?.[0] && TIPOS.some((t) => t.valor === f.tipo[0]) ? f.tipo[0] : '';
  }

  return { formulario, resumen, leer, escribir };
}

/** Conecta la barra con el router y los enlaces del menú. */
export function iniciarFiltros({ seccion, menu }) {
  let actual = { pagina: null, filtros: {} };
  let barra = null;
  const listas = cargarOpciones();
  promesaOpciones = listas.then((o) => { opciones = o; });

  const emitir = () => {
    const nuevos = barra.leer();
    const filtros = { ...actual.filtros };
    CLAVES.forEach((k) => { filtros[k] = nuevos[k]; });
    document.dispatchEvent(new CustomEvent('filtros-cambiaron', { detail: { pagina: actual.pagina, filtros } }));
  };

  async function sincronizar() {
    const def = PAGINAS.find((p) => p.id === actual.pagina);
    if (!def?.filtros) { seccion.hidden = true; return; }
    if (!opciones) opciones = await listas;
    if (!barra) {
      barra = construir(opciones, emitir);
      seccion.replaceChildren(el('h2', { class: 'solo-lectores' }, 'Filtros'), barra.formulario, barra.resumen);
    }
    barra.escribir(actual.filtros);
    barra.resumen.textContent = `Mostrando: ${resumenFiltros(actual.filtros)}`;
    seccion.hidden = false;
    // Los filtros acompañan al usuario al cambiar entre pantallas que los usan
    menu.querySelectorAll('a[data-pagina]').forEach((a) => {
      if (PAGINAS.find((p) => p.id === a.dataset.pagina)?.filtros) {
        a.setAttribute('href', hashPara(a.dataset.pagina, actual.filtros));
      }
    });
  }

  document.addEventListener('pagina-cambio', (e) => {
    actual = e.detail;
    sincronizar();
  });
}
