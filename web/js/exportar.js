// Exportar CSV (C-11): cada tabla de la página recibe un botón «Exportar CSV» que descarga lo que se ve.
// El archivo usa «;» como separador y UTF-8 con BOM para que Excel en español lo abra bien; los números
// quedan como se muestran en pantalla (formato es-CL: 1.234,5).
import { el } from './ui.js';

const quitarComillas = (t) => t.replace(/"/g, '""');
const campo = (t) => `"${quitarComillas(t)}"`;

/** Texto de una celda: sin íconos decorativos, con las listas separadas por « | ». */
function textoCelda(celda) {
  const copia = celda.cloneNode(true);
  copia.querySelectorAll('[aria-hidden="true"]').forEach((e) => e.remove());
  const items = [...copia.querySelectorAll('li')].map((li) => li.textContent.replace(/\s+/g, ' ').trim());
  return (items.length ? items.join(' | ') : copia.textContent.replace(/\s+/g, ' ').trim());
}

/** Convierte una <table> accesible en texto CSV (encabezados + filas). */
export function tablaACsv(tabla) {
  const encabezados = [...tabla.querySelectorAll('thead th')].map(textoCelda);
  const filas = [...tabla.querySelectorAll('tbody tr')].map((tr) => [...tr.children].map(textoCelda));
  return [encabezados, ...filas].map((fila) => fila.map(campo).join(';')).join('\r\n');
}

const sinTildes = (t) => t.normalize('NFD').replace(/[̀-ͯ]/g, '');
export const nombreArchivo = (titulo, fecha = new Date()) => {
  const base = sinTildes(titulo).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 60) || 'tabla';
  return `planbot_${base}_${fecha.toISOString().slice(0, 10)}.csv`;
};

export function descargarCsv(nombre, contenido) {
  const blob = new Blob(['﻿', contenido], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const enlace = el('a', { href: url, download: nombre });
  document.body.append(enlace);
  enlace.click();
  enlace.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function agregarBoton(tabla) {
  if (tabla.dataset.exportable) return;
  tabla.dataset.exportable = '1';
  const titulo = tabla.querySelector('caption')?.textContent ?? 'tabla';
  const boton = el('button', {
    type: 'button', class: 'boton-exportar', 'aria-label': `Exportar a CSV la tabla: ${titulo}`,
    onclick: () => descargarCsv(nombreArchivo(titulo), tablaACsv(tabla)),
  }, 'Exportar CSV');
  const barra = el('div', { class: 'barra-tabla' }, boton);
  const padre = tabla.parentElement;
  if (padre?.matches('.tabla-scroll, .datos-grafico')) padre.prepend(barra);
  else tabla.before(barra);
}

/** Agrega el botón a las tablas existentes y a las que se dibujen después dentro de `raiz`. */
export function vigilarTablas(raiz) {
  const mirar = (nodo) => {
    if (nodo.nodeType !== 1) return;
    if (nodo.matches('table.tabla')) agregarBoton(nodo);
    nodo.querySelectorAll('table.tabla').forEach(agregarBoton);
  };
  new window.MutationObserver((cambios) => cambios.forEach((c) => c.addedNodes.forEach(mirar))).observe(raiz, { childList: true, subtree: true });
  mirar(raiz);
}
