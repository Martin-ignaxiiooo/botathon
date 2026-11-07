# Demo PlanBot · Cinco minutos

Guion único para la exposición. Integra las «Notas para la demo» de docs\progreso-front.md contrastadas con el código de origin/main en **3829f23** (7-nov). Lucas opera Control Room; César conduce el dashboard; Andrés confirma cálculo/consultas si hace falta. Objetivo: ver Blue Prism procesar BUK, observar su efecto en Nacional y localizar errores por fila. Ensayar tiempos con el release real: este documento no certifica que el recorrido BP esté aprobado.

**Blue Prism es el camino principal.** tools\vm\simular_robot.ps1 es solo contingencia, usa psql y los mismos C# de limpieza/validación; no demuestra una sesión BP, Excel VBO ni su cola. Si se utiliza, avisar al jurado «esta carga usa el script de contingencia», conservar resumen.json/carga_id y no presentarlo como ejecución del robot. La alternativa preferida ante una falla de BP durante los cinco minutos sigue siendo el video de un ensayo identificado.

## Direcciones listas para el jurado

Son locales a la VM proyectada; no hay una URL pública confirmada. Conservar **?modo=api antes de #** en todos los enlaces:

| Pantalla | URL |
|---|---|
| Nacional | http://localhost:8080/?modo=api#nacional |
| Cambios, carga más reciente con cambios/errores | http://localhost:8080/?modo=api#cambios |
| Carga concreta (reemplazar CARGA_ID por el ID real) | `http://localhost:8080/?modo=api#cambios?carga=CARGA_ID` |
| Jornada de 71555 | http://localhost:8080/?modo=api#profesional?persona=71555 |
| Traslado de 71146 | http://localhost:8080/?modo=api#profesional?persona=71146 |
| Evidencia técnica JSON | http://localhost:3000/v_kpi |

Si el jurado abre un enlace en otro computador, localhost designa ese otro computador: César debe proporcionar un despliegue y URL alcanzables, con API/CORS configurados. No presentar una dirección local como servicio público.

## Preparación previa

- [ ] Confirmar release BP 7.5.1, Check Code sin errores, Runtime Resource conectado, procesos publicados y nombre real de la cola. Anotar qué proceso orquesta P01–P05; no inventar nombres de menú o cola.
- [ ] Probar ODBC con SELECT 1; revisar Credential Manager PlanBot_Postgres y ConnStrSinClave sin proyectar su contenido. Servicios PostgreSQL, PostgREST y dashboard disponibles; ejecutar tools\vm\verificar_vm.ps1 y resolver/identificar cada rojo. Los RPC opcionales ausentes no certifican ni impiden por sí solos el recorrido BUK.
- [ ] Cargar reglas con P00 dejando la planilla en `C:\PlanBot\entrada\planificacion`; comprobar versión vigente y conteo de reglas.
- [ ] Cargar `data\buk\01_original.xlsx` mediante el robot en `C:\PlanBot\entrada\buk`. Guardar un snapshot/dump **posterior al original y anterior a 02/03**; ese es el punto de inicio de cada ensayo.
- [ ] Dejar carpetas de entrada limpias, sin archivos a medio copiar. Colas de demostración sin ítems pendientes/en ejecución; conservar el historial necesario para trazabilidad, no borrar cargas ni hashes manualmente. Si 02/03 ya están registrados, restaurar el snapshot de ensayo antes de empezar.
- [ ] Tener `02_cambios.xlsx`, `03_errores.xlsx` y los esperado_*.csv en el escritorio real del usuario (puede estar en OneDrive). No depender de descargar nada durante la exposición. Verificar que sean la misma versión del commit de D-04.
- [ ] Abrir Control Room, la cola del release y Nacional. Confirmar **«● En vivo: base de datos»**, datos presentes y consultas HTTP a PostgREST en Red; **«◌ Datos de prueba (mock)» no sirve para la demo integrada**. La insignia indica el modo configurado, no garantiza respuesta correcta de la base. No presentar mocks como datos recién cargados por el robot.
- [ ] Mostrar solo persona_id; evitar pantallas de credenciales, datos originales adicionales o logs sensibles. Preparar zoom legible y una navegación breve con Tab para mostrar acceso por teclado.
- [ ] Sin filtros, abrir Nacional con 01 y pulsar **Actualizar datos**. Anotar última carga/hora, dotación, atenciones, meta, horas contratadas y FOJA. Conservar esa pestaña hasta después de 02: la comparación se guarda en sessionStorage por pestaña/modo. F5 conserva el estado; cerrar la pestaña lo pierde. No limpiar almacenamiento durante la demo. Guardar captura posterior a 02 para el cierre: 03 se basa en 01 y puede cambiar nuevamente el plan.
- [ ] Probar Tab → «Saltar al contenido», foco visible, «Lectura fácil» y «Letra grande». Preparar un gráfico con «Ver datos» como tabla alternativa. Lector de pantalla real y PDF requieren ensayo humano; no afirmar una certificación a partir de una etiqueta aria o la vista de impresión.
- [ ] Tener dump, release exportado, video local de cinco minutos y capturas fechadas de un ensayo correcto. Probar el video sin Internet y marcarlo «ensayo grabado» cuando se utilice.
- [ ] Completar los resultados reales de [tests/e2e/guion.md](../tests/e2e/guion.md), en especial las consultas de cambios, errores e invariancia por vigencia. Verificar accesibilidad que se vaya a afirmar, no solo que exista una etiqueta aria.

Para evitar que el robot lea un archivo incompleto, copiar primero fuera del directorio vigilado y moverlo allí una vez terminada la copia. Ejemplo en PowerShell, ajustando el nombre del archivo según el minuto:

```powershell
$escritorioDemo = [Environment]::GetFolderPath('Desktop')
New-Item -ItemType Directory -Force C:\PlanBot\preparar | Out-Null
Copy-Item -LiteralPath (Join-Path $escritorioDemo '02_cambios.xlsx') -Destination C:\PlanBot\preparar\02_cambios.xlsx
Move-Item -LiteralPath C:\PlanBot\preparar\02_cambios.xlsx -Destination C:\PlanBot\entrada\buk\02_cambios.xlsx
```

No sobrescribir un archivo que esté siendo procesado. El horario o inicio manual debe estar acordado con Lucas para evitar que un schedule y el presentador lancen dos sesiones a la vez.

## Minuto a minuto

| Tiempo | Archivo / operación | Qué mostrar | Qué decir |
|---|---|---|---|
| 0:00–1:00 | Partir con reglas y 01 cargados. No entregar archivos nuevos; sin filtros. | Señalar «En vivo: base de datos», última carga con hora y seis KPI. Usar Tab/lectura fácil brevemente; después Control Room con recurso y sesión original. Mantener la pestaña Nacional abierta. | «PlanBot conecta los contratos con la planificación. Este es el punto de partida real: Blue Prism recibió la información y PostgreSQL la calculó. La meta es 90 %; FOJA relaciona horas directas y contratadas. Veremos el efecto de cinco cambios». |
| 1:00–2:00 | Copiar 02 vía preparar a entrada\buk; ejecutar solo el maestro/schedule ensayado. Esperar fin correcto. | Control Room y cola: ítem adquirido, carga_id y finalización. Volver a la **misma pestaña** Nacional, pulsar **Actualizar datos** (o F5). Señalar nueva fecha/hora, «Hay una carga nueva» y ▲/▼ de las tarjetas que variaron; guardar captura. | «El robot limpia, valida y llama al cálculo desde la vigencia. Ahora actualizamos la pantalla y vemos qué cambió respecto del archivo anterior. Las flechas indican variación; no significan por sí solas mejora o deterioro». |
| 2:00–3:00 | Abrir Cambios por carga_id de 02; no cargar otro archivo todavía. | Cambios selecciona la carga reciente con eventos; usar URL concreta para evitar confusiones. Contrastar cinco filas. Abrir 71555 (abril/mayo) y 71146 (junio/julio e instituto). | «Cargo desde marzo, alta desde abril, jornada de 40 a 30 desde mayo, baja desde junio y traslado desde julio. Conservamos el historial anterior; las consultas del ensayo comprueban que los meses anteriores no cambiaron». |
| 3:00–4:00 | Entregar 03 por el mismo mecanismo y completar su flujo; no restaurar BD frente al jurado. | Sesión/cola y carga_id de 03. Abrir Cambios con ese ID: persona, campo, fila y motivo. Mostrar cinco casos esperados, sin exigir que cinco mensajes sean cinco filas cuando hay varias causas. | «Este archivo trae cinco errores intencionales. Indicamos dónde corregir cada uno y excluimos las filas rechazadas. Sus filas válidas también son una nueva foto de contratos: este archivo se basa en el original, por lo que puede cambiar nuevamente el plan». |
| 4:00–5:00 | Reentregar los mismos bytes de 03 cuando terminó el intento anterior. | Cola: «archivo repetido»; puede existir un ítem de cola nuevo, pero no una nueva carga SQL ni recálculo. Cerrar con captura **identificada como posterior a 02**, o con pantalla actual explicando su carga. | «La huella evita cargar dos veces el mismo contenido. Archivo, carga, errores y cambios quedan identificados. Mediremos horas de intervención y duración del recálculo para liberar tiempo de planificación y apoyar la atención». |

### Tarjeta de los cinco cambios de 02

| Tipo | persona_id | Vigencia | Evidencia |
|---|---|---|---|
| cambio_cargo | 71132 | marzo, mes 3 | Cargo distinto, existente en la fuente |
| alta | 999001 | abril, mes 4 | Abril–julio, kinesiólogo de IT 131; donante 71279 |
| cambio_jornada | 71555 | mayo, mes 5 | 40 → 30 Horas Semanales |
| baja | 71027 | junio, mes 6 | Sin filas desde junio |
| cambio_it | 71146 | julio, mes 7 | Cambian IT e Instituto; IT destino 101 |

Para 03: 71027 horas 0; 71132 fecha término anterior al ingreso; 71146 cargo inexistente; 71232 duplicado; 71247 texto «cuarenta» en horas. Comparar por carga_id y persona/campo. Los mensajes exactos pueden variar con el validador; revisar que expliquen el mismo error.

**Importante para el operador:** 03 está basado en 01, no en 02. Si el flujo carga sus filas válidas y recalcula después de 02, puede revertir cambios de 02 o generar otros eventos. No afirmar que ese archivo solo añade errores ni que el plan permanece como tras 02; no exigir exactamente cinco cambios en la carga de 03. Para evaluar la detección de errores de forma aislada, el ensayo E2E restaura el snapshot de 01 antes de 03. Después de la exposición, restaurar ese punto para repetir la demo. No modificar los fixtures para esconder esta diferencia.

La simulación de meta 0.85 queda fuera de estos cinco minutos. Solo mostrarla después, si sus RPC/contratos y aprobación real están integrados; una decisión en modo mock vive en memoria y no demuestra aprobación/aplicación en PostgreSQL.

## Cómo leer el efecto en Nacional

El botón vuelve a consultar datos; no hay promesa de actualización instantánea automática. La insignia «Hay una carga nueva» depende de que ultima_carga cambie respecto de una carga previamente vista en esa pestaña. ▲/▼ solo aparece en magnitudes con variación suficiente; puede haber carga nueva sin flechas en todas las tarjetas. Mantener filtros limpios al comparar. Si falta ultima_carga o se pierde sessionStorage, cotejar números anotados y SQL; no inventar una diferencia visual.

Cambios arma la lista desde v_cambios/v_errores_carga: una carga sin eventos puede no aparecer y un archivo sin errores puede figurar como «Archivo no informado». Identificar siempre por carga_id de Control Room/SQL. La marca de jornada depende de claves reales de v_parametros_vigentes; si aún no coinciden con las esperadas por el front, no prometer esa marca. La pantalla de Profesional y las consultas de vigencia siguen siendo la evidencia del cambio concreto.

## Si algo falla en vivo

| Falla | Acción del operador | Qué comunicar |
|---|---|---|
| Recurso desconectado, inicio lento o sin respuesta por más de 20 segundos | Revisar estado una vez; no lanzar sesiones adicionales. Continuar con video local del ensayo. | «La ejecución en vivo está detenida; mostraremos el ensayo grabado y su resultado identificado». |
| ODBC/SQL falla o el proceso termina en excepción | Mostrar el estado sin claves, guardar carga_id y detener nuevos archivos. No reintentar una carga masiva completa a ciegas: puede tener lotes confirmados. | «La carga queda identificada para conciliar y recuperar; no la damos por completada». |
| El archivo aparece como repetido al primer intento | No renombrar para intentar saltar el hash ni alterar contenido. Usar evidencia del ensayo; restaurar snapshot después de exponer. | «Esta base ya registraba la huella del archivo; la detección está evitando duplicarlo». |
| Dashboard vacío o API inaccesible | Comprobar URL una vez; si SQL está disponible, mostrar consulta contractual o captura/video con fecha y carga. | «Esta es la evidencia SQL/del ensayo; la vista en vivo no está disponible». No cambiar silenciosamente a mocks. |
| Encabezado muestra Datos de prueba (mock) | Corregir ?modo=api, confirmar JSON/red y pulsar Actualizar; si no responde, pasar al video identificado. | «La pantalla de ejemplo no prueba la carga que acabamos de ejecutar». |
| No aparece Hay una carga nueva o faltan flechas | Revisar misma pestaña, filtros y ultima_carga una vez; cotejar los KPI anotados con SQL. | «Mostramos los valores antes/después; el indicador visual depende del estado de esta pestaña». |
| Los errores o cambios no coinciden con CSV | Conservar archivos/IDs y anotar discrepancia. No declarar éxito ni cambiar esperado_*.csv en vivo. | «El resultado difiere del caso esperado y debe revisarse antes de aprobarlo». |
| Falta tiempo | Omitir repetición de archivo o extensión de escenarios; cerrar con el resultado de 02 ya obtenido. | «La detección de errores/repetidos está documentada en el ensayo; hoy mostramos el recorrido que alcanzó a completarse». |

No reiniciar servicios ni restaurar una base durante los cinco minutos frente al jurado. La recuperación se realiza después, con respaldo y conciliación. Mantener visibles los límites reales del MVP.
