// Pantalla Parámetros (C-09): reglas vigentes por tabla y escenarios de simulación con aprobación.
import { el, tablaDatos, tarjetaGrafico, opcionBase, idUnico, avisar } from '../ui.js';
import { getData } from '../api.js';
import { num, pct, fecha, fechaHora } from '../formato.js';
import { lecturaFacil, plural } from '../lectura.js';
import {
  listarEscenarios, decidirEscenario, requiereToken, leerToken, guardarToken, borrarToken, limpiarToken, pareceJwt, infoToken,
} from '../escenarios.js';
import { abrirDialogoDecision, abrirDialogoToken } from '../dialogo.js';

const ORDEN_TABLAS = ['param.general', 'param.cargo_distribucion', 'param.cargo', 'param.asignacion_catalogo', 'param.asignacion', 'param.calendario_mes', 'param.calendario', 'param.grupal'];

const ESTADOS = {
  pendiente: { texto: 'Pendiente de aprobación', icono: '!', tipo: 'alerta' },
  borrador: { texto: 'Borrador', icono: 'ℹ', tipo: 'info' },
  aprobado: { texto: 'Aprobado', icono: '✓', tipo: 'ok' },
  aplicado: { texto: 'Aplicado', icono: '✓', tipo: 'ok' },
  rechazado: { texto: 'Rechazado', icono: '✕', tipo: 'error' },
};
const estadoDe = (e) => ESTADOS[e] ?? { texto: String(e ?? 'Sin estado'), icono: 'ℹ', tipo: 'info' };
const puedeDecidir = (e) => e === 'pendiente' || e === 'borrador';

/** "0.65 · 40 min" -> "0,65 · 40 min" (decimales a la chilena; no toca fechas ni códigos). */
/** `valor` puede ser texto/número ("0.9") o un objeto JSON (param.cargo_distribucion, calendario, etc.). */
const valorLegible = (v) => {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'string' && /^\s*[{[]/.test(v)) { // en la base real el jsonb llega como texto JSON
    try { return valorLegible(JSON.parse(v)); } catch { /* no era JSON: se muestra como texto */ }
  }
  if (Array.isArray(v)) return v.map(valorLegible).join(', ');
  if (typeof v === 'object') return Object.entries(v).map(([k, x]) => `${k}: ${valorLegible(x)}`).join(' · ');
  return String(v).replace(/(\d)\.(\d)/g, '$1,$2');
};
const sinTildes = (t) => String(t).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const con = (n) => (n > 0 ? `+${num(n)}` : n < 0 ? `−${num(Math.abs(n))}` : '0');

export async function render(contenedor) {
  const [reglas, resultado] = await Promise.all([getData('v_parametros_vigentes', {}), listarEscenarios()]);
  contenedor.append(el('h1', { tabindex: '-1' }, 'Parámetros y escenarios'));

  const pendientes = resultado.escenarios.filter((e) => puedeDecidir(e.estado));
  const metaGestion = Number((reglas.find((r) => r.clave === 'meta') ?? reglas.find((r) => r.clave === 'meta_gestion'))?.valor);
  const tablas = new Set(reglas.map((r) => r.tabla));
  const primero = pendientes[0];
  const efecto = primero?.impacto.reduce((s, i) => s + Number(i.diferencia_meta || 0), 0);
  lecturaFacil(contenedor, [
    reglas.length ? `Hay ${plural(reglas.length, 'regla vigente', 'reglas vigentes')} en ${plural(tablas.size, 'tabla', 'tablas')}.` : 'Todavía no hay reglas cargadas.',
    metaGestion ? `La meta de gestión es ${pct(metaGestion, 0)} de las atenciones planificadas.` : null,
    resultado.disponible
      ? `Hay ${plural(resultado.escenarios.length, 'escenario', 'escenarios')}; ${pendientes.length} ${pendientes.length === 1 ? 'espera' : 'esperan'} una decisión.`
      : 'Los escenarios todavía no están disponibles.',
    primero ? `Si se aprueba el escenario ${primero.escenario_id}, la meta ${efecto >= 0 ? 'sube' : 'baja'} en ${num(Math.abs(efecto))} atenciones.` : null,
    requiereToken() ? 'Para aprobar o rechazar hay que ingresar como planificador y escribir un motivo.' : 'Aprobar o rechazar siempre pide un motivo.',
  ]);

  contenedor.append(seccionReglas(reglas));
  const zonaEscenarios = el('section', { class: 'seccion', 'aria-labelledby': 'titulo-escenarios' });
  contenedor.append(zonaEscenarios);
  dibujarEscenarios(zonaEscenarios, resultado);
}

// ---------- Reglas vigentes ----------
function seccionReglas(reglas) {
  const idBuscar = idUnico('buscar-regla');
  const buscador = el('input', { type: 'search', id: idBuscar, autocomplete: 'off', placeholder: 'Ej.: meta, jornada, KINESIOLOGO' });
  const resumen = el('p', { class: 'nota-grafico', role: 'status' });
  const grupos = el('div', { class: 'grupos-parametros' });
  const versionMax = reglas.reduce((m, r) => (Number(r.version) > Number(m?.version ?? 0) ? r : m), null);

  const dibujar = () => {
    const consulta = sinTildes(buscador.value.trim());
    const visibles = reglas.filter((r) => !consulta || sinTildes(`${r.tabla} ${r.clave} ${valorLegible(r.valor)}`).includes(consulta));
    const porTabla = new Map();
    visibles.forEach((r) => porTabla.set(r.tabla, [...(porTabla.get(r.tabla) ?? []), r]));
    const nombres = [...porTabla.keys()].sort((a, b) => {
      const ia = ORDEN_TABLAS.indexOf(a); const ib = ORDEN_TABLAS.indexOf(b);
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b);
    });
    resumen.textContent = consulta
      ? `Mostrando ${num(visibles.length)} de ${num(reglas.length)} reglas.`
      : `${num(reglas.length)} reglas en ${num(porTabla.size)} tablas${versionMax ? ` · versión más alta: ${versionMax.version}, vigente desde el ${fecha(versionMax.vigente_desde)}` : ''}.`;
    grupos.replaceChildren(...(nombres.length ? nombres.map((tabla, i) => {
      const filas = porTabla.get(tabla);
      const detalle = el('details', { class: 'grupo-parametros' },
        el('summary', {}, `${tabla} (${plural(filas.length, 'regla', 'reglas')})`),
        el('div', { class: 'tabla-scroll' }, tablaDatos({
          caption: `Reglas vigentes de ${tabla}`,
          columnas: [
            { titulo: 'Clave', campo: 'clave' },
            { titulo: 'Valor', campo: 'valor', formato: valorLegible },
            { titulo: 'Versión', campo: 'version', numerica: true, formato: num },
            { titulo: 'Vigente desde', campo: 'vigente_desde', formato: fecha },
          ],
          filas,
        })));
      detalle.open = Boolean(consulta) || i === 0; // sin búsqueda solo se abre la primera tabla
      return detalle;
    }) : [el('p', { class: 'estado-vacio' }, 'No hay reglas que coincidan con la búsqueda.')]));
  };
  buscador.addEventListener('input', dibujar);
  dibujar();

  return el('section', { class: 'seccion', 'aria-labelledby': 'titulo-reglas' },
    el('h2', { id: 'titulo-reglas' }, 'Reglas vigentes'),
    el('div', { class: 'campo campo-filtro' }, el('label', { for: idBuscar }, 'Buscar regla'), buscador),
    resumen, grupos);
}

// ---------- Escenarios ----------
function dibujarEscenarios(zona, resultado) {
  zona.replaceChildren(el('h2', { id: 'titulo-escenarios' }, 'Escenarios de simulación'));
  if (!resultado.disponible) {
    zona.append(el('p', { class: 'estado estado-vacio', role: 'status' },
      'Los escenarios todavía no están disponibles en esta base de datos.'));
    return;
  }
  if (!resultado.escenarios.length) {
    zona.append(el('p', { class: 'estado-vacio' }, 'No hay escenarios creados. Los escenarios se crean al simular un cambio de parámetros.'));
    return;
  }
  if (requiereToken()) zona.append(bloquePlanificador());
  zona.append(...resultado.escenarios.map(tarjetaEscenario));
}

// ---------- Modo planificador (token JWT, solo en sessionStorage) ----------
/** Vuelve a dibujar la pantalla y deja el foco en el botón indicado (la pantalla se reconstruye). */
function recargar(idFoco) {
  document.addEventListener('pagina-cambio', () => document.getElementById(idFoco)?.focus(), { once: true });
  window.dispatchEvent(new window.HashChangeEvent('hashchange'));
}

/** true si hay un token que parece vigente (la firma la verifica PostgREST al decidir). */
function tokenVigente() {
  const info = infoToken();
  return Boolean(leerToken() && info && !info.vencido);
}

async function ingresarComoPlanificador() {
  const ingreso = await abrirDialogoToken({
    validar: (texto) => {
      const token = limpiarToken(texto);
      if (!pareceJwt(token)) return 'Eso no parece un token JWT: debe tener tres partes separadas por puntos.';
      const info = infoToken(token);
      if (info?.vencido) return 'Ese token ya venció. Pida uno nuevo.';
      if (info?.rol && info.rol !== 'planificador') return `Ese token es del rol «${info.rol}», no del rol planificador.`;
      return null;
    },
    guardar: async (texto) => guardarToken(limpiarToken(texto)),
  });
  if (ingreso) recargar('boton-planificador');
}

function salirDelModoPlanificador() {
  borrarToken();
  avisar('Salió del modo planificador.', 'info');
  recargar('boton-planificador');
}

function bloquePlanificador() {
  const token = leerToken();
  const info = infoToken(token);
  const caja = el('div', { class: 'modo-planificador tarjeta' });
  if (tokenVigente()) {
    const vence = info.vence ? ` · el token vence el ${fechaHora(info.vence)}` : '';
    caja.append(
      el('p', { class: 'estado-texto estado-ok', role: 'status' }, el('span', { 'aria-hidden': 'true' }, '✓'), `Modo planificador activo${vence}`),
      el('button', { type: 'button', id: 'boton-planificador', onclick: salirDelModoPlanificador }, 'Salir'));
  } else if (token) {
    caja.append(
      el('p', { class: 'estado-texto estado-alerta', role: 'status' }, el('span', { 'aria-hidden': 'true' }, '!'),
        info?.vencido ? 'El token del planificador venció' : 'No se puede leer el token guardado'),
      el('button', { type: 'button', id: 'boton-planificador', class: 'boton-primario', onclick: ingresarComoPlanificador }, 'Ingresar de nuevo'),
      el('button', { type: 'button', onclick: salirDelModoPlanificador }, 'Salir'));
  } else {
    caja.append(
      el('p', { class: 'modo-planificador-texto' }, 'Para aprobar o rechazar escenarios hay que ingresar como planificador.'),
      el('button', { type: 'button', id: 'boton-planificador', class: 'boton-primario', onclick: ingresarComoPlanificador }, 'Ingresar como planificador'));
  }
  return caja;
}

function tarjetaEscenario(esc) {
  const estado = estadoDe(esc.estado);
  const idTitulo = `escenario-${esc.escenario_id}`;
  const titulo = el('h3', { id: idTitulo, tabindex: '-1' }, `Escenario ${esc.escenario_id}`);
  const tarjeta = el('article', { class: 'tarjeta escenario', 'aria-labelledby': idTitulo },
    el('div', { class: 'cab-grafico' }, titulo,
      el('span', { class: `estado-texto estado-${estado.tipo}` }, el('span', { 'aria-hidden': 'true' }, estado.icono), estado.texto)),
    el('p', { class: 'escenario-descripcion' }, esc.descripcion),
    el('dl', { class: 'ficha-datos' },
      el('div', {}, el('dt', {}, 'Parámetro'), el('dd', {}, esc.parametro)),
      el('div', {}, el('dt', {}, 'Valor actual → propuesto'), el('dd', {}, `${valorLegible(esc.valor_actual)} → ${valorLegible(esc.valor_propuesto)}`)),
      el('div', {}, el('dt', {}, 'Creado'), el('dd', {}, `${fechaHora(esc.creado_en)}${esc.creado_por ? ` · ${esc.creado_por}` : ''}`)),
      esc.decision_motivo ? el('div', {}, el('dt', {}, 'Motivo de la decisión'), el('dd', {}, esc.decision_motivo)) : null));

  if (esc.impacto.length) tarjeta.append(...impacto(esc));
  else tarjeta.append(el('p', { class: 'estado-vacio' }, 'Este escenario aún no tiene impacto calculado.'));

  if (puedeDecidir(esc.estado)) {
    const decidir = (decision) => async () => {
      const aprobar = decision === 'aprobar';
      const guardado = await abrirDialogoDecision({
        titulo: `${aprobar ? 'Aprobar' : 'Rechazar'} el escenario ${esc.escenario_id}`,
        descripcion: `${esc.descripcion}. ${aprobar ? 'Al aprobarlo, Blue Prism podrá aplicarlo a los parámetros.' : 'Al rechazarlo, no se aplicará.'}`,
        textoConfirmar: aprobar ? 'Confirmar aprobación' : 'Confirmar rechazo',
        guardar: (motivo) => decidirEscenario(esc.escenario_id, decision, motivo),
      });
      if (!guardado) return;
      // La pantalla se dibuja de nuevo con el estado actualizado y el foco vuelve a este escenario.
      document.addEventListener('pagina-cambio', () => document.getElementById(idTitulo)?.focus(), { once: true });
      window.dispatchEvent(new window.HashChangeEvent('hashchange'));
    };
    const autorizado = !requiereToken() || tokenVigente();
    if (autorizado) {
      tarjeta.append(el('div', { class: 'acciones' },
        el('button', { type: 'button', class: 'boton-primario', 'aria-label': `Aprobar el escenario ${esc.escenario_id}`, onclick: decidir('aprobar') }, 'Aprobar'),
        el('button', { type: 'button', 'aria-label': `Rechazar el escenario ${esc.escenario_id}`, onclick: decidir('rechazar') }, 'Rechazar')));
    } else {
      // Sin token no se puede decidir: los botones quedan inactivos (aria-disabled) y, al pulsarlos, piden el token
      const idNota = `nota-decision-${esc.escenario_id}`;
      const inactivo = (texto, etiqueta) => el('button', {
        type: 'button', class: 'boton-inactivo', 'aria-disabled': 'true', 'aria-describedby': idNota,
        'aria-label': `${etiqueta} el escenario ${esc.escenario_id} (requiere ingresar como planificador)`, onclick: ingresarComoPlanificador,
      }, texto);
      tarjeta.append(el('div', { class: 'acciones' }, inactivo('Aprobar', 'Aprobar'), inactivo('Rechazar', 'Rechazar'),
        el('span', { id: idNota, class: 'nota-decision' }, 'Requiere ingresar como planificador')));
    }
  }
  return tarjeta;
}

/** Tabla antes/después por instituto y gráfico de barras de la meta. */
function impacto(esc) {
  const filas = [...esc.impacto].sort((a, b) => Number(b.meta_despues) - Number(a.meta_despues));
  const total = filas.reduce((t, f) => ({
    instituto: 'Total nacional',
    atenciones_antes: t.atenciones_antes + Number(f.atenciones_antes),
    atenciones_despues: t.atenciones_despues + Number(f.atenciones_despues),
    meta_antes: t.meta_antes + Number(f.meta_antes),
    meta_despues: t.meta_despues + Number(f.meta_despues),
    diferencia_meta: t.diferencia_meta + Number(f.diferencia_meta),
  }), { atenciones_antes: 0, atenciones_despues: 0, meta_antes: 0, meta_despues: 0, diferencia_meta: 0 });
  const tabla = tablaDatos({
    caption: `Impacto del escenario ${esc.escenario_id} por instituto (antes y después)`,
    columnas: [
      { titulo: 'Instituto', campo: 'instituto' },
      { titulo: 'Atenciones antes', campo: 'atenciones_antes', numerica: true, formato: num },
      { titulo: 'Atenciones después', campo: 'atenciones_despues', numerica: true, formato: num },
      { titulo: 'Meta antes', campo: 'meta_antes', numerica: true, formato: num },
      { titulo: 'Meta después', campo: 'meta_despues', numerica: true, formato: num },
      {
        titulo: 'Cambio en la meta', campo: 'diferencia_meta', numerica: true,
        formato: (d) => `${con(Number(d))}${Number(d) > 0 ? ' (sube)' : Number(d) < 0 ? ' (baja)' : ' (sin cambio)'}`,
      },
    ],
    filas: [...filas, total],
  });
  tabla.querySelector('tbody tr:last-child')?.classList.add('fila-total');

  const grafico = tarjetaGrafico({
    titulo: 'Meta antes y después, por instituto', nivel: 4, clase: 'tarjeta-anidada', alto: 260,
    ariaLabel: `Gráfico de barras con la meta de cada instituto antes y después del escenario ${esc.escenario_id}. `
      + filas.map((f) => `${f.instituto}: de ${num(f.meta_antes)} a ${num(f.meta_despues)}`).join('; ') + '.',
    opcion: opcionBase({
      color: ['#7b8794', '#124a82'],
      tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' }, valueFormatter: (v) => num(v) },
      legend: { top: 0 },
      grid: { left: 8, right: 8, top: 40, bottom: 8, containLabel: true },
      // con muchos institutos se muestran todos los nombres (rotados) en vez de omitir algunos
      xAxis: { type: 'category', data: filas.map((f) => f.instituto), axisLabel: { interval: 0, rotate: filas.length > 6 ? 35 : 0 } },
      yAxis: { type: 'value', axisLabel: { formatter: (v) => num(v) } },
      series: [
        { name: 'Meta antes', type: 'bar', data: filas.map((f) => Number(f.meta_antes)), barMaxWidth: 40 },
        { name: 'Meta después', type: 'bar', data: filas.map((f) => Number(f.meta_despues)), barMaxWidth: 40 },
      ],
    }),
    tabla: {
      caption: `Meta antes y después del escenario ${esc.escenario_id}`,
      columnas: [
        { titulo: 'Instituto', campo: 'instituto' },
        { titulo: 'Meta antes', campo: 'meta_antes', numerica: true, formato: num },
        { titulo: 'Meta después', campo: 'meta_despues', numerica: true, formato: num },
      ],
      filas,
    },
  });
  return [el('div', { class: 'tabla-scroll' }, tabla), grafico.elemento];
}
