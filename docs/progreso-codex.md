# Progreso Codex · César

Rama: `codex/trabajo`. Solo commits locales, sin push. Última actualización: 2026-11-06.

## Hecho

- Tarea 1 / A-02/A-03: código ODBC, carga por lotes, SHA-256 y guía de configuración para Lucas.
- Dos compilaciones independientes con el compilador .NET Framework disponible, sintaxis C# 5 (subconjunto de C# 7.3); segunda con warnings como errores. Ambas correctas. `git diff --check` correcto.
- Tarea 3 / D-06: CI para main con PostgreSQL 16, pwsh, omisión explícita de scripts ausentes y ESLint 9/Node 20. Configuración JS comprobada con Node y `git diff --check` correcto. Jobs limitados a tres minutos; duración real pendiente de GitHub.
- Tarea 4 / D-07: guion de seis pasos, comparación exacta de cambios, invariancia mensual, errores, repetidos, escenario y lista de respaldo. Revisado contra contratos; ejecución integrada pendiente de la VM y del back.
- Tarea 5 / D-08: README e instalación Windows con/sin Docker, ODBC, secretos, PostgREST, release, Control Room y ensayo. Se explicitan componentes aún ausentes; revisión documental y enlaces locales correctos.
- Tarea 2 / D-04 cerrada: generador, tres Excel y dos CSV generados/verificados. Por instrucción de César, todos los cambios usan enero–julio de la fuente, sin base anual sintética: jornada 71555 (IT 131), 40 → 30 desde mayo; baja 71027 (IT 101) desde junio; alta 999001 (IT 131) desde abril copiando al kinesiólogo 71279; cargo 71132 (IT 131) desde marzo; traslado 71146 al IT 101 desde julio (IT e Instituto).
- D-04: original idéntico byte a byte; tres Excel reabiertos; matriz completa de cambios contrastada preservando blancos/encabezados y meses previos; cinco eventos derivados independientemente de las diferencias original/cambios coinciden exactamente con esperado_cambios.csv. Alta solo abril–julio, baja sin junio/julio y ningún mes añadido fuera de enero–julio. Errores y esperado_errores también verificados (71027, 71132, 71146, 71232, 71247).
- Actualizados LEEME de casos, README, instalación y guion E2E para los nuevos meses. Comando `python data\generar_casos.py` ejecutado con openpyxl 3.1.5 desde dependencia temporal vía PYTHONPATH.
- Verificación adicional de C#: SHA-256 de archivo vacío coincide con el vector conocido; validación rechaza tablas fuera de stg e identificadores con SQL/puntos adicionales.
- Tras integración paralela del dashboard, ESLint 9.39.1 ejecutado sobre los 12 módulos de web\js: correcto. Se añadieron Node/Element como globales del navegador. Git permanece en codex/trabajo; no se modificó web.

## Siguiente

- Ensayar D-07 en la VM con Blue Prism y el back integrado: contrastar api.v_cambios y api.v_errores_carga con los CSV, y verificar recálculo desde cada vigencia.

## Errores conocidos

- Este clon aún no contiene `scripts\migrar.ps1` ni `scripts\test.ps1`: no se pueden ejecutar las pruebas generales.
- No hay Blue Prism ni servidor PostgreSQL/driver ODBC preparados aquí: queda pendiente Check Code y prueba de integración en el Runtime de Lucas. La compilación local no certifica el entorno BP.
- Compilador local .NET Framework, sin SDK Roslyn C# 7.3 ni reference assemblies 4.7 verificados; se evitó toda sintaxis posterior a C# 5 y API posterior a Framework 4.7.
- Carga Masiva confirma por lote: ante error puede haber lotes anteriores confirmados; conciliar antes de reintentar.
- web\js ya fue integrado por el trabajo paralelo; lint local en verde. No se ha ejecutado GitHub Actions (sin push por instrucción).
