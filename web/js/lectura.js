// Lectura fácil: resumen de 3 a 5 frases cortas, generado con los datos de cada pantalla.
// La caja siempre está en la página; el CSS la muestra solo cuando el botón «Lectura fácil» está activado.
import { el, idUnico } from './ui.js';

export function lecturaFacil(contenedor, frases) {
  const lista = frases.filter(Boolean).slice(0, 5);
  if (!lista.length) return;
  const id = idUnico('lectura');
  const caja = el('section', { class: 'lectura-facil-caja', 'aria-labelledby': id },
    el('h2', { id }, 'Lectura fácil'), el('ul', {}, lista.map((f) => el('li', {}, f))));
  const titulo = contenedor.querySelector('h1');
  if (titulo) titulo.after(caja);
  else contenedor.prepend(caja);
}

export const plural = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;
