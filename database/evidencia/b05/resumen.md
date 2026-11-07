# Evidencia B-05 · resumen generado por scripts\evidencia_b05.py

Medida: capa `calc.v_semanal`, periodo `may_dic`, contra `stg.esperado` (sin mes). Numerador = persona-IT con `ate_dir_semana` igual (o `pct_dir_final` a ±0,0001); denominador = persona-IT con esperado `ate_dir_semana` y fila en el sistema. Pares repetidos del Excel: acierto si calza con cualquiera de sus filas.

| Variante | ate_dir_semana | pct_dir_final |
|---|---|---|
| v0 · horas de diciembre (antes) | 425/450 = 94.4 % | 430/450 = 95.6 % |
| v1 · promedio may-dic (después) | 431/450 = 95.8 % | 438/450 = 97.3 % |

Aciertos perdidos v0→v1: 0 []. Ganados: 6 [(72210, 141), (73206, 81), (73258, 131), (79740, 131), (125926, 131), (126057, 51)].

Causas de las diferencias v0 (una fila puede tener varias): {'minutos_60_vs_40': 4, 'horas_buk_distintas_excel': 8, 'pct_sin_fila_en_param': 1, 'distribucion_area': 4, 'cambio_jornada_may_dic': 8, 'cargo_distinto': 1, 'otra': 1}

Causas de las diferencias v1 (una fila puede tener varias): {'minutos_60_vs_40': 4, 'horas_buk_distintas_excel': 8, 'pct_sin_fila_en_param': 1, 'distribucion_area': 4, 'cargo_distinto': 1, 'cambio_jornada_may_dic': 2, 'otra': 1}

## Tramo (tramo.csv)

- calza_promedio_y_hs_dic: 380
- no_informativo (mismos % en los 3 tramos): 73
- calza_solo_promedio: 17
- sin_fila_en_param: 1

## Jornada usada por el Excel en may-dic (denominador.csv)

horas_periodo_excel = (H/Sem NAS Total + Total Hrs. Asignación) / %NAS + Asig. Especiales + colación.

- =H/S dic Excel · =prom may-dic BUK: 427
- =H/S dic Excel · ≠prom may-dic BUK: 11
- ≠H/S dic Excel · =prom may-dic BUK: 9

AX (H/Sem Disp.Ate) = denominador × (1 − %NAS+Asig) en 456/456 filas.
