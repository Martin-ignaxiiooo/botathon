// Acceso a datos de escenarios (simulación de parámetros). No es parte del Contrato 3: en modo mock lee
// web/mock/escenarios.json y guarda las decisiones solo en memoria (se pierden al recargar); en modo api
// llama a funciones SQL por PostgREST cuyos nombres están en config.rpc (los define Andrés).
//   listar_escenarios()                                  -> [{escenario_id, descripcion, parametro, valor_actual,
//                                                            valor_propuesto, estado, creado_por, creado_en,
//                                                            decision_motivo, impacto: [{it, instituto, atenciones_antes,
//                                                            atenciones_despues, meta_antes, meta_despues, diferencia_meta}]}]
//   decidir_escenario(escenario_id, decision, motivo)    -> decision: 'aprobar' | 'rechazar'
import config from './config.js';
import { leerMock } from './api.js';

const decisionesMock = new Map(); // escenario_id -> {estado, decision_motivo}

async function llamarRpc(nombre, cuerpo) {
  const respuesta = await fetch(`${config.apiUrl}/${nombre}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify(cuerpo ?? {}),
  });
  if (!respuesta.ok) {
    let detalle = '';
    try { detalle = (await respuesta.json()).message ?? ''; } catch { /* sin cuerpo JSON */ }
    const error = new Error(detalle || `HTTP ${respuesta.status}`);
    error.estado = respuesta.status;
    throw error;
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

/** Aprueba o rechaza un escenario pendiente. Lanza un Error con el motivo del fallo. */
export async function decidirEscenario(escenarioId, decision, motivo) {
  if (decision !== 'aprobar' && decision !== 'rechazar') throw new Error('Decisión no válida.');
  if (config.modo === 'mock') {
    decisionesMock.set(escenarioId, { estado: decision === 'aprobar' ? 'aprobado' : 'rechazado', decision_motivo: motivo });
    return;
  }
  await llamarRpc(config.rpc.decidirEscenario, { escenario_id: escenarioId, decision, motivo });
}
