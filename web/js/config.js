// Configuración del front. Se puede forzar el modo con ?modo=api o ?modo=mock en la URL.
const parametros = new URLSearchParams(location.search);
const modoUrl = parametros.get('modo');

const config = {
  modo: modoUrl === 'api' || modoUrl === 'mock' ? modoUrl : 'mock', // 'mock' | 'api'
  apiUrl: 'http://localhost:3000',
  // Funciones SQL (PostgREST /rpc/<nombre>) de escenarios. Nombres provisorios: los define Andrés (no están en el contrato).
  rpc: { listarEscenarios: 'rpc/listar_escenarios', decidirEscenario: 'rpc/decidir_escenario' },
  totalProfesionalesExcel: 471, // filas de Dotacion_Asistencial: base de la cuadratura
};

export default config;
