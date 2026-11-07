# Verificación independiente del cálculo

Ejecución: **7 de noviembre de 2026**, Windows/Python 3.12, pandas 3.1.1 y openpyxl 3.1.5. Código: [tools/verificar_calculo.py](../tools/verificar_calculo.py). No consulta PostgreSQL ni lee código de `database\`, `api\`, `web\` o `scripts\`. El cálculo independiente se ejecuta **antes** de abrir esperado.csv; no se ajustan sus parámetros para maximizar coincidencias.

**Resultado:** con las fuentes disponibles y los supuestos explícitos siguientes **no se reproduce el 98–100 %** anunciado en reglas.md. El escenario de continuidad coincide en 4.232 % del %Dir final, 21.875 % de las atenciones directas semanales y 2.376 % del plan mensual comparable. Esto no demuestra un error del SQL de Andrés: faltan entradas individuales, el año BUK está incompleto y existe una fórmula grupal abierta. El resultado del SQL real aún no se ha recibido.

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
