// CommonJS para funcionar sin package.json en este sitio sin build.
module.exports = [
  {
    files: ['web/js/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: Object.fromEntries([
        'window', 'document', 'navigator', 'location', 'history', 'localStorage',
        'sessionStorage', 'fetch', 'URL', 'URLSearchParams', 'console', 'alert',
        'confirm', 'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval',
        'requestAnimationFrame', 'cancelAnimationFrame', 'HTMLElement', 'Event',
        'CustomEvent', 'AbortController', 'Blob', 'FileReader', 'TextEncoder',
        'Intl', 'echarts', 'Tabulator', 'ResizeObserver', 'IntersectionObserver',
        'matchMedia', 'performance', 'getComputedStyle', 'queueMicrotask',
      ].map(name => [name, 'readonly'])),
    },
    rules: {
      'no-undef': 'error',
      'no-dupe-args': 'error',
      'no-dupe-keys': 'error',
      'no-unreachable': 'error',
      'constructor-super': 'error',
      'valid-typeof': 'error',
    },
  },
];
