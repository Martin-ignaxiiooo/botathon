// Impresión (C-11): botón «Imprimir» y cabecera de impresión con título, fecha y filtros aplicados.
// El resto (sin menú, filtros ni botones) lo resuelve @media print en base.css.
import { el } from './ui.js';
import { PAGINAS } from './router.js';
import { fechaHora } from './formato.js';
import { resumenFiltros, esperarOpciones } from './filtros.js';

export function iniciarImpresion({ cabecera, herramientas }) {
  herramientas.append(el('button', { type: 'button', onclick: () => window.print() }, 'Imprimir'));

  let ultimo = { pagina: null, filtros: {} };
  const dibujar = (pagina, filtros) => {
    ultimo = { pagina, filtros };
    const def = PAGINAS.find((p) => p.id === pagina);
    if (!def) { cabecera.replaceChildren(); return; }
    const extra = [];
    if (filtros.persona?.length) extra.push(`Profesional ${filtros.persona[0]}`);
    if (filtros.carga?.length) extra.push(`Carga ${filtros.carga[0]}`);
    const filtrosTexto = def.filtros ? resumenFiltros(filtros) : (extra.join(' · ') || 'sin filtros');
    cabecera.replaceChildren(
      el('p', { class: 'impresion-marca' }, 'PlanBot · Planificación asistencial'),
      el('h2', { class: 'impresion-titulo' }, def.titulo),
      el('p', {}, `Impreso el ${fechaHora(new Date())}`),
      el('p', {}, `Filtros aplicados: ${filtrosTexto}.`));
  };
  document.addEventListener('pagina-cambio', (e) => {
    dibujar(e.detail.pagina, e.detail.filtros);
    esperarOpciones().then(() => dibujar(e.detail.pagina, e.detail.filtros)); // con los nombres de los institutos ya cargados
  });
  // Al imprimir se abren todos los desplegables (reglas de Parámetros) para que salga todo el contenido
  let abiertos = [];
  window.addEventListener('beforeprint', () => {
    dibujar(ultimo.pagina, ultimo.filtros); // la fecha y hora son las del momento de imprimir
    abiertos = [...document.querySelectorAll('details:not([open])')];
    abiertos.forEach((d) => { d.open = true; });
  });
  window.addEventListener('afterprint', () => abiertos.forEach((d) => { d.open = false; }));
}
