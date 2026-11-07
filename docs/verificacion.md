# Verificación independiente del cálculo

Ejecución: **7 de noviembre de 2026**, Windows/Python 3.12, pandas 3.1.1 y openpyxl 3.1.5. Código: [tools/verificar_calculo.py](../tools/verificar_calculo.py). No consulta PostgreSQL ni lee código de `database\`, `api\`, `web\` o `scripts\`. El cálculo independiente se ejecuta **antes** de abrir esperado.csv; no se ajustan sus parámetros para maximizar coincidencias.

**Actualización Tarea 10:** al incorporar los insumos individuales del Excel se confirma la hipótesis: **A: 99.788 %** por cargo+área y tramo por promedio (variante de homologación candidata); **B: 100 % de ambos porcentajes finales, 98.658 % de directas semanales en 447 filas activas; C: 100 % del plan mensual aislado y 99.867 % de meta**. Los resultados están condicionados a los insumos explícitos de cada capa, no son la exactitud de un cálculo alimentado solo por BUK ni de la base de Andrés. Detalle y exportación de insumos a continuación.

## Revisión desde d69cdd8 · Directas activas B

Se partió de `d69cdd8` en `codex/trabajo`, sin cambios locales pendientes. Se leyeron las instrucciones, reglas y contratos y se consultaron las referencias remotas sin fusionarlas sobre el worktree. El contrato local y el de origin/main no identifican una versión **v1.1**; se solicitó su ubicación. Esta revisión no cambia contratos, SQL, arquitectura, fuentes Excel ni CSV de datos.

### Reproducción y denominadores

Las 12 pruebas anteriores pasaron antes de editar. La reproducción conserva exactamente los conteos del estado reportado:

| Medida | Numerador / denominador | % | Qué mide |
|---|---:|---:|---|
| A, cargo+área candidato y promedio | 470/471 por cada porcentaje base | 99.788 | Fila física de la tabla; incluye los dos pares con varios tramos |
| B, porcentajes finales usando %NAS Excel | 456/456 por cada final | 100.000 | Solo valores numéricos comparables; 15 de 471 filas sin final calculable |
| B, directas semanales activas | 441/447 | 98.658 | Filas con H/S dic > 0; todas tienen comparación numérica |
| B, directas incluyendo históricos | 441/456 | 96.711 | 456 comparables de 471; diciembre cero no representa necesariamente toda la vigencia histórica |
| C aislada, plan mayo–diciembre | 3.768/3.768 | 100.000 | 471 filas × 8 meses, usando BF y SemHab Excel |
| C aislada, meta | 3.763/3.768 | 99.867 | Misma población mensual |

El 100 % de finales es condicionado a `%NAS + Asig. Especiales` del propio Excel. El 100 % de C es condicionado a BF y SemHab. No son métricas de una cadena independiente de extremo a extremo.

### Las seis diferencias y la evidencia de disponibilidad

Se añadió lectura de **AX, H/Sem Disp.Ate**, que es una **duración Excel**. Ejemplo: 1 día y 15 minutos representa **24.25 horas**, no 0.25. Se decodifica sin perder días; números seriales se convierten de días a horas, y formatos desconocidos producen error en lugar de un cero. AX ya expresa disponibilidad **después de NAS/asignaciones**; multiplicarlo otra vez por `(1−%NAS)` duplicaría el descuento.

Se contrastan dos disponibilidades después de NAS:

```text
Disponibilidad según regla vigente = AD × (1−AT)
AD = H/Sem Disponible antes NAS dic; AT = %NAS + Asig. Especiales

Diagnóstico alternativo = AX × (%Directo / (%Directo+%Indirecto)) × 60 / min_directa
```

La segunda expresión es **solo un diagnóstico** y luego aplica floor(x+1e-9). No reemplaza la fórmula B, no alimenta las variantes C y no usa el objetivo BA para elegir un valor. Los seis casos se identifican por fila_excel; ninguno pertenece a los pares repetidos.

| Fila Excel | persona_id / IT | Objetivo BA | B vigente | AX diagnóstico | Disponibilidad AD×(1−AT), h | AX, h | Causa comprobada / pendiente |
|---:|---|---:|---:|---:|---:|---:|---|
| 18 | 134744 / 11 | 15 | 14 | 14 | 16.500000 | 16.50 | Ambas disponibilidades coinciden; el objetivo no se deriva de estos insumos con la regla escrita. Revisar origen/excepción. |
| 115 | 72365 / 41 | 16 | 17 | 16 | 14.177215 | 14.00 | AX y diciembre difieren; solo AX reproduce BA. Confirmar disponibilidad/vigencia correcta. |
| 219 | 73206 / 81 | 29 | 30 | 29 | 25.756627 | 25.45 | Misma diferencia de insumos; no error de frontera numérica. |
| 383 | 79740 / 131 | 30 | 29 | 30 | 22.656000 | 23.60 | La disponibilidad AX es mayor que la reconstruida de diciembre. |
| 384 | 73258 / 131 | 31 | 29 | 31 | 22.384615 | 24.25 | AX conserva más de 24 h; no se recorta a una hora del día. |
| 464 | 72210 / 141 | 33 | 32 | 33 | 24.476190 | 25.70 | Disponibilidades distintas; AX reproduce el objetivo. |

Sin floor, los valores de la regla vigente son respectivamente **14.558824, 17.012658, 30.356024, 29.736000, 29.379808 y 32.125000**. Con AX son **14.558824, 16.800000, 29.994643, 30.975000, 31.828125 y 33.731250**. No se corrigen con un epsilon mayor: la regla es floor(x+1e-9), no redondeo al entero más cercano.

En particular, 134744 tiene H/S=20, %Directo=0.75, %Indirecto=0.10, %NAS+asignaciones=0.175 y min_directa=60. La operación es `20×0.75×(1−0.175)/0.85 = 14.5588235294`, cuyo floor es **14**. El objetivo **15** puede ser un valor no actualizado o una excepción, pero la causa de origen no está demostrada y no se modifica ni el Excel ni esperado.csv.

Las cinco filas restantes están marcadas como cambios de jornada en la planilla; eso es compatible con un desajuste temporal entre disponibilidad semanal may–dic y la de diciembre. **No demuestra por sí solo cómo debe calcularse la vigencia de AX.** Las celdas relevantes están pegadas como valores: no hay una fórmula viva que permita certificar su procedencia. Se solicitó confirmación antes de sustituir el insumo de la regla B.

### Pares repetidos: tramos consecutivos, no cruces que deban colapsarse

La lectura de T/U (Periodo Inicio Jornada / Perido Fin Jornada) demuestra:

| Persona / IT | Fila | Inicio | Fin | H/S dic |
|---|---:|---|---|---:|
| 137356 / 22 | 59 | 2026-01-01 | 2026-06-30 | 0 |
| 137356 / 22 | 60 | 2026-07-01 | 2026-12-31 | 30 |
| 72190 / 41 | 112 | 2026-01-01 | 2026-03-31 | 0 |
| 72190 / 41 | 113 | 2026-04-01 | 2026-12-31 | 35 |

Las 471 filas y 469 pares se mantienen. Se incorporó una validación de unicidad de **fila_excel** y cruces `validate='one_to_one'` por esa fila para la evidencia, sin cruzar por persona/IT ni tomar máximos. Ninguna de las seis diferencias activas proviene de estos cuatro registros. Las vigencias se leen únicamente para diagnóstico; **insumos.csv conserva sus 31 columnas y contenido**, sin introducir una dimensión nueva en contratos.

### Antes/después y decisiones pendientes

| Resultado | Antes | Después |
|---|---:|---:|
| B vigente, directas activas | 441/447 = 98.658 % | **441/447 = 98.658 %**, no se cambió la regla |
| Diagnóstico separado con AX | No disponible | 446/447 = **99.776 %**, cinco casos explicados, no aprobados como sustitución |
| A, finales B, indirectas B y variantes C existentes | Resultados originales | **Idénticos, fila por fila**, incluidos aciertos y discrepancias |

Se conservaron los CSV de la reproducción en `tools/resultados/revision_antes` y los nuevos en `tools/resultados/revision_despues` (artefactos locales excluidos de Git). Se contrastaron con `pandas.testing.assert_frame_equal` **todo el detalle y todo el resumen preexistentes**, excluyendo únicamente la nueva capa de diagnóstico. No se perdió ninguno de los 441 aciertos originales al evaluar AX como alternativa. El nuevo `b_directas_activas_discrepancias.csv` permite reproducir la tabla y sus causas, sin codificar excepciones por persona.

**17 pruebas en verde**: las 12 originales y cinco pruebas nuevas que cubren duraciones >24 h, formatos ambiguos, seis residuos, ausencia de regresiones en AX y mantenimiento de vigencias/identidad de filas. No está disponible scripts/test.ps1; no se modificaron los datos ni carpetas del back/front.

Pendientes concretos: confirmar si B debe usar la disponibilidad de AX y cuál es su vigencia; revisar 134744/11 con el responsable del Excel; facilitar la referencia del contrato v1.1. Siguen sin cambiar los residuos ya documentados de A (71613/131), NAS reconstruido (nueve jornadas), reconstrucción grupal y las cinco metas. No se aplican reglas nuevas ni ajustes para alcanzar 100 %.

## Tarea 10 · Diagnóstico por capas

```powershell
python tools\verificar_calculo.py --capas --salida tools\resultados\capas
python data\extraer.py "data\excel\Nac - Planificacion Asistencial x mes.xlsx" data\csv
python -m unittest discover -s tools -p test_*.py
```

El diagnóstico lee directamente las columnas necesarias de **Dotacion_Asistencial, tabla Dot_Asistencial, encabezados fila 4**. El rango de tabla es A4:GW476, con una fila de totales: se usan **471 registros de las filas 5–475**, nunca el total. Se compara por **fila_excel**, manteniendo separados contratos con el mismo persona_id/IT. Así los conflictos del CSV largo de Tarea 9 no se convierten en cruces muchos-a-muchos ni se pierde la correspondencia con el objetivo.

Se generan `capas_resumen.csv`, `capas_detalle.csv`, `capas_top20.csv` y `capas_claves_repetidas.csv` en la salida (excluidos de Git). Las discrepancias incluyen persona_id, IT, fila Excel, mes, referencia, cálculo y diferencia. Tolerancia 1e-9 en porcentajes e intermedios fraccionarios; igualdad exacta en conteos, con floor(x+1e-9). El manifiesto de fuentes incluye la huella del Excel de planificación cuando se usa --capas.

### A · Distribución base, homologación y tramo

Se contrastan `%Directo`, `%Indirecto` y `% NAS` con param_cargo. Se prueban ambos criterios de tramo con los umbrales de parámetros, sin ajustar las cifras objetivo.

| Homologación / criterio de tramo | Directo | Indirecto | NAS | Denominador |
|---|---:|---:|---:|---:|
| Nombre normalizado / Prom_Pond Horas Semanales | 466 · 98.938 % | 467 · 99.151 % | 467 · 99.151 % | 471 |
| Nombre normalizado / H/S dic | 449 · 95.329 % | 456 · 96.815 % | 450 · 95.541 % | 471 |
| Cargo+área candidato / Prom_Pond Horas Semanales | 470 · **99.788 %** | 470 · **99.788 %** | 470 · **99.788 %** | 471 |
| Cargo+área candidato / H/S dic | 453 · 96.178 % | 459 · 97.452 % | 453 · 96.178 % | 471 |

La variante contextual utiliza `Cargo + " " + Area` únicamente cuando ese nombre existe en param_cargo para el tramo; en caso contrario conserva el nombre original. No consulta porcentajes objetivo para elegir, ni contiene excepciones por persona. Es una **propuesta de homologación a validar por Andrés**, no una modificación del catálogo SQL.

Resuelve cuatro casos concretos: 74761 y 111842 (TO del área ULAB), 71926 (EDUCADOR del área UTA) y 137147 (TO del área UTA). El quinto residuo, **71613/131, fila 382**, tiene JEFE TERAPIA OCUPACIONAL con base Excel 0.10/0.00/0.90, frente a 0.30/0.10/0.60 del cargo general. Existe un cargo especial AC en parámetros compatible con esa distribución, pero el código no lo asigna sin una regla de homologación aprobada. El promedio ponderado explica mejor el tramo que la jornada de diciembre.

### B · NAS, porcentajes finales y atención semanal

Dos rutas separadas evitan confundir una identidad con una reconstrucción de todos sus insumos:

```text
disponible = H/S dic − Horas Colación en Contrato
pct_NAS_reconstruido = (H/Sem NAS Total + Total Hrs. Asignación) / disponible
pct_dir_final = %Directo × (1 − pct_NAS) / (%Directo + %Indirecto)
pct_ind_final = %Indirecto × (1 − pct_NAS) / (%Directo + %Indirecto)
directas_semana = floor(disponible_antes_NAS_Excel × pct_dir_final × 60 / min_directa + 1e-9)
```

La primera ruta usa el `%NAS + Asig. Especiales` ya calculado en Excel para aislar los porcentajes finales y la atención. La segunda lo reconstruye desde NAS/asignaciones/colación y expone sus diferencias. No se utiliza `%Directo Final` ni la atención semanal objetivo como predictor de la atención recalculada.

| Prueba | Aciertos / comparables | % comparables | Sin comparar / universo |
|---|---:|---:|---:|
| Disponible H/S dic − colación vs H/Sem Disponible antes NAS dic | 471/471 | 100.000 | 0/471 |
| NAS reconstruido vs %NAS + Asig. Especiales | 438/447 | 97.987 | 24/471 |
| Final directo usando %NAS Excel | 456/456 | **100.000** | 15/471 |
| Final indirecto usando %NAS Excel | 456/456 | **100.000** | 15/471 |
| Final directo/indirecto con NAS reconstruido | 438/447 cada uno | 97.987 | 24/471 |
| Directas semanales con %NAS Excel, H/S dic > 0 | 441/447 | **98.658** | 0/447 |
| Indirectas semanales con %NAS Excel, H/S dic > 0 | 444/447 | 99.329 | 0/447 |
| Directas semanales con NAS reconstruido, activas | 439/447 | 98.210 | 0/447 |
| Indirectas semanales con NAS reconstruido, activas | 443/447 | 99.105 | 0/447 |

Se muestra explícitamente la población activa de **447 filas con H/S dic > 0**, coherente con las reglas documentadas. Al incluir históricos con diciembre cero, la primera ruta semanal da **441/456 = 96.711 %** de directas comparables (93.631 % sobre las 471 filas). Algunas filas guardan atención semanal histórica distinta de cero pese a H/S dic = 0; no se borran ni se presentan como prueba de fallo de la fórmula de diciembre. Los porcentajes finales nulos tampoco se convierten en cero. Denominadores disponibles <= 0 no se usan para reconstruir NAS.

Los nueve residuos del NAS reconstruido corresponden a jornadas cambiantes: **72365/41, 126057/51, 73206/81, 119621/91, 72721/131, 125926/131, 79740/131, 73258/131 y 72210/141**. Revisar qué jornada/ponderación usa allí el Excel; no se ajustó el denominador para forzar coincidencia.

Las seis discrepancias semanales directas activas con %NAS Excel son **134744/11** (15 vs 14), **72365/41** (16 vs 17), **73206/81** (29 vs 30), **79740/131** (30 vs 29), **73258/131** (31 vs 29) y **72210/141** (33 vs 32), en orden objetivo vs recalculado. Salvo la primera, son jornadas cambiantes. Validar estándar, vigencia de horas y posibles ajustes manuales.

### C · Plan mensual y meta, mayo–diciembre

Para aislar la fórmula mensual se utiliza **Atención Semanal Directa + Grupal** de Excel (BF), no solo las directas individuales BA:

```text
plan_mes = floor(semana_directa_grupal_Excel × SemHabMes + 1e-9)
meta_mes = floor(plan_mes × meta_parametrizada + 1e-9)
```

| Variante | Plan | Meta | Sin comparar |
|---|---:|---:|---:|
| Mensual aislada, usando BF Excel | **3.768/3.768 = 100.000 %** | **3.763/3.768 = 99.867 %** | 0 |
| Encadenada desde %NAS Excel y grupos reconstruidos | 3.575/3.648 = 97.999 % | 3.570/3.648 = 97.862 % | 120/3.768 |
| Encadenada desde NAS reconstruido y grupos | 3.504/3.576 = 97.987 % | 3.499/3.576 = 97.847 % | 192/3.768 |

La reconstrucción de BF a partir de la atención individual, porcentaje grupal (override individual si existe; si no, estándar) y pacientes por grupo coincide en **462/471 = 98.089 %**, con tolerancia para números fraccionarios. Por eso **no se afirma 100 % de extremo a extremo**: la capa C aislada confirma la fórmula del plan con BF y SemHab correctos, mientras la cadena completa conserva los residuos semanales y grupales.

Los cinco residuos de meta aislada son **136947/131, julio** (Excel 289 vs 297) y **72458/51, agosto–noviembre** (86/84/86/86 vs 85/83/85/85). Investigar referencia/redondeo intermedio o ajustes, sin cambiar los valores objetivo. La meta usa 0.9 del archivo de parámetros generales, no una constante dentro de la función.

### Tarea 10.2 · Exportación insumos.csv

Las capas confirman el efecto de los insumos faltantes y permiten generar [data/csv/insumos.csv](../data/csv/insumos.csv). Se regeneraron todos los CSV con el extractor; los seis archivos anteriores conservan su contenido. Conteos: param_cargo 258, param_asignacion 33, param_calendario 12, param_grupal 10, excepciones 177, esperado 31.527; **insumos 471 filas × 31 columnas**. No incluye nombres, RUT ni fechas de nacimiento; los textos de asignación son categorías de la planilla.

**Límite de unicidad que no debe ocultarse:** la tabla tiene 471 registros pero **469 pares persona_id/IT únicos**. Se consultó a César sobre esta contradicción entre «471 filas» y «una por par». La exportación de revisión conserva las 471 filas, en orden de tabla y sin inventar una agregación; queda pendiente definir una clave de contrato/versión o la consolidación antes de usar persona_id/IT como clave única.

| Par repetido | Filas Excel | H/S dic | Promedio | Horas asignación |
|---|---|---|---|---|
| 137356 / 22 | 59 y 60 | 0 y 30 | 20 y 30 | 0 y 0 |
| 72190 / 41 | 112 y 113 | 0 y 35 | 32 y 35 | 0.25 y 18.25 |

No usar `drop_duplicates`, sumar todas las horas ni elegir el máximo sin revisar la vigencia. El registro n del CSV (contando desde 1 después de la cabecera) corresponde a fila Excel n+4; el diagnóstico aporta fila_excel para resolver estos casos sin cambiar las 31 columnas pedidas. El extractor imprime un aviso explícito de duplicidad. **insumos.csv es un artefacto auxiliar nuevo, no un CSV de un contrato stg existente: no se crea ni modifica una tabla SQL.**

| Columna(s) | Origen / unidad |
|---|---|
| persona_id, it | PersonaId e IT; enteros |
| cargo, area | Cargo y Area; texto con espacios exteriores recortados |
| horas_semana_dic | H/S dic; horas por semana |
| prom_pond_horas | Prom_Pond Horas Semanales; horas |
| dias_semana | N° Días Semana Contrato; número de días |
| colacion_contrato | Horas Colación en Contrato; horas semanales, no indicador sí/no |
| horas_nas_total | H/Sem NAS Total; horas semanales |
| horas_asignacion | Total Hrs. Asignación; total, puede incluir asignaciones 3/4 |
| asignacion_1, horas_asig_1 | Asignación 1 y Hrs. Asignación 1 |
| asignacion_2, horas_asig_2 | Asignación 2 y Hrs. Asignación 2 |
| pct_dir_base, pct_ind_base, pct_nas_base | %Directo, %Indirecto y % NAS; fracciones, no porcentaje ×100 |
| min_directa, min_indirecta | Estándar Minutos Atención Directa/Indirecta |
| semhab_1 … semhab_12 | SemHab1 … SemHab12; semanas individuales por mes |

Vacíos numéricos se conservan como NULL/celda CSV vacía, no se convierten en 0. Los blancos de texto también quedan vacíos. Se conserva precisión decimal sin redondear a efectos de visualización.

**Suficiencia del archivo:** las 31 columnas solicitadas no incluyen `%NAS + Asig. Especiales`, BF ni los overrides grupales/pacientes. Por tanto permiten reconstruir la ruta B de NAS y obtener aproximadamente 98 % en activas, pero no garantizan por sí solas el 100 % condicionado ni la ruta C aislada. Cualquier ampliación futura de insumos/contratos debe acordarse expresamente. No deben sustituirse faltantes con resultados finales del esperado para afirmar independencia.

Pruebas: **12 en verde**, incluyendo lectura acotada de tabla, 471 registros sin totales, cotejo independiente de las 31 columnas CSV frente a la hoja, mantenimiento de los contratos repetidos, denominador activo separado, resultados por capa y las siete pruebas anteriores. No se ejecutó scripts/test.ps1 porque no está en este clon.

## Resultado histórico de Tarea 9 · Solo BUK y parámetros

Con esas fuentes y supuestos **no se reprodujo el 98–100 %** anunciado en reglas.md: continuidad coincidió en 4.232 % del %Dir final, 21.875 % semanal y 2.376 % mensual comparable. La tarea 10 explica por qué: los insumos individuales son necesarios. Estos números históricos no describen las capas condicionadas anteriores ni la base de Andrés, cuyo export real sigue pendiente.

## Ejecutar y reproducir

Desde la raíz del repositorio, en PowerShell:

```powershell
python -m pip install -r tools\requirements-verificacion.txt
python tools\verificar_calculo.py
python -m unittest discover -s tools -p test_*.py
# Sensibilidad explícita; no reemplaza el resultado base:
python tools\verificar_calculo.py --colacion --grupal-hipotesis --salida tools\resultados\sensibilidad
```

En esta sesión las dependencias se instalaron en una carpeta temporal y se pasaron mediante PYTHONPATH; no se modificó la instalación de pgAdmin. `--buk`, `--csv`, `--param-generales` y `--salida` permiten otras rutas. Las rutas predeterminadas de entrada se resuelven desde el repositorio, sin depender del directorio de ejecución.

La salida predeterminada `tools\resultados\` está excluida de Git mediante `tools\.gitignore`. Se generan:

- `calculo.csv`: todas las personas/IT y meses 5–12 de ambos modelos, valores intermedios, cargo, origen observado/proyectado/sin_contrato e hipótesis. No contiene nombres, RUT ni fecha completa de nacimiento.
- `comparaciones.csv`: unión exterior de referencia y cálculo, diferencia **calculado − referencia**, coincidencia y cobertura. Ausencias/conflictos no se convierten en ceros.
- `resumen.csv`: conteos y porcentajes por campo/comparación, incluyendo ausentes y claves extra del candidato.
- `top20_por_campo.csv`: hasta veinte mayores diferencias absolutas **por campo y comparación**, con hipótesis. No se ordenan juntos porcentajes y atenciones, pues tienen distintas unidades.
- `ejecucion.json`: versión de pandas, configuración, cobertura, conflictos y SHA-256 de cada fuente; permite detectar una ejecución con archivos distintos. La consola imprime resumen y diferencias.

Salida del proceso 0 significa «informe generado», no «se alcanzó el 98 %». Entradas inválidas o claves de base duplicadas terminan con error; las diferencias numéricas se reportan para diagnóstico.

## Fuentes y cobertura

Se leen **solo nueve columnas** de Dotacion_2026: IT, PersonaId, Fecha de Nacimiento, Periodo, Fecha Término, Horas Semanales, Cargo, Cod_Esp y Ndias. De nacimiento se conserva únicamente el mes para aplicar el beneficio de cumpleaños; la fecha completa se elimina del DataFrame de trabajo y no se exporta. Se eliminan filas sin persona numérica; claves BUK duplicadas causan error, no se promedian.

La fuente utilizada tiene **3.123 registros y 465 pares persona/IT**, con meses enero–julio. No se modificó el Excel ni se creó una base anual sintética. Los campos objetivo extraídos del otro Excel contienen 455 claves de %Dir, 469 de atención semanal y 3.752 de plan mayo–diciembre, después de reducir duplicados por clave.

En los cuatro campos leídos para el análisis (%Dir, semanal, plan y semhab), hay **35 claves repetidas con valores en conflicto**: 1 de %Dir, 2 semanales, 16 de plan y 16 de semhab. Se conservan como referencia ambigua sin valor comparable. No se escoge el primer valor ni se promedian los valores; podrían representar una dimensión perdida en el CSV y deben revisarse con el extractor/Excel. Tampoco se ocultan personas ausentes de BUK ni las claves extra del candidato.

Huellas de las dos fuentes principales de esta ejecución:

```text
BUK:          8a78dc92bf9fcbaced4bd7f42f95871e85ed543003fc4b2227867e9ef5c47abf
esperado.csv: 942748c2f9dc8dd5e40fe17b5fc997a9da9f050fca960c1715f3b02d46cd0111
```

## Reglas implementadas y supuestos

1. **Parámetros generales ausentes del CSV:** no existe param_general.csv en data\csv. Se utiliza [tools/param_general_verificacion.csv](../tools/param_general_verificacion.csv), una transcripción explícita de reglas.md/contexto.md, editable con procedencia por clave. No es el seed ni una lectura de param.general de Andrés. Los CSV param_cargo, param_calendario, param_grupal y param_asignacion se leen directamente; conflictos de cargo/tramo o zona/mes se rechazan.
2. **Modelo estricto:** solo calcula meses con fila BUK; agosto–diciembre quedan sin valor cuando no existe contrato observado. Su promedio de horas es parcial, no un promedio anual certificado. **Continuidad:** únicamente para quienes llegan al último mes global BUK, prolonga la última jornada/cargo hasta diciembre, sin superar un término conocido. Es un escenario matemático etiquetado, no una nueva fuente. No inventa nuevas altas ni considera la falta de fila una baja definitiva. No prorratea días de ingreso/término dentro del mes: el beneficio y la exposición diaria requieren definición adicional.
3. **Promedio y tramo:** ponderación por días calendario de los meses representados, umbrales 40/22. El documento no define completamente la ponderación anual; otra ponderación debe acordarse, no seleccionarse según la que mejor calce. La jornada legal ya se refleja en BUK (44 en enero–abril y 42 desde mayo para muchos contratos), por lo que no se aplica una segunda rebaja automática.
4. **Cargo:** coincidencia exacta normalizada (mayúsculas, acentos y espacios exteriores) con param_cargo. No se adivina una homologación por parecido. Todos los cargos de esta fuente tienen coincidencia; varios Cod_Esp BUK difieren del código de la regla de cargo y se señalan como hipótesis. Eso importa especialmente para grupos.
5. **NAS y %Dir:** NAS = pct_nas × promedio; %NAS = (NAS + asignaciones) / (horas − colación); %Dir final = pct_dir × (1−%NAS)/(pct_dir+pct_ind). Las asignaciones individuales se fijan en **0 por falta de fuente**, no porque se haya demostrado su ausencia. param_asignacion tiene **33 registros de tipos, con repeticiones**; no identifica qué persona tiene cada tipo. Sumarlos a todos sería incorrecto. El caso documentado de 137732 necesita dos horas de Líder Equipo: la base sin esa entrada predice 39 atenciones/semana frente a 36 esperadas.
6. **Colación y pausa:** base sin colación, porque no viene el beneficio individual. `--colacion` prueba descontar 0.25 h × Ndias, sin afirmar que todos tengan ese beneficio. La pausa 10 %/6 % se calcula como dato intermedio; no se resta adicionalmente porque las fórmulas escritas de NAS/%Dir/atenciones no indican dónde introducirla. Hacerlo podría descontarla dos veces; es una pregunta para Andrés.
7. **Semanas/plan:** semanas = round((días−inhábiles)/5, 1) con calendario general; se descuentan medio día en septiembre, un día en diciembre y, desde julio, medio día en el mes de cumpleaños cuando se conoce. Licencias, vacaciones, permisos y días adicionales se fijan en 0 por ausencia de fuente individual. No se usa semhab del esperado para construir este cálculo. Los calendarios zonales no están en el CSV exportado; Arica/Aysén quedan señalados. `excepciones.csv` no forma parte de las entradas solicitadas y no se aplica automáticamente como si fueran horas adicionales.
8. **Atenciones:** floor(horas disponibles × %Dir final × 60 / min_directa); plan = floor(atenciones semanales × semhab), siempre **floor(x + 1e-9)**. Minutos/denominadores nulos o una distribución fuera de rango producen valor no comparable, no un cero aparentemente correcto. La fórmula grupal de reglas.md está abierta: la base es individual. Hay una sensibilidad separada, no una regla aprobada.
9. **Comparación de escalares:** el esperado contiene un único %Dir/atención semanal para mayo–diciembre. Se compara con el último mes disponible del modelo, no con un promedio ajustado al objetivo; diciembre solo es representable si pudo proyectarse. Se conservan los resultados por mes en calculo.csv para revisar cambios de jornada. El supuesto de que esa fila represente todo mayo–diciembre debe validarse.

## Coincidencia independiente observada

Tolerancia absoluta **1e-9** en %Dir (fracción 0–1); igualdad exacta para conteos. «% comparables» usa solo referencia y cálculo numéricos; «% total» incluye también referencias ausentes, conflictivas o no calculables en el denominador. Es necesario mirar ambos.

| Modelo / campo | Referencias | Comparables | Coinciden | % comparables | % total |
|---|---:|---:|---:|---:|---:|
| Estricto · %Dir final | 455 | 449 | 19 | 4.232 | 4.176 |
| Estricto · directas/semana | 469 | 448 | 96 | 21.429 | 20.469 |
| Estricto · plan mayo–dic | 3.752 | 1.331 | 80 | 6.011 | 2.132 |
| Continuidad · %Dir final | 455 | 449 | 19 | 4.232 | 4.176 |
| Continuidad · directas/semana | 469 | 448 | 98 | 21.875 | 20.896 |
| Continuidad · plan mayo–dic | 3.752 | 3.536 | 84 | 2.376 | 2.239 |

Cada modelo tiene además una clave escalar propia extra fuera del esperado y ocho claves mensuales extra (una por mes). No se suman como aciertos de cobertura. El mejor porcentaje de la sensibilidad conjunta `--colacion --grupal-hipotesis` para continuidad es **23.214 % semanal** y **4.893 % mensual**, pero %Dir cae a **0 %**. No respalda aplicar colación indiscriminadamente ni ajustar el modelo al mayor porcentaje.

## Veinte mayores diferencias mensuales

Modelo **continuidad base**, sin colación ni factor grupal. Orden por diferencia absoluta, desempate persona/IT/mes. Son hipótesis que requieren revisar las entradas, no causas confirmadas. Agosto–diciembre usan continuidad hipotética.

| persona_id | IT | Mes | Excel | Independiente | Diferencia | Hipótesis |
|---:|---:|---:|---:|---:|---:|---|
| 136947 | 131 | 6 | 330 | 92 | −238 | Grupal UEDA; factor candidato 3.75 |
| 136947 | 131 | 7 | 330 | 96 | −234 | Grupal y semanas individuales |
| 136947 | 131 | 8 | 315 | 92 | −223 | Grupal y continuidad futura |
| 136947 | 131 | 10 | 315 | 92 | −223 | Grupal y continuidad futura |
| 136947 | 131 | 11 | 315 | 92 | −223 | Grupal y continuidad futura |
| 136947 | 131 | 9 | 307 | 90 | −217 | Grupal, descuentos y continuidad |
| 136947 | 131 | 12 | 299 | 88 | −211 | Grupal, descuentos y continuidad |
| 71743 | 81 | 5 | 285 | 83 | −202 | Grupal UEDA; ponderación de jornada |
| 136947 | 131 | 5 | 283 | 83 | −200 | Grupal y semanas individuales |
| 71743 | 81 | 6 | 279 | 92 | −187 | Grupal; semhab Excel 3.72381 |
| 111576 | 51 | 6 | 0 | 172 | +172 | semhab Excel 0; ausencia/licencia/vacación por identificar |
| 71720 | 51 | 7 | 0 | 171 | +171 | semhab Excel 0; falta novedad individual |
| 72873 | 131 | 6 | 0 | 168 | +168 | semhab Excel 0; falta novedad individual |
| 73095 | 81 | 6 | 0 | 163 | +163 | semhab Excel 0; falta novedad individual |
| 123781 | 51 | 6 | 0 | 163 | +163 | semhab Excel 0; falta novedad individual |
| 121047 | 131 | 7 | 16 | 176 | +160 | Excel semhab 1.4 y solo 12 directas/semana; NAS/asignaciones |
| 71743 | 81 | 7 | 255 | 96 | −159 | Grupal y semanas individuales |
| 73021 | 131 | 7 | 0 | 158 | +158 | semhab Excel 0; falta novedad individual |
| 132575 | 81 | 6 | 220 | 63 | −157 | Grupal UTAC; factor candidato 3.75 |
| 73021 | 131 | 6 | 0 | 151 | +151 | semhab Excel 0; falta novedad individual |

Las mayores diferencias simples refuerzan la falta de NAS individual: 72052/131 tiene %Dir esperado 0.141612 frente a 0.700000, y 8 directas/semana frente a 39. 121047/131 tiene 0.200223 frente a 0.647456 y 12 frente a 40. También revisar 126984/81 (11 frente a 40). El CSV top20_por_campo contiene las veinte de **cada** campo, sin mezclar unidades.

## Hallazgo sobre atención grupal: diagnóstico separado

Para aislar la última operación se calculó floor(ate_dir_semana_Excel × semhab_Excel). Coincide en **3.000/3.736 = 80.300 %** de celdas comparables, no en el 100 %. Esto revela que la fórmula mensual escrita por sí sola no reproduce muchas filas aun usando los valores intermedios del Excel.

Se ensayó la hipótesis:

```text
factor = (1 − pct_grupal) + pct_grupal × pacientes_grupo
plan = floor(ate_dir_semana_Excel × semhab_Excel × factor + 1e-9)
```

El porcentaje/pacientes proviene de param_grupal por **último Cod_Esp BUK observado** de cada persona/IT y grupo IT (131/81 San-Con; otros). Un código sin entrada usa factor individual 1 en esta hipótesis. No se selecciona el factor que mejor calza con cada persona. Para UEDA/UTAC en San-Con, 1−0.55+0.55×6 = **3.75**; para 136947, junio, floor(21×4.2×3.75) = **330**.

Este diagnóstico reproduce **3.664/3.696 = 99.134 %** de los comparables, pero **3.664/3.752 = 97.655 %** del total de claves esperado; faltan 56 por conflicto/cobertura. Quedan 32 diferencias comparables, ocho meses en cada par: **71926/131, 74761/131, 109828/131 y 111842/131**. Revisar especialmente homologación/código especial y naturaleza de las atenciones de esas personas.

**No es una validación independiente al 99 %:** usa atención semanal y semhab del propio objetivo, y la fórmula grupal sigue siendo hipótesis. Su valor es indicar a Andrés qué parte de la reconstrucción investigar. El escenario independiente con `--grupal-hipotesis` aplica el mismo factor a sus propios resultados, manteniendo separado el diagnóstico del objetivo.

## Comparar un CSV real de Andrés

```powershell
python tools\verificar_calculo.py --plan C:\PlanBot\respaldo\plan_mes.csv --salida tools\resultados\con_base
# Si el campo mensual directo tiene otro nombre físico:
python tools\verificar_calculo.py --plan C:\PlanBot\respaldo\plan_mes.csv --columna-plan nombre_real
```

CSV UTF-8 separado por coma, con encabezado y columnas **persona_id, it, mes** (entero 1–12); solo se compara mayo–diciembre. Formato ancho: `plan_ate_dir` o alias `atenciones_dir`; opcionales `pct_dir_final` y `ate_dir_semana`. Se ignoran columnas adicionales. Si los nombres físicos difieren, usar --columna-plan para el plan directo o un CSV largo con `persona_id,it,mes,campo,valor`, con campo de los tres nombres canónicos. El archivo recibido no se modifica.

Claves duplicadas se rechazan: un export con varios escenarios/versiones debe filtrarse antes, nunca promediarse aquí. El programa informa los campos no exportados, preserva NULL como incomparables y distingue:

- **base_vs_excel:** base frente a los valores Excel. Como %Dir/semanal del Excel son escalares may–dic, se repiten para cada mes; esas repeticiones no son ocho observaciones independientes.
- **base_vs_estricto / base_vs_continuidad:** base frente a cada cálculo propio, con el mismo horizonte mensual y cobertura visible.

El adaptador se probó de punta a punta con un CSV parcial de una fila **generado exclusivamente para probar el lector**, más pruebas de alias/duplicados. No se recibió un export real de calc.plan_mes: no se atribuye ninguna coincidencia ni error a la base de Andrés. Un 100 % en una sola fila comparable no significa 100 % del universo; el resumen conserva los faltantes.

## Siguiente para llegar a una validación útil del 98–100 %

1. Resolver las claves ambiguas del esperado y confirmar el nivel persona/IT/cargo con el equipo, sin cambiar contratos unilateralmente.
2. Aportar jornada/vigencia de agosto–diciembre y definir el promedio ponderado anual. El escenario de continuidad no sustituye ese insumo.
3. Incorporar asignaciones por persona y las novedades mensuales (licencias, vacaciones, permisos, días adicionales), y acordar colación/calendario zonal. Las tablas de tipos no bastan.
4. Confirmar la fórmula grupal y la homologación entre Cargo y Cod_Esp; revisar los cuatro residuos identificados. Acordar cómo se integra pausa saludable en las fórmulas.
5. Ejecutar --plan con el export real. Solo afirmar 98–100 % con cobertura explícita y trazabilidad de entradas, no con valores del esperado usados como predictores.

Pruebas ejecutadas: siete tests en verde (ejemplo documentado 137732, floor con epsilon, NAS imposible, cobertura/ausentes/extras, conflicto del objetivo, CSV de base/duplicados, continuidad respetando término y factor grupal como hipótesis). No está disponible scripts\test.ps1 en este clon; no se modificaron carpetas del back ni del front.
