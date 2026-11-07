// Punto de entrada: menú responsive y arranque del router.
import { iniciarRouter } from './router.js';
import { iniciarFiltros } from './filtros.js';
import { iniciarHerramientas } from './herramientas.js';
import { vigilarDesbordes } from './ui.js';
import { vigilarTablas } from './exportar.js';
import { iniciarImpresion } from './impresion.js';

const menu = document.getElementById('menu-principal');
const botonMenu = document.getElementById('boton-menu');
const contenedor = document.getElementById('contenido');
const pantallaChica = window.matchMedia('(max-width: 860px)');

// Botones de accesibilidad (se aplican antes de dibujar para que no haya parpadeo)
iniciarHerramientas(document.getElementById('herramientas'));

// La altura del encabezado cambia con «Letra grande»: el menú pegajoso se ajusta a ella.
const encabezado = document.querySelector('.encabezado');
new ResizeObserver(() => requestAnimationFrame(() => {
  document.documentElement.style.setProperty('--alto-encabezado', `${encabezado.offsetHeight}px`);
})).observe(encabezado);
vigilarDesbordes(document.getElementById('principal'));
vigilarTablas(document.getElementById('principal'));
iniciarImpresion({ cabecera: document.getElementById('cabecera-impresion'), herramientas: document.getElementById('herramientas') });

function ajustarMenu() {
  menu.hidden = pantallaChica.matches;
  botonMenu.setAttribute('aria-expanded', 'false');
}
ajustarMenu();
pantallaChica.addEventListener('change', ajustarMenu);

botonMenu.addEventListener('click', () => {
  const abrir = menu.hidden;
  menu.hidden = !abrir;
  botonMenu.setAttribute('aria-expanded', String(abrir));
});
// En pantallas chicas el menú se cierra al elegir una pantalla.
menu.addEventListener('click', (e) => {
  if (pantallaChica.matches && e.target.closest('a')) ajustarMenu();
});

// Los filtros se registran antes que el router para no perder el primer evento 'pagina-cambio'.
iniciarFiltros({ seccion: document.getElementById('filtros'), menu });
iniciarRouter({ contenedor, menu });
