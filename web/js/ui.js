// Utilidades de interfaz: elementos, estados de carga/error, tarjetas KPI, tablas y gráficos accesibles.
import { texto } from './formato.js';

export const PALETA = ['#124a82', '#2f80c9', '#7fb3e3', '#52606d', '#9aa5b1'];

/** Crea un elemento: el('p', {class: 'x', 'aria-label': 'y', onclick: fn}, 'texto', otroNodo). */
export function el(etiqueta, atributos = {}, ...hijos) {
  const nodo = document.createElement(etiqueta);
  for (const [clave, valor] of Object.entries(atributos || {})) {
    if (valor === null || valor === undefined || valor === false) continue;
    if (clave === 'class') nodo.className = valor;
    else if (clave.startsWith('on') && typeof valor === 'function') nodo.addEventListener(clave.slice(2), valor);
    else nodo.setAttribute(clave, valor === true ? '' : String(valor));
  }
  const agregar = (h) => {
    if (Array.isArray(h)) h.forEach(agregar);
    else if (h !== null && h !== undefined && h !== false) nodo.append(h instanceof Node ? h : document.createTextNode(String(h)));
  };
  hijos.forEach(agregar);
  return nodo;
}

let contadorId = 0;
export const idUnico = (prefijo = 'id') => `${prefijo}-${++contadorId}`;

// ---------- Avisos, carga y errores ----------
export function avisar(mensaje, tipo = 'info') {
  const zona = document.getElementById('avisos');
  if (!zona) return;
  const icono = { error: '⚠ Error:', ok: '✓', info: 'ℹ' }[tipo] || 'ℹ';
  const caja = el('div', { class: `aviso aviso-${tipo}` },
    el('p', {}, el('strong', {}, `${icono} `), mensaje));
  const cerrar = el('button', { type: 'button', 'aria-label': 'Cerrar aviso', onclick: () => caja.remove() }, 'Cerrar');
  caja.append(cerrar);
  zona.append(caja);
  if (tipo !== 'error') setTimeout(() => caja.remove(), 8000);
}

export function cargando(contenedor, mensaje = 'Cargando datos…') {
  contenedor.replaceChildren(
    el('div', { class: 'estado', role: 'status' }, el('span', { class: 'giro', 'aria-hidden': 'true' }), mensaje));
}

export function mostrarError(contenedor, mensaje, alReintentar) {
  const caja = el('div', { class: 'estado estado-error-caja', role: 'alert' },
    el('span', { 'aria-hidden': 'true' }, '⚠'),
    el('p', {}, el('strong', {}, 'No se pudo mostrar esta pantalla. '), mensaje));
  if (alReintentar) caja.append(el('button', { type: 'button', onclick: alReintentar }, 'Reintentar'));
  contenedor.replaceChildren(caja);
}

export function vacio(contenedor, mensaje = 'No hay datos para los filtros elegidos.') {
  contenedor.replaceChildren(el('p', { class: 'estado estado-vacio', role: 'status' }, mensaje));
}

// ---------- Tarjeta KPI ----------
/** estado: {texto, tipo: 'ok'|'alerta'|'error'|'info'} — el estado siempre lleva texto además del color. */
export function tarjetaKpi({ titulo, valor, detalle, estado, compacta = false }) {
  const iconos = { ok: '✓', alerta: '!', error: '✕', info: 'ℹ' };
  return el('article', { class: 'tarjeta tarjeta-kpi' },
    el('p', { class: 'tarjeta-titulo' }, titulo),
    el('p', { class: compacta ? 'tarjeta-valor tarjeta-valor-compacto' : 'tarjeta-valor' }, valor),
    detalle ? el('p', { class: 'tarjeta-detalle' }, detalle) : null,
    estado ? el('p', { class: `estado-texto estado-${estado.tipo}` },
      el('span', { 'aria-hidden': 'true' }, iconos[estado.tipo] || ''), estado.texto) : null);
}

// ---------- Tablas accesibles ----------
/** columnas: [{campo, titulo, formato?: fn, numerica?: bool}] · filas: arreglo de objetos. */
export function tablaDatos({ caption, columnas, filas, id }) {
  const cabecera = el('tr', {}, columnas.map((c) =>
    el('th', { scope: 'col', class: c.numerica ? 'num' : null }, c.titulo)));
  const cuerpo = filas.map((f) => el('tr', {}, columnas.map((c) => {
    const bruto = typeof c.valor === 'function' ? c.valor(f) : f[c.campo];
    const celda = c.formato ? c.formato(bruto) : texto(bruto); // formato recibe solo el valor (así sirve num, pct...)
    return el('td', { class: c.numerica ? 'num' : null }, celda);
  })));
  return el('table', { class: 'tabla', id }, el('caption', {}, caption),
    el('thead', {}, cabecera), el('tbody', {}, cuerpo));
}

/** Botón que muestra u oculta el elemento `objetivo` (tabla de valores del gráfico). */
export function botonVerDatos(objetivo, etiqueta = 'Ver datos') {
  if (!objetivo.id) objetivo.id = idUnico('datos');
  objetivo.hidden = true;
  const boton = el('button', { type: 'button', 'aria-expanded': 'false', 'aria-controls': objetivo.id }, etiqueta);
  boton.addEventListener('click', () => {
    const abrir = objetivo.hidden;
    objetivo.hidden = !abrir;
    boton.setAttribute('aria-expanded', String(abrir));
    boton.textContent = abrir ? 'Ocultar datos' : etiqueta;
  });
  return boton;
}

// ---------- Gráficos ECharts ----------
const liberadores = new Set();

/** Llamar al cambiar de pantalla: libera gráficos y observadores. */
export function liberarGraficos() {
  liberadores.forEach((fn) => fn());
  liberadores.clear();
}

/** Opciones base comunes (paleta, tipografía, márgenes). */
export function opcionBase(extra = {}) {
  return {
    color: PALETA,
    textStyle: { fontFamily: 'system-ui, "Segoe UI", Roboto, Arial, sans-serif', fontSize: 13, color: '#1f2933' },
    animation: !window.matchMedia('(prefers-reduced-motion: reduce)').matches,
    ...extra,
  };
}

/**
 * Tarjeta con título visible, gráfico (role="img" + aria-label) y botón "Ver datos".
 * `opcion` es una opción de ECharts; `tabla` = {caption, columnas, filas}.
 * Devuelve {elemento, grafico()} — el gráfico se crea cuando el contenedor tiene tamaño.
 */
export function tarjetaGrafico({ titulo, ariaLabel, opcion, tabla, alto = 320, alClic, nivel = 2, nota, clase = '' }) {
  const lienzo = el('div', { class: 'grafico', role: 'img', 'aria-label': ariaLabel, style: `height:${alto}px` });
  const datos = el('div', { class: 'datos-grafico' }, tablaDatos({ ...tabla }));
  const boton = botonVerDatos(datos);
  const elemento = el('section', { class: `tarjeta ${clase}`.trim() },
    el('div', { class: 'cab-grafico' }, el(`h${nivel}`, {}, titulo), boton),
    nota ? el('p', { class: 'nota-grafico' }, nota) : null, lienzo, datos);

  let grafico = null;
  const observador = new ResizeObserver(() => {
    if (!lienzo.clientWidth) return;
    if (!grafico) {
      grafico = echarts.init(lienzo);
      grafico.setOption(opcion);
      if (alClic) grafico.on('click', alClic);
    } else {
      grafico.resize();
    }
  });
  observador.observe(lienzo);
  liberadores.add(() => { observador.disconnect(); grafico?.dispose(); grafico = null; });
  return { elemento, grafico: () => grafico };
}
