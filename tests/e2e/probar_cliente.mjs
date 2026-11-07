// Prueba del módulo real api.js con fetch controlado. NO certifica HTTP ni DOM.
// node --experimental-vm-modules tests\e2e\probar_cliente.mjs origin/main
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const referencia = process.argv[2] || 'HEAD';
const sha = execFileSync('git', ['rev-parse', `${referencia}^{commit}`], { encoding: 'utf8' }).trim();
const leer = ruta => execFileSync('git', ['show', `${sha}:${ruta}`], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
const contrato = JSON.parse(fs.readFileSync(new URL('./contrato_v1_1.json', import.meta.url), 'utf8'));
const fixtures = Object.fromEntries(Object.keys(contrato.vistas).map(v => [v, JSON.parse(leer(`web/mock/${v}.json`))]));

for (const [vista, columnas] of Object.entries(contrato.vistas)) {
  assert(fixtures[vista].length > 0, `Fixture vacío: ${vista}; no se puede verificar su forma`);
  for (const fila of fixtures[vista]) for (const col of columnas) assert(col in fila, `${vista}: falta ${col} en ${referencia}`);
}

async function cliente(search) {
  const peticiones = [], avisos = [];
  const contexto = vm.createContext({ URLSearchParams, location: { search }, avisos });
  contexto.fetch = async (url, options) => {
    peticiones.push({ url, options });
    const vista = String(url).startsWith('mock/')
      ? String(url).slice(5, -5) : new URL(url).pathname.slice(1);
    assert(fixtures[vista], `Endpoint desconocido: ${url}`);
    return { ok: true, json: async () => fixtures[vista] };
  };
  const configuracion = new vm.SourceTextModule(leer('web/js/config.js'), { context: contexto });
  const ui = new vm.SyntheticModule(['avisar'], function () {
    this.setExport('avisar', (mensaje, tipo) => avisos.push({ mensaje, tipo }));
  }, { context: contexto });
  const api = new vm.SourceTextModule(leer('web/js/api.js'), { context: contexto });
  await api.link(spec => {
    if (spec === './config.js') return configuracion;
    if (spec === './ui.js') return ui;
    throw new Error(`Importación no prevista: ${spec}`);
  });
  await api.evaluate();
  return { api: api.namespace, config: configuracion.namespace.default, contexto, peticiones, avisos };
}

const api = await cliente('?modo=api');
assert.equal(api.config.modo, 'api');
for (const vista of Object.keys(contrato.vistas)) {
  const filas = await api.api.getData(vista);
  assert.equal(filas.length, fixtures[vista].length);
  const ultima = api.peticiones.at(-1);
  assert.equal(new URL(ultima.url).pathname, '/' + vista);
  assert.equal(ultima.options.headers.Accept, 'application/json');
  assert(!ultima.url.includes('mock/'));
}
await api.api.getData('v_instituto_area_mes', { it: [131, 81], area: ['KI', 'TO'], desde: 5, hasta: 7 });
let q = new URL(api.peticiones.at(-1).url).searchParams;
assert.equal(q.get('it'), 'in.(131,81)');
assert.equal(q.get('area'), 'in.("KI","TO")');
assert.deepEqual(q.getAll('mes'), ['gte.5', 'lte.7']);
await api.api.getData('v_cambios', { persona: [71555], carga: [7] });
q = new URL(api.peticiones.at(-1).url).searchParams;
assert.equal(q.get('persona_id'), 'eq.71555');
assert.equal(q.get('carga_id'), 'eq.7');
const mock = await cliente('');
assert.equal(mock.config.modo, 'mock');
const filtradas = await mock.api.getData('v_instituto_area_mes', { it: [131], desde: 5, hasta: 7 });
assert(filtradas.length > 0 && filtradas.every(r => r.it === 131 && r.mes >= 5 && r.mes <= 7));
assert.equal(mock.peticiones[0].url, 'mock/v_instituto_area_mes.json');
api.contexto.fetch = async () => ({ ok: false, status: 503 });
assert.equal((await api.api.getData('v_kpi')).length, 0);
assert(api.avisos.some(a => a.tipo === 'error' && a.mensaje.includes('503')));
console.log(JSON.stringify({ sha, contrato: contrato.version, vistas: 8, columnas_v1_1: 'OK', filtros: 'OK', modo_api: 'OK', modo_predeterminado_mock: 'confirmado', fallo_http_visible: 'OK', alcance: 'Módulo real con fetch simulado; no PostgreSQL, PostgREST ni navegador' }, null, 2));
