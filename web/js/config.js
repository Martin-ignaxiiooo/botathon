// Configuración del front. Se puede forzar el modo con ?modo=api o ?modo=mock en la URL.
const parametros = new URLSearchParams(location.search);
const modoUrl = parametros.get('modo');

const config = {
  modo: modoUrl === 'api' || modoUrl === 'mock' ? modoUrl : 'mock', // 'mock' | 'api'
  apiUrl: 'http://localhost:3000',
};

export default config;
