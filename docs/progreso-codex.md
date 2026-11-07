# Progreso Codex · César

Rama: `codex/trabajo`. Solo commits locales, sin push. Última actualización: 2026-11-06.

## Hecho

- Tarea 1 / A-02/A-03: código ODBC, carga por lotes, SHA-256 y guía de configuración para Lucas.
- Dos compilaciones independientes con el compilador .NET Framework disponible, sintaxis C# 5 (subconjunto de C# 7.3); segunda con warnings como errores. Ambas correctas. `git diff --check` correcto.
- Tarea 3 / D-06: CI para main con PostgreSQL 16, pwsh, omisión explícita de scripts ausentes y ESLint 9/Node 20. Configuración JS comprobada con Node y `git diff --check` correcto. Jobs limitados a tres minutos; duración real pendiente de GitHub.

## Siguiente

- Tarea 2 pendiente de decisión de César: fuente solo contiene enero–julio (431 personas con 7 filas); ninguna persona tiene 12 meses. Generador creado con validación previa y fallo explícito; aún no produce archivos ni se considera terminado.
- Tareas 4 y 5: guion E2E, README e instalación.

## Errores conocidos

- Este clon aún no contiene `scripts\migrar.ps1` ni `scripts\test.ps1`: no se pueden ejecutar las pruebas generales.
- No hay Blue Prism ni servidor PostgreSQL/driver ODBC preparados aquí: queda pendiente Check Code y prueba de integración en el Runtime de Lucas. La compilación local no certifica el entorno BP.
- Compilador local .NET Framework, sin SDK Roslyn C# 7.3 ni reference assemblies 4.7 verificados; se evitó toda sintaxis posterior a C# 5 y API posterior a Framework 4.7.
- Carga Masiva confirma por lote: ante error puede haber lotes anteriores confirmados; conciliar antes de reintentar.
- No existe web\js en este clon: CI de lint admite temporalmente un patrón sin archivos. No se ha ejecutado GitHub Actions (sin push por instrucción).
