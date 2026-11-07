// Botones de accesibilidad del encabezado: «Lectura fácil» y «Letra grande».
// Cada uno es un botón de dos estados (aria-pressed) y se recuerda en este navegador.
import { el, avisar } from './ui.js';

const CLAVE = 'planbot-preferencias';

function leerPreferencias() {
  try { return JSON.parse(localStorage.getItem(CLAVE)) ?? {}; } catch { return {}; }
}
function guardarPreferencias(prefs) {
  try { localStorage.setItem(CLAVE, JSON.stringify(prefs)); } catch { /* sin almacenamiento: no se recuerda */ }
}

const OPCIONES = [
  {
    clave: 'lecturaFacil', clase: 'lectura-facil', texto: 'Lectura fácil',
    activado: 'Lectura fácil activada: cada pantalla muestra un resumen con frases cortas.',
    desactivado: 'Lectura fácil desactivada.',
  },
  {
    clave: 'letraGrande', clase: 'letra-grande', texto: 'Letra grande',
    activado: 'Letra grande activada.', desactivado: 'Letra grande desactivada.',
    redibuja: true, // los gráficos usan tamaños de letra propios: hay que dibujar la pantalla de nuevo
  },
];

export function iniciarHerramientas(zona) {
  const prefs = leerPreferencias();
  const raiz = document.documentElement;

  for (const opcion of OPCIONES) {
    const aplicar = (valor) => {
      raiz.classList.toggle(opcion.clase, valor);
      boton.setAttribute('aria-pressed', String(valor));
    };
    const boton = el('button', { type: 'button', 'aria-pressed': 'false' }, opcion.texto);
    aplicar(Boolean(prefs[opcion.clave]));
    boton.addEventListener('click', () => {
      const valor = boton.getAttribute('aria-pressed') !== 'true';
      aplicar(valor);
      guardarPreferencias({ ...leerPreferencias(), [opcion.clave]: valor });
      avisar(valor ? opcion.activado : opcion.desactivado, 'info');
      if (opcion.redibuja) window.dispatchEvent(new window.HashChangeEvent('hashchange'));
    });
    zona.append(boton);
  }
}
