// Formato es-CL: miles con punto, decimales con coma, porcentajes con 1 decimal.
const LOCALE = 'es-CL';
const SIN_DATO = '—';

export const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
export const MESES_CORTOS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const cacheNum = new Map();
function formateador(clave, opciones) {
  if (!cacheNum.has(clave)) cacheNum.set(clave, new Intl.NumberFormat(LOCALE, opciones));
  return cacheNum.get(clave);
}

function esNumero(x) {
  return x !== null && x !== undefined && x !== '' && Number.isFinite(Number(x));
}

/** 1234567.891 -> "1.234.568" (o con `dec` decimales: "1.234.567,89"). */
export function num(x, dec = 0) {
  if (!esNumero(x)) return SIN_DATO;
  return formateador(`n${dec}`, {
    minimumFractionDigits: dec, maximumFractionDigits: dec, useGrouping: 'always',
  }).format(Number(x));
}

/** 0.6543 -> "65,4 %" (la entrada es decimal, como en el contrato). */
export function pct(x, dec = 1) {
  if (!esNumero(x)) return SIN_DATO;
  return `${formateador(`p${dec}`, {
    minimumFractionDigits: dec, maximumFractionDigits: dec, useGrouping: 'always',
  }).format(Number(x) * 100)} %`;
}

/** Convierte "2026-11-04" (sin hora) a fecha local para evitar el desfase de zona horaria. */
function aFecha(valor) {
  if (valor instanceof Date) return valor;
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(valor)) {
    const [a, m, d] = valor.split('-').map(Number);
    return new Date(a, m - 1, d);
  }
  return new Date(valor);
}

/** "2026-11-04" -> "4 de noviembre de 2026". */
export function fecha(valor) {
  if (!valor) return SIN_DATO;
  const f = aFecha(valor);
  if (Number.isNaN(f.getTime())) return SIN_DATO;
  return new Intl.DateTimeFormat(LOCALE, { day: 'numeric', month: 'long', year: 'numeric' }).format(f);
}

/** "2026-11-04T09:15:42-03:00" -> "4 de noviembre de 2026, 09:15". */
export function fechaHora(valor) {
  if (!valor) return SIN_DATO;
  const f = aFecha(valor);
  if (Number.isNaN(f.getTime())) return SIN_DATO;
  const hora = new Intl.DateTimeFormat(LOCALE, { hour: '2-digit', minute: '2-digit', hour12: false }).format(f);
  return `${fecha(f)}, ${hora}`;
}

/** 1..12 -> "enero" (o "ene" si `corto`). */
export function nombreMes(m, corto = false) {
  const lista = corto ? MESES_CORTOS : MESES;
  return lista[Number(m) - 1] ?? SIN_DATO;
}

/** Texto genérico para celdas: números con num(), nulos con raya. */
export function texto(x) {
  if (x === null || x === undefined || x === '') return SIN_DATO;
  return typeof x === 'object' ? JSON.stringify(x) : String(x);
}
