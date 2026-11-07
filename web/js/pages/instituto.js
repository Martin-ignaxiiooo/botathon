import { el } from '../ui.js';

export function render(contenedor) {
  contenedor.append(el('h1', { tabindex: '-1' }, 'Instituto'), el('p', {}, 'Pantalla en construcción.'));
}
