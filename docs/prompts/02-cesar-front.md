# César · FRONT (Claude Code; si se acaba la cuota, el mismo prompt en Codex)

Lee AGENTS.md, docs/contratos.md y docs/progreso-front.md. Soy César y programo el FRONT. Solo puedo modificar web\, data\, tests\e2e\, .github\, bluePrism\codigo\ y docs\progreso-front.md (y marcar mis historias en docs\backlog.md). Andrés programa el back en paralelo: no toques database\, api\, scripts\ ni tests\sql\.
Estás en Windows con PowerShell: comandos de PowerShell y rutas con \.

D-02 ya está hecho. Implementa en orden:
1) Código C# de A-02 y A-03 en bluePrism\codigo\ (PlanBot_PostgreSQL.cs con Ejecutar Consulta, Ejecutar Comando, Ejecutar Función y Carga Masiva usando System.Data.Odbc, .NET 4.7, consultas parametrizadas, lotes de 500 en transacción, solo tablas stg.*; y PlanBot_Archivos_Hash.cs con SHA-256), con un README de cómo pegarlo en Blue Prism 7.5.1. Es urgente: Lucas lo necesita antes de la hora 3.
2) D-03 (mocks con las columnas exactas de las vistas), C-02, C-03, C-04, C-05, C-06, C-07, D-04, D-06, C-08, C-10, C-09, C-11.
Front: HTML + JavaScript con módulos ES, sin framework ni build; ECharts 5 y Tabulator 6 copiados en web\vendor; accesible (teclado, aria-label, contraste AA, tabla alternativa en gráficos, lectura fácil); números es-CL; diseño sobrio y profesional.
Trabaja en modo mock (web\js\config.js) hasta que B-09 de Andrés esté en main; entonces git pull, cambia a modo api y verifica que la pantalla Nacional cuadra con v_kpi.
Por cada historia: git checkout main; git pull; rama feat/<ID>; la página carga sin errores en consola; marca la historia en docs\backlog.md; actualiza docs\progreso-front.md; commit (Conventional Commits); push; PR con gh pr create (revisa Andrés).
