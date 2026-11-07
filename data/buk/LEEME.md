# Casos BUK · D-04

Generados con `python data\generar_casos.py` y openpyxl 3.1.5.

- `01_original.xlsx`: copia byte por byte de la fuente; reabierta y comprobada.
- `02_cambios.xlsx` y `esperado_cambios.csv`: cinco eventos sobre enero–julio, verificados al reabrir el Excel y derivar el CSV desde las diferencias con el original.

| Tipo | Persona | IT en CSV | Desde | Cambio |
|---|---|---|---|---|
| cambio_jornada | 71555 | 131 | mayo (5) | 40 → 30 horas semanales |
| baja | 71027 | 101 | junio (6) | Eliminar junio y julio |
| alta | 999001 | 131 | abril (4) | Copiar abril–julio del kinesiólogo 71279, con ingreso 1 de abril |
| cambio_cargo | 71132 | 131 | marzo (3) | Otro cargo existente en la fuente |
| cambio_it | 71146 | 101 | julio (7) | IT e Instituto de destino tomados de la fuente |

- Los meses anteriores de las personas modificadas y las demás personas permanecen intactos. No se agregan meses fuera de enero–julio. El CSV de traslado usa IT destino.
- `03_errores.xlsx`: cinco errores intencionales, conservando encabezados y filas vacías. Verificado al guardar y reabrir; textos vacíos pueden normalizarse a celdas vacías por openpyxl.
- `esperado_errores.csv`: cinco filas verificadas contra las modificaciones. Personas: 71027 (horas 0), 71132 (fechas), 71146 (cargo), 71232 (duplicado), 71247 (texto en horas). Los motivos describen la semántica esperada; el contrato no fija textos literales del validador de Lucas.

Por instrucción de César, los casos usan únicamente enero–julio de la fuente; no se crea una base anual sintética. Ejecutar el generador regenera y verifica los tres Excel y los dos CSV. La comprobación integrada de `api.v_cambios`/`api.v_errores_carga` se realiza en la VM con el guion E2E.

La fuente se conserva por pedido expreso; esta copia no agrega nombres ni RUT. Usar solo en el entorno de demostración autorizado.
