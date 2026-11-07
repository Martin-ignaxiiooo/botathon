// Router por #hash: "#pagina?clave=valor&otra=1,2". Cada pantalla es un módulo js/pages/<pagina>.js
// con `export function render(contenedor, filtros)`.
import { cargando, mostrarError, liberarGraficos, el } from './ui.js';

export const PAGINAS = [
  { id: 'nacional', titulo: 'Nacional', filtros: true },   // filtros: muestra la barra de filtros (C-04)
  { id: 'instituto', titulo: 'Instituto', filtros: true },
  { id: 'profesional', titulo: 'Profesional' },
  { id: 'cambios', titulo: 'Cambios' },
  { id: 'parametros', titulo: 'Parámetros' },
  { id: 'cuadratura', titulo: 'Cuadratura' },
];

export function leerHash() {
  const [pagina, consulta = ''] = location.hash.replace(/^#\/?/, '').split('?');
  return { pagina: pagina || 'nacional', params: new URLSearchParams(consulta) };
}

const lista = (valor) => (valor ? valor.split(',').filter(Boolean) : []);

/** Parámetros del hash -> objeto de filtros (los mismos que entiende getData). */
export function filtrosDesdeParams(p) {
  return {
    it: lista(p.get('it')).map(Number).filter(Number.isFinite),
    area: lista(p.get('area')),
    cargo: lista(p.get('cargo')),
    tipo: lista(p.get('tipo')),
    persona: lista(p.get('persona')).map(Number).filter(Number.isFinite),
    carga: lista(p.get('carga')).map(Number).filter(Number.isFinite),
    desde: Number(p.get('desde')) || null,
    hasta: Number(p.get('hasta')) || null,
  };
}

/** Arma "#pagina?it=131,81&area=KI" omitiendo filtros vacíos. */
export function hashPara(pagina, filtros = {}) {
  const q = new URLSearchParams();
  for (const [clave, valor] of Object.entries(filtros)) {
    const texto = Array.isArray(valor) ? valor.join(',') : valor;
    if (texto !== null && texto !== undefined && texto !== '') q.set(clave, texto);
  }
  const consulta = q.toString().replace(/%2C/g, ',');
  return `#${pagina}${consulta ? `?${consulta}` : ''}`;
}

export function irA(pagina, filtros = {}) {
  location.hash = hashPara(pagina, filtros);
}

let token = 0;
let ultimaPagina = null;

export function iniciarRouter({ contenedor, menu }) {
  const navegar = async () => {
    const mio = ++token;
    const { pagina, params } = leerHash();
    const def = PAGINAS.find((p) => p.id === pagina);

    menu.querySelectorAll('a[data-pagina]').forEach((a) => {
      if (a.dataset.pagina === pagina) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    liberarGraficos();

    const vista = el('div', { class: 'vista' });
    contenedor.replaceChildren(vista);

    if (!def) {
      document.title = 'Pantalla no encontrada · PlanBot';
      vista.append(el('h1', { tabindex: '-1' }, 'Pantalla no encontrada'),
        el('p', {}, 'La dirección no corresponde a ninguna pantalla. ', el('a', { href: '#nacional' }, 'Ir a Nacional')));
      ultimaPagina = null;
      document.dispatchEvent(new CustomEvent('pagina-cambio', { detail: { pagina: null, filtros: {} } }));
      return;
    }

    document.title = `${def.titulo} · PlanBot`;
    const filtros = filtrosDesdeParams(params);
    cargando(vista);
    try {
      const modulo = await import(`./pages/${pagina}.js`);
      if (mio !== token) return;
      vista.replaceChildren();
      await modulo.render(vista, filtros);
    } catch (error) {
      console.error(error);
      if (mio === token) mostrarError(vista, `Detalle técnico: ${error.message}`, navegar);
      return;
    }
    if (mio !== token) return;

    // Anuncia la nueva pantalla a lectores de pantalla, pero no mueve el foco si solo cambiaron los filtros.
    if (ultimaPagina !== null && ultimaPagina !== pagina) vista.querySelector('h1')?.focus();
    ultimaPagina = pagina;
    document.dispatchEvent(new CustomEvent('pagina-cambio', { detail: { pagina, filtros } }));
  };

  window.addEventListener('hashchange', navegar);
  // La barra de filtros avisa con este evento; el router pasa el estado al hash (la URL es la fuente de verdad).
  document.addEventListener('filtros-cambiaron', (e) => {
    irA(e.detail.pagina || leerHash().pagina, e.detail.filtros);
  });
  return navegar();
}
