// Cliente de datos: getData(vista, filtros). En modo mock lee web/mock/<vista>.json y filtra en memoria;
// en modo api arma la consulta de PostgREST. Si algo falla avisa y devuelve [].
import config from './config.js';
import { avisar } from './ui.js';

// Filtros que cada vista del Contrato 3 admite (columna correspondiente).
const FILTRABLES = {
  v_kpi: [],
  v_nacional_mes: ['mes'],
  v_instituto_area_mes: ['it', 'area', 'cargo', 'mes'],
  v_profesional_mes: ['it', 'area', 'cargo', 'mes', 'persona'],
  v_cambios: ['it', 'persona', 'carga'],
  v_errores_carga: ['persona', 'carga'],
  v_parametros_vigentes: [],
  v_cuadratura: ['persona', 'mes'],
};

const COLUMNA = { persona: 'persona_id', carga: 'carga_id' };

const lista = (v) => (v === undefined || v === null || v === '' ? [] : Array.isArray(v) ? v : String(v).split(','));

/** Normaliza {it, area, cargo, desde, hasta, persona, carga} a listas y números. */
export function normalizar(f = {}) {
  return {
    it: lista(f.it).map(Number).filter(Number.isFinite),
    area: lista(f.area),
    cargo: lista(f.cargo),
    persona: lista(f.persona).map(Number).filter(Number.isFinite),
    carga: lista(f.carga).map(Number).filter(Number.isFinite),
    desde: Number(f.desde) || null,
    hasta: Number(f.hasta) || null,
  };
}

function filtrarMock(filas, f, admitidos) {
  const usa = (k) => admitidos.includes(k);
  return filas.filter((r) => {
    if (usa('it') && f.it.length && !f.it.includes(Number(r.it))) return false;
    if (usa('area') && f.area.length && !f.area.includes(r.area)) return false;
    if (usa('cargo') && f.cargo.length && !f.cargo.includes(r.cargo)) return false;
    if (usa('persona') && f.persona.length && !f.persona.includes(Number(r.persona_id))) return false;
    if (usa('carga') && f.carga.length && !f.carga.includes(Number(r.carga_id))) return false;
    if (usa('mes')) {
      if (f.desde && r.mes < f.desde) return false;
      if (f.hasta && r.mes > f.hasta) return false;
    }
    return true;
  });
}

function consultaPostgrest(f, admitidos) {
  const q = [];
  const condicion = (columna, valores) => {
    if (!valores.length) return;
    q.push(valores.length === 1
      ? `${columna}=eq.${encodeURIComponent(valores[0])}`
      : `${columna}=in.(${valores.map((v) => (typeof v === 'number' ? v : `"${v}"`)).map(encodeURIComponent).join(',')})`);
  };
  for (const k of ['it', 'area', 'cargo', 'persona', 'carga']) {
    if (admitidos.includes(k)) condicion(COLUMNA[k] || k, f[k]);
  }
  if (admitidos.includes('mes')) {
    if (f.desde) q.push(`mes=gte.${f.desde}`);
    if (f.hasta) q.push(`mes=lte.${f.hasta}`);
  }
  return q.join('&');
}

const cacheMock = new Map();

/** Lee un JSON de web/mock (con caché). Sirve también para datos que no son vistas (escenarios). */
export function leerMock(nombre) {
  if (!cacheMock.has(nombre)) {
    const promesa = fetch(`mock/${nombre}.json`).then((r) => {
      if (!r.ok) throw new Error(`HTTP ${r.status} en mock/${nombre}.json`);
      return r.json();
    });
    promesa.catch(() => cacheMock.delete(nombre));
    cacheMock.set(nombre, promesa);
  }
  return cacheMock.get(nombre);
}

export async function getData(vista, filtros = {}) {
  const admitidos = FILTRABLES[vista];
  if (!admitidos) {
    avisar(`La vista «${vista}» no existe en el contrato de datos.`, 'error');
    return [];
  }
  const f = normalizar(filtros);
  try {
    if (config.modo === 'mock') {
      return filtrarMock(await leerMock(vista), f, admitidos);
    }
    const q = consultaPostgrest(f, admitidos);
    const respuesta = await fetch(`${config.apiUrl}/${vista}${q ? `?${q}` : ''}`, {
      headers: { Accept: 'application/json' },
    });
    if (!respuesta.ok) throw new Error(`HTTP ${respuesta.status}`);
    return await respuesta.json();
  } catch (error) {
    avisar(`No se pudieron cargar los datos de «${vista}» (${error.message}). Se muestra la pantalla sin datos.`, 'error');
    return [];
  }
}
