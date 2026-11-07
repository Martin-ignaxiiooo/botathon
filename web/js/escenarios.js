// Acceso a datos de escenarios (simulación de parámetros). En modo mock lee web/mock/escenarios.json y guarda las
// decisiones solo en memoria; en modo api usa las funciones SQL de B-12 por PostgREST (nombres en config.rpc):
//   api.listar_escenarios()                              -> lectura pública (rol web_lectura), sin token
//   api.decidir_escenario(escenario_id, decision, motivo) -> solo rol planificador: exige un JWT en Authorization.
// El token JWT del planificador se guarda SOLO en sessionStorage (esta pestaña) y se envía únicamente en la
// llamada a decidir_escenario. Nunca va en el repositorio ni en config.js.
import config from './config.js';
import { leerMock } from './api.js';

const CLAVE_TOKEN = 'planbot-token-planificador';
const decisionesMock = new Map(); // escenario_id -> {estado, decision_motivo}

/** Error de la API con el estado HTTP y el código de PostgreSQL/PostgREST. */
export class ErrorApi extends Error {
  constructor(mensaje, estado = 0, codigo = '') {
    super(mensaje);
    this.estado = estado;
    this.codigo = codigo;
  }
}

// ---------- Token del planificador ----------
export function leerToken() {
  try { return sessionStorage.getItem(CLAVE_TOKEN) || null; } catch { return null; }
}
export function guardarToken(token) {
  try { sessionStorage.setItem(CLAVE_TOKEN, token); } catch { /* sin almacenamiento: no se recuerda */ }
}
export function borrarToken() {
  try { sessionStorage.removeItem(CLAVE_TOKEN); } catch { /* nada que borrar */ }
}

/** Limpia lo que se pega: quita espacios, saltos de línea y un posible prefijo «Bearer ». */
export function limpiarToken(texto) {
  return String(texto ?? '').replace(/^\s*Bearer\s+/i, '').replace(/\s+/g, '');
}
export const pareceJwt = (t) => /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$/.test(t);

/** Rol y vencimiento leídos del cuerpo del token (sin verificar la firma: eso lo hace PostgREST). */
export function infoToken(token = leerToken()) {
  if (!token) return null;
  try {
    const cuerpo = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const datos = JSON.parse(window.atob(cuerpo.padEnd(Math.ceil(cuerpo.length / 4) * 4, '=')));
    const vence = Number.isFinite(datos.exp) ? new Date(datos.exp * 1000) : null;
    return { rol: datos.role ?? null, vence, vencido: vence ? vence.getTime() <= Date.now() : false };
  } catch {
    return null;
  }
}

/** La decisión necesita token solo con la base real (los datos de prueba no tienen permisos). */
export const requiereToken = () => config.modo === 'api';

// ---------- Llamadas ----------
async function llamarRpc(nombre, cuerpo, token) {
  const cabeceras = { 'Content-Type': 'application/json', Accept: 'application/json' };
  if (token) cabeceras.Authorization = `Bearer ${token}`; // solo cuando se pasa explícitamente (decidir)
  const respuesta = await fetch(`${config.apiUrl}/${nombre}`, { method: 'POST', headers: cabeceras, body: JSON.stringify(cuerpo ?? {}) });
  if (!respuesta.ok) {
    let datos = {};
    try { datos = await respuesta.json(); } catch { /* sin cuerpo JSON */ }
    throw new ErrorApi(datos.message || `HTTP ${respuesta.status}`, respuesta.status, datos.code ?? '');
  }
  const texto = await respuesta.text();
  return texto ? JSON.parse(texto) : null;
}

/** {disponible, escenarios}. `disponible` es false si la base aún no tiene la función (404). */
export async function listarEscenarios() {
  try {
    if (config.modo === 'mock') {
      const base = await leerMock('escenarios');
      return { disponible: true, escenarios: base.map((e) => ({ ...e, ...decisionesMock.get(e.escenario_id) })) };
    }
    const filas = await llamarRpc(config.rpc.listarEscenarios, {});
    return { disponible: true, escenarios: (Array.isArray(filas) ? filas : []).map((e) => ({ ...e, impacto: Array.isArray(e.impacto) ? e.impacto : [] })) };
  } catch (error) {
    return { disponible: false, escenarios: [], motivo: error.message };
  }
}

/** Mensaje claro para quien decide, según el estado HTTP y el código del error. */
function traducirError(e) {
  const texto = `${e.codigo} ${e.message}`;
  if (e.estado === 401 && /PGRST303|expired/i.test(texto)) {
    return new ErrorApi('El token venció. Salga y vuelva a ingresar como planificador con un token nuevo.', 401, e.codigo);
  }
  if (e.estado === 401 && /PGRST30|JWT|JWS/i.test(texto)) {
    return new ErrorApi('El token no es válido (formato o firma incorrectos). Salga y vuelva a ingresar con un token nuevo.', 401, e.codigo);
  }
  if (e.estado === 401) {
    return new ErrorApi('Requiere ingresar como planificador.', 401, e.codigo);
  }
  if (e.estado === 403) {
    return new ErrorApi('Su rol no tiene permiso para aprobar o rechazar escenarios (se necesita el rol planificador).', 403, e.codigo);
  }
  // Reglas del back (p. ej. «el escenario 2 ya está aprobado»): se muestra sin el prefijo técnico
  return new ErrorApi(String(e.message).replace(/^decidir_escenario:\s*/i, ''), e.estado, e.codigo);
}

/** Aprueba o rechaza un escenario pendiente. Lanza ErrorApi con un mensaje listo para mostrar. */
export async function decidirEscenario(escenarioId, decision, motivo) {
  if (decision !== 'aprobar' && decision !== 'rechazar') throw new ErrorApi('Decisión no válida.');
  if (config.modo === 'mock') {
    decisionesMock.set(escenarioId, { estado: decision === 'aprobar' ? 'aprobado' : 'rechazado', decision_motivo: motivo });
    return;
  }
  const token = leerToken();
  if (!token) throw new ErrorApi('Requiere ingresar como planificador.', 401, 'sin_token');
  try {
    await llamarRpc(config.rpc.decidirEscenario, { escenario_id: escenarioId, decision, motivo }, token);
  } catch (error) {
    throw traducirError(error);
  }
}
