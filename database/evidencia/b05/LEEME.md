# Evidencia B-05 · cálculo semanal may-dic

Reproducir (con PostgreSQL arriba y openpyxl instalado):

```
.\scripts\casos_buk.ps1      # carga 01_original, 02_cambios, 03_errores y la base real -> casos_*.txt
.\scripts\evidencia_b05.ps1  # exporta v0/v1 y cruza con el Excel -> resto de archivos y resumen.md
.\scripts\test.ps1 -Modulo db
```

| Archivo | Contenido |
|---|---|
| `sistema_may_dic.csv` | Por persona-IT: datos usados (cargo, tramo, promedio, horas dic, horas promedio may-dic, colación, NAS, asignaciones, %, minutos) y resultado v0 y v1 |
| `esperado_semanal.csv` | Copia de stg.esperado (campos sin mes) usada como objetivo |
| `excel_insumos.csv` | Valores de la hoja Dotacion_Asistencial por fila Excel, más el denominador implícito |
| `diferencias_v0.csv` / `diferencias_v1.csv` | Cada diferencia con esperado, obtenido, datos del sistema y del Excel, y causas |
| `tramo.csv` | Por fila Excel: qué filas de param_cargo (cargo, tramo) reproducen sus % base |
| `denominador.csv` | Filas donde la jornada usada por el Excel no es H/S dic o no es el promedio may-dic del BUK |
| `casos_*.txt` | Métricas de cada carga BUK: conteos, alertas, errores, coincidencia semanal y personas de los casos D-04 |
| `resumen.md` | Métricas antes/después y conteos (lo genera el script) |

## 1 · Qué mide el 94,4 %

- **Capa:** `calc.v_semanal`, periodo `may_dic`, contra `stg.esperado` (campos sin mes, cargados de `data\csv\esperado.csv`).
- **Numerador:** persona-IT con `ate_dir_semana` igual al Excel (para `pct_dir_final`, diferencia ≤ 0,0001).
- **Denominador:** 450 persona-IT con esperado `ate_dir_semana` y fila en el sistema. Las 2 personas-IT con dos filas en el Excel (72190/41 y 137356/22) cuentan como acierto si calzan con cualquiera de sus filas.
- **Meses y modo:** may-dic con meses reales del BUK (5-7) y proyectados (8-12), sobre la base real `Nac - Base contratos x mes.xlsx` cargada en PostgreSQL 16 nativo.
- **v0 (antes, 94,4 %):** horas del periodo = horas del último mes del periodo (diciembre). La cifra se recalcula en `b05_export.sql` con los mismos insumos y está en `diferencias_v0.csv`.
- **v1 (después, 95,8 %):** horas del periodo = promedio de los meses may-dic con contrato.

## 2 · Cómo elige el tramo el Excel: comprobado frente a inferido

- **Comprobado:** `Dotacion_Asistencial` no tiene fórmulas en las filas de datos. Solo hay 105 fórmulas, todas en las filas 1-3 de encabezado. La tabla `Dot_Asistencial` (A4:GW476) no guarda `calculatedColumnFormula`. Las fórmulas, celdas y ponderaciones del tramo **no están en el archivo**: los valores se pegaron como valores.
- **Documentado, no demostrado con el Excel:** los umbrales 40 y 22 vienen del enunciado (`reglas.md`). La ponderación del promedio anual se infirió en B-04: cada mes con contrato pesa igual y se redondea hacia abajo. Coincide con `Prom_Pond Horas Semanales` en 456/466; ponderar por semanas da 454.
- **Inferido por coincidencia (`tramo.csv`), sobre las 471 filas:**

| Clase | Filas | Qué significa |
|---|---:|---|
| Calza con el tramo por promedio y por H/S dic | 380 | No distingue entre los dos criterios |
| No informativo | 73 | El cargo tiene los mismos % en los 3 tramos; no dice nada del tramo |
| Calza solo con el tramo por promedio | 17 | Son las únicas filas que discriminan; todas favorecen el promedio |
| Calza solo con H/S dic, u otro tramo | 0 | — |
| Sin fila en `param_cargo` | 1 | 71613 (JEFE TERAPIA OCUPACIONAL, 0,10/0,00/0,90) |

  La única evidencia directa sobre el criterio son esas 17 filas, y ninguna lo contradice. Que 466/471 calcen **no prueba** que los 5 restantes sean ajustes manuales:
  - 4 se explican con cargo + área de la fila (ver 3).
  - 71613 no calza con ninguna fila de `param_cargo`. Su origen no está confirmado y queda pendiente de preguntar al responsable del Excel.

## 3 · Clasificación de las 25 diferencias de v0

Detalle, con esperado, obtenido y datos, en `diferencias_v0.csv` y `diferencias_v1.csv`. Una fila puede tener más de una causa.

| Causa | v0 | v1 | Casos | Evidencia |
|---|---:|---:|---|---|
| Distribución por área (TO ULAB, TO UTA, EDUCADOR UTA en vez de TO o EDUCADOR) | 4 | 4 | 74761, 111842, 137147, 71926 | Los % del Excel calzan con `param_cargo` para "Cargo + Area". El área no viene en Cod_Esp del BUK (dice TO o ULAB), sí en `sub_area` ("Unidad Laboral ( ULAB )", "Unidad de Tecnologia Asistida (UTA)"). Hipótesis de regla, también encontrada por Codex; **no confirmada** |
| Minutos estándar 60 en vez de 40 | 4 | 4 | 72458 (KI tramo 2), 71232, 71292, 71372 (MF tramo 3) | El Excel trae 60 para esa fila; `param_cargo` dice 40 para ese cargo y tramo. No hay regla visible: otros MF tramo 3 usan 40 |
| Selección de tramo | 0 | 0 | — | Ninguna diferencia se explica por usar otro tramo |
| % sin fila en `param_cargo` | 1 | 1 | 71613 | 0,10/0,00/0,90 no existe para ningún tramo |
| Cargo distinto (el BUK lo cambió en julio, el Excel no) | 1 | 1 | 72365 | El Excel lo calcula como ASISTENTE SOCIAL; el BUK dice COORDINADOR desde julio |
| Cambio de jornada en may-dic | 8 | 2 | v0: 6 corregidos + 72365 y 137356 | Ver 4 |
| Horas del BUK distintas del Excel | 8 | 8 | 71342, 139458, 115444, 129024, 134746, 71575, 72190, 137356 | H/S dic o promedio del Excel ≠ BUK (el Excel es una foto anterior, o tiene excepciones y multi-IT) |
| Otra | 1 | 1 | 134744 | floor(20 × 0,75 × 0,825 / 0,85 × 60/60) = floor(14,56) = 14; el Excel dice 15 |

## 4 · Qué cambia el promedio may-dic

- **Qué toca:** cambia **solo las horas semanales del periodo** que se usan en el cálculo semanal: el denominador de %NAS con asignaciones, las horas disponibles y las atenciones por semana. **No cambia el tramo**, que sigue saliendo del promedio anual (`calc.v_promedio_horas`). Tampoco cambia las horas mensuales: B-06 usará las horas de cada mes de `core.dotacion_mes`.
- **Evidencia del propio Excel** (`denominador.csv`, `resumen.md`):
  - El Excel no guarda la jornada que usa en may-dic, pero se despeja: D = (H/Sem NAS Total + Total Hrs. Asignación) / %NAS+Asig, más la colación.
  - Comprobado en 456/456 filas: AX (H/Sem Disp.Ate) = D × (1 − %NAS+Asig).
  - En 427 filas D = H/S dic = promedio may-dic del BUK.
  - En las **9** filas donde D ≠ H/S dic, D es exactamente el promedio may-dic del BUK (9/9), y las 9 están marcadas "Cambio jornada" en el Excel.
  - En 11 filas D = H/S dic pero ≠ promedio BUK; son personas cuyas horas en el BUK difieren del Excel.
- **Proyección ago-dic:** el promedio incluye los meses proyectados (8p-12p = horas de julio). Los 9 calces exactos solo ocurren si ago-dic repite julio, así que el Excel también supone que la jornada de julio sigue hasta diciembre.
  - Ejemplo 73258: 5:40 6:40 7:30 8:30p … 12:30p da 32,5, igual a D del Excel.
- **Cambios durante el año:** el cambio se pondera por los meses que dura dentro de may-dic.
  - Ejemplo: 71555 en `02_cambios` (40 → 30 desde mayo) da 30 en may-dic.
  - Como el tramo es anual, ese cambio también lo baja de tramo 1 a 2 en ene-abr. Es una interacción de la regla documentada, no del promedio.
- **Antes/después:** ganados 6 (72210, 73206, 73258, 79740, 125926, 126057), **perdidos 0**.

## 5 · Sin excepciones por persona

No se agregó ningún ajuste por persona. Distribución por área y minutos de 60 quedan como **hipótesis por confirmar**. Si se confirman como reglas de negocio:
- La de área irá en la homologación (`param.cargo_homologado` por cargo + sub_area).
- La de minutos irá en `param.cargo_distribucion`.

En ambos casos se documentará el origen.

## 6 · Casos D-04 y pruebas (`casos_*.txt`)

| Carga | leídas / válidas / con error | Alertas | Semanal may-dic (ate / pct) |
|---|---|---|---|
| 01_original | 3123 / 3123 / 0 | 0 | 431/450 · 438/450 |
| 02_cambios | 3125 / 3125 / 0 | 0 | 429/450 · 436/450 (bajan 71555 y 71132, modificados a propósito) |
| 03_errores | 3124 / 3119 / 5 | 2 (cargo, duplicado) | 431/450 · 438/450 |
| Base real (queda cargada) | 3123 / 3123 / 0 | 0 | 431/450 · 438/450 |

- **03_errores:** las 5 filas de `esperado_errores.csv` aparecen en `stg.error_fila` con el campo esperado: 71027 horas_semanales, 71132 fecha_termino, 71146 cargo, 71232 persona_id (duplicado) y 71247 horas_semanales (texto).
- **02_cambios:** los 5 eventos se reflejan en `core.dotacion_mes`:
  - Baja 71027: termina en mayo y no se proyecta.
  - Alta 999001: desde abril.
  - Cambio de IT 71146: 131 de enero a junio, 101 desde julio.
  - Jornada 71555: 30 h desde mayo.
  - Cargo 71132: ASISTENTE SOCIAL.
- **Pruebas:** `test.ps1 -Modulo todo` en verde (000, 001, 002, 010).
