import { el, tarjetaKpi } from '../ui.js';
import { getData } from '../api.js';
import { num, pct, fechaHora } from '../formato.js';

// Esqueleto de C-02: solo comprueba el flujo getData -> tarjeta. C-03 lo reemplaza.
export async function render(contenedor, filtros) {
  const [kpi] = await getData('v_kpi', filtros);
  contenedor.append(el('h1', { tabindex: '-1' }, 'Nacional'));
  if (!kpi) return contenedor.append(el('p', {}, 'Sin datos.'));
  contenedor.append(el('div', { class: 'grilla grilla-kpi' },
    tarjetaKpi({ titulo: 'Atenciones planificadas', valor: num(kpi.atenciones_plan) }),
    tarjetaKpi({ titulo: '% FOJA', valor: pct(kpi.foja), detalle: `Última carga: ${fechaHora(kpi.ultima_carga)}` })));
}
