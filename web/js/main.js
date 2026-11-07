// Punto de entrada: menú responsive y arranque del router.
import { iniciarRouter } from './router.js';

const menu = document.getElementById('menu-principal');
const botonMenu = document.getElementById('boton-menu');
const contenedor = document.getElementById('contenido');
const pantallaChica = window.matchMedia('(max-width: 860px)');

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

iniciarRouter({ contenedor, menu });
