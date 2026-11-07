// Dimensión de agrupación «área». En el BUK real la columna Área es la sede (igual al instituto) y la
// especialidad está en `cargo`: cuando area == instituto en todas las filas, las pantallas agrupan por cargo
// y ocultan el filtro Área. Si algún día `area` trae la especialidad (KI, TO, FI, ED...), se usa tal cual.
import { getData } from './api.js';
import { nombreArea } from './formato.js';
import { cargoLegible } from './textoCambios.js';

export const POR_AREA = {
  campo: 'area', etiqueta: 'Área', singular: 'área', plural: 'áreas', redundante: false, nombre: nombreArea,
};
export const POR_CARGO = {
  campo: 'cargo', etiqueta: 'Cargo', singular: 'cargo', plural: 'cargos', redundante: true, nombre: cargoLegible,
};

const simplificar = (t) => String(t ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');

/** area == instituto en todas las filas que traen área (algunas filas con error vienen sin área). */
export function areaEsInstituto(filas) {
  const conArea = filas.filter((f) => f.area);
  return conArea.length > 0 && conArea.every((f) => simplificar(f.area) === simplificar(f.instituto));
}

let guardada = null;

/** Devuelve POR_AREA o POR_CARGO según los datos (se decide una sola vez cuando hay datos). */
export async function dimensionArea() {
  if (guardada) return guardada;
  const filas = await getData('v_instituto_area_mes', {});
  if (!filas.length) return POR_AREA;
  guardada = areaEsInstituto(filas) ? POR_CARGO : POR_AREA;
  return guardada;
}
