# Casos BUK · D-04 parcial

Generados con `python data\generar_casos.py` y openpyxl 3.1.5.

- `01_original.xlsx`: copia byte por byte de la fuente; reabierta y comprobada.
- `03_errores.xlsx`: cinco errores intencionales, conservando encabezados y filas vacías. Verificado al guardar y reabrir; textos vacíos pueden normalizarse a celdas vacías por openpyxl.
- `esperado_errores.csv`: cinco filas verificadas contra las modificaciones. Personas: 71027 (horas 0), 71132 (fechas), 71146 (cargo), 71232 (duplicado), 71247 (texto en horas). Los motivos describen la semántica esperada; el contrato no fija textos literales del validador de Lucas.

**Pendientes:** `02_cambios.xlsx` y `esperado_cambios.csv`. La fuente actual solo trae enero–julio; ninguna persona tiene 12 meses. El generador crea y verifica original/errores y luego termina con error explícito de cobertura anual, sin generar un caso engañoso de agosto–octubre. César debe decidir cómo aportar/completar la base anual preservando el requisito de original idéntico. No usar un archivo de cambios de otra ejecución como si perteneciera a esta base.

La fuente se conserva por pedido expreso; esta copia no agrega nombres ni RUT. Usar solo en el entorno de demostración autorizado.
