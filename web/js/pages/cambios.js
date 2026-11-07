// Pantalla Cambios y errores (C-07): lista de cargas y, al elegir una, sus errores y cambios.
// El contrato no trae el estado de la carga ni el archivo de las cargas sin errores: el estado se deduce
// de los conteos y el archivo se toma de v_errores_carga (si no hay errores, "Archivo no informado").
import { el, tablaDatos, vacio } from '../ui.js';
import { getData } from '../api.js';
import { hashPara } from '../router.js';
import { num, fecha, nombreMes } from '../formato.js';
import { tipoCambio, etiquetaCampo, describirObjeto } from '../textoCambios.js';

let renderizadaAntes = false;
let cargaAnterior = null;

/** Estado visible con texto e ícono (nunca solo color). */
function estadoDe(errores, cambios) {
  if (errores > 0) return { texto: 'Con errores', icono: '⚠', tipo: 'alerta' };
  if (cambios > 0) return { texto: 'Procesada con cambios', icono: 'ℹ', tipo: 'info' };
  return { texto: 'Procesada sin novedades', icono: '✓', tipo: 'ok' };
}

const plural = (n, uno, varios) => `${num(n)} ${n === 1 ? uno : varios}`;
const insignia = (e) => el('span', { class: `estado-texto estado-${e.tipo}` }, el('span', { 'aria-hidden': 'true' }, e.icono), e.texto);
const enlacePersona = (id) => (id === null || id === undefined
  ? 'Sin ID'
  : el('a', { href: hashPara('profesional', { persona: [id] }) }, String(id)));

function armarCargas(errores, cambios) {
  const mapa = new Map();
  const obtener = (id) => {
    if (!mapa.has(id)) mapa.set(id, { id, archivo: null, errores: 0, cambios: 0, detectado: null });
    return mapa.get(id);
  };
  for (const e of errores) {
    const c = obtener(e.carga_id);
    c.errores += 1;
    c.archivo ??= e.archivo;
  }
  for (const k of cambios) {
    const c = obtener(k.carga_id);
    c.cambios += 1;
    if (!c.detectado || k.detectado_en > c.detectado) c.detectado = k.detectado_en;
  }
  return [...mapa.values()].sort((a, b) => b.id - a.id);
}

export async function render(contenedor, filtros) {
  const [errores, cambios, institutos] = await Promise.all([
    getData('v_errores_carga', {}), getData('v_cambios', {}), getData('v_instituto_area_mes', {}),
  ]);
  contenedor.append(el('h1', { tabindex: '-1' }, 'Cambios y errores de carga'));

  const cargas = armarCargas(errores, cambios);
  if (!cargas.length) {
    const caja = el('div');
    contenedor.append(caja);
    return vacio(caja, 'Todavía no hay cargas registradas. Procese un archivo de BUK para verlo aquí.');
  }
  const elegida = cargas.find((c) => c.id === filtros.carga?.[0]) ?? null;
  const nombreInstituto = new Map(institutos.map((f) => [f.it, f.instituto]));

  contenedor.append(listaDeCargas(cargas, elegida));
  const detalle = el('section', { class: 'seccion' });
  contenedor.append(detalle);

  if (filtros.carga?.length && !elegida) {
    detalle.append(el('p', { class: 'estado estado-vacio', role: 'status' },
      `No existe la carga ${filtros.carga[0]}. Elija una de la lista.`));
  } else if (!elegida) {
    detalle.append(el('p', { class: 'estado estado-vacio' }, 'Elija una carga de la lista para ver sus errores y cambios.'));
  } else {
    const titulo = dibujarDetalle(detalle, elegida, errores.filter((e) => e.carga_id === elegida.id),
      cambios.filter((k) => k.carga_id === elegida.id), nombreInstituto);
    // Al elegir otra carga la lista se redibuja: el foco pasa al detalle para quien navega con teclado.
    if (renderizadaAntes && cargaAnterior !== elegida.id) titulo.focus();
  }
  renderizadaAntes = true;
  cargaAnterior = elegida?.id ?? null;
}

function listaDeCargas(cargas, elegida) {
  const tabla = tablaDatos({
    caption: 'Cargas procesadas, de la más reciente a la más antigua',
    columnas: [
      {
        titulo: 'Carga', valor: (c) => c,
        formato: (c) => el('a', {
          href: hashPara('cambios', { carga: [c.id] }), 'aria-current': elegida?.id === c.id ? 'true' : null,
          'aria-label': `Ver el detalle de la carga ${c.id}`,
        }, `Carga ${c.id}`),
      },
      { titulo: 'Archivo', valor: (c) => c.archivo ?? el('em', {}, 'Archivo no informado') },
      { titulo: 'Fecha', valor: (c) => (c.detectado ? fecha(c.detectado) : '—') },
      { titulo: 'Errores', campo: 'errores', numerica: true, formato: num },
      { titulo: 'Cambios', campo: 'cambios', numerica: true, formato: num },
      { titulo: 'Estado', valor: (c) => estadoDe(c.errores, c.cambios), formato: insignia },
    ],
    filas: cargas,
  });
  tabla.querySelectorAll('tbody tr').forEach((fila, i) => {
    if (cargas[i].id === elegida?.id) fila.classList.add('fila-activa-tabla');
  });
  return el('section', { class: 'tarjeta', 'aria-labelledby': 'titulo-cargas' },
    el('h2', { id: 'titulo-cargas' }, 'Cargas'), el('div', { class: 'tabla-scroll' }, tabla));
}

function dibujarDetalle(zona, carga, errores, cambios, nombreInstituto) {
  const estado = estadoDe(errores.length, cambios.length);
  const titulo = el('h2', { tabindex: '-1' }, `Carga ${carga.id}${carga.archivo ? ` · ${carga.archivo}` : ''}`);
  const resumen = el('p', { class: 'resumen-carga' }, insignia(estado),
    el('strong', {}, `Esta carga trajo ${plural(cambios.length, 'cambio', 'cambios')} y ${plural(errores.length, 'error', 'errores')}.`));
  zona.replaceChildren(el('div', { class: 'tarjeta' }, titulo, resumen));

  // ---- Errores ----
  const seccionErrores = el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-errores' },
    el('h3', { id: 'titulo-errores' }, `Errores (${num(errores.length)})`));
  if (errores.length) {
    seccionErrores.append(el('div', { class: 'tabla-scroll' }, tablaDatos({
      caption: `Errores de la carga ${carga.id}: filas que no se pudieron cargar`,
      columnas: [
        { titulo: 'Fila', campo: 'fila', numerica: true, formato: num },
        { titulo: 'Profesional', valor: (e) => e.persona_id, formato: enlacePersona },
        { titulo: 'Campo', campo: 'campo', formato: etiquetaCampo },
        { titulo: 'Motivo', campo: 'motivo' },
      ],
      filas: [...errores].sort((a, b) => a.fila - b.fila),
    })));
  } else {
    seccionErrores.append(el('p', { class: 'estado-vacio' }, '✓ Esta carga no tiene errores.'));
  }

  // ---- Cambios ----
  const seccionCambios = el('section', { class: 'tarjeta seccion', 'aria-labelledby': 'titulo-cambios-carga' },
    el('h3', { id: 'titulo-cambios-carga' }, `Cambios detectados (${num(cambios.length)})`));
  const lineas = (obj) => {
    const l = describirObjeto(obj);
    return l.length ? el('ul', { class: 'celda-lista' }, l.map((t) => el('li', {}, t))) : '—';
  };
  if (cambios.length) {
    seccionCambios.append(el('div', { class: 'tabla-scroll' }, tablaDatos({
      caption: `Cambios detectados en la carga ${carga.id}`,
      columnas: [
        {
          titulo: 'Tipo', valor: (k) => tipoCambio(k.tipo),
          formato: (t) => el('span', {}, el('span', { 'aria-hidden': 'true' }, `${t.icono} `), t.texto),
        },
        { titulo: 'Profesional', valor: (k) => k.persona_id, formato: enlacePersona },
        { titulo: 'Instituto', valor: (k) => nombreInstituto.get(k.it) ?? `IT ${k.it}` },
        { titulo: 'Rige desde', valor: (k) => nombreMes(k.mes_vigencia) },
        { titulo: 'Antes', valor: (k) => k.antes, formato: lineas },
        { titulo: 'Después', valor: (k) => k.despues, formato: lineas },
      ],
      filas: [...cambios].sort((a, b) => a.mes_vigencia - b.mes_vigencia),
    })));
  } else {
    seccionCambios.append(el('p', { class: 'estado-vacio' }, 'Esta carga no trajo cambios.'));
  }
  zona.append(seccionErrores, seccionCambios);
  return titulo;
}
