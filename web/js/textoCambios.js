// Textos legibles para los cambios detectados (v_cambios): etiquetas de tipo y descripción de antes/después.
// Compartido por las pantallas Profesional y Cambios.
import { num, fecha, nombreArea } from './formato.js';

export const capitalizar = (t) => t.charAt(0).toUpperCase() + t.slice(1);
export const cargoLegible = (c) => capitalizar(String(c).toLowerCase());

const TIPOS_CAMBIO = {
  alta: { texto: 'Alta', icono: '＋' },
  baja: { texto: 'Baja', icono: '−' },
  cambio_jornada: { texto: 'Cambio de jornada', icono: '⇄' },
  cambio_cargo: { texto: 'Cambio de cargo', icono: '⇄' },
  cambio_it: { texto: 'Cambio de instituto', icono: '⇄' },
};

/** {texto, icono} del tipo de cambio; los tipos desconocidos se muestran con su nombre. */
export const tipoCambio = (t) => TIPOS_CAMBIO[t] ?? { texto: capitalizar(String(t).replaceAll('_', ' ')), icono: '⇄' };

const CAMPOS = {
  horas_semanales: 'Horas semanales', cargo: 'Cargo', area: 'Área', it: 'Instituto (IT)', instituto: 'Instituto',
  fecha_termino: 'Fecha de término', fecha_ingreso: 'Fecha de ingreso',
  persona_id: 'ID del profesional', cod_esp: 'Código de especialidad', periodo: 'Período',
};

export const etiquetaCampo = (k) => CAMPOS[k] ?? capitalizar(String(k).replaceAll('_', ' '));

export function valorCambio(campo, v) {
  if (v === null || v === undefined || v === '') return 'sin dato';
  if (campo === 'area') return nombreArea(v);
  if (campo === 'cargo') return cargoLegible(v);
  if (campo.startsWith('fecha')) return fecha(v);
  if (typeof v === 'number') return num(v, Number.isInteger(v) ? 0 : 1);
  return String(v);
}

/** Claves a mostrar: si viene el nombre del instituto no se repite el código `it`. */
function clavesVisibles(...objetos) {
  const claves = [...new Set(objetos.flatMap((o) => Object.keys(o ?? {})))];
  return claves.includes('instituto') ? claves.filter((k) => k !== 'it') : claves;
}

/** {antes, despues} (jsonb) -> ["Cargo: Kinesiologo → Terapeuta ocupacional", ...]. */
export function describirCambio(antes, despues) {
  const a = antes ?? {};
  const d = despues ?? {};
  return clavesVisibles(a, d).map((k) => (antes === null || antes === undefined
    ? `${etiquetaCampo(k)}: ${valorCambio(k, d[k])}`
    : `${etiquetaCampo(k)}: ${valorCambio(k, a[k])} → ${valorCambio(k, d[k])}`));
}

/** Un solo lado (antes o después) -> ["Cargo: Kinesiologo", ...]; vacío si el objeto es null (p. ej. alta). */
export function describirObjeto(objeto) {
  if (objeto === null || objeto === undefined) return [];
  return clavesVisibles(objeto).map((k) => `${etiquetaCampo(k)}: ${valorCambio(k, objeto[k])}`);
}
