# Evidencia B-07/B-08 · casos D-04 (7-nov)

Carga `01_original.xlsx` (carga 36) y luego `02_cambios.xlsx` (carga 37), con `scripts\cargar_buk_prueba.ps1 -Forzar`;
después `api.detectar_cambios(37)`. Resultado = `data\buk\esperado_cambios.csv` (5/5, sin extras):

| tipo | persona_id | it | mes_vigencia | antes | despues |
|---|---|---|---|---|---|
| cambio_cargo | 71132 | 131 | 3 | {"cargo": "MEDICO FISIATRA"} | {"cargo": "ASISTENTE SOCIAL"} |
| alta | 999001 | 131 | 4 | | {"cargo": "KINESIOLOGO", "fecha_ingreso": "2026-04-01", "horas_semanales": 44} |
| cambio_jornada | 71555 | 131 | 5 | {"horas_semanales": 40} | {"horas_semanales": 30} |
| baja | 71027 | 101 | 6 | {"cargo": "ASISTENTE SOCIAL", "horas_semanales": 32} | |
| cambio_it | 71146 | 101 | 7 | {"it": 131} | {"it": 101} |

- `api.mes_minimo_afectado(37)` = 3.
- `api.mes_minimo_afectado(36)` = NULL: es igual a la carga real anterior, sin cambios.
- `api.recalcular(3)`: 4.447 filas en 125 ms. Queda en `audit.log`: `{"desde_mes": 3, "filas": 4447, "ms": 125}`.
- Prueba sintética: `tests\sql\030_cambios_recalcular.sql`. Cubre los 6 tipos (incluye `cambio_vigencia`), la re-ejecución, la carga sin cambios, que los meses anteriores no cambien, `audit.log` y los permisos.
