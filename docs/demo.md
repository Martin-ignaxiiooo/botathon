# Demo PlanBot · Cinco minutos

Objetivo: mostrar a Blue Prism procesando un BUK, el efecto de los cambios en el dashboard y errores identificados por fila. Lucas opera Control Room; César conduce el dashboard; Andrés confirma cálculo/consultas si hace falta. Ensayar en la VM y ajustar los tiempos al release real. Este es un guion de ejecución, no evidencia de que la integración ya esté validada.

## Preparación previa

- [ ] Confirmar release BP 7.5.1, Check Code sin errores, Runtime Resource conectado, procesos publicados y nombre real de la cola. Anotar qué proceso orquesta P01–P05; no inventar nombres de menú o cola.
- [ ] Probar ODBC con SELECT 1; revisar Credential Manager PlanBot_Postgres y ConnStrSinClave sin proyectar su contenido. Servicios PostgreSQL, PostgREST y dashboard disponibles.
- [ ] Cargar reglas con P00 dejando la planilla en `C:\PlanBot\entrada\planificacion`; comprobar versión vigente y conteo de reglas.
- [ ] Cargar `data\buk\01_original.xlsx` mediante el robot en `C:\PlanBot\entrada\buk`. Guardar un snapshot/dump **posterior al original y anterior a 02/03**; ese es el punto de inicio de cada ensayo.
- [ ] Dejar carpetas de entrada limpias, sin archivos a medio copiar. Colas de demostración sin ítems pendientes/en ejecución; conservar el historial necesario para trazabilidad, no borrar cargas ni hashes manualmente. Si 02/03 ya están registrados, restaurar el snapshot de ensayo antes de empezar.
- [ ] Tener `02_cambios.xlsx`, `03_errores.xlsx` y los esperado_*.csv en el escritorio real del usuario (puede estar en OneDrive). No depender de descargar nada durante la exposición. Verificar que sean la misma versión del commit de D-04.
- [ ] Abrir Control Room, la cola del release y el dashboard Nacional en ventanas listas para alternar. Usar `http://localhost:8080/?modo=api#nacional` y confirmar que corresponde a la base de demo, sin datos mock.
- [ ] Mostrar solo persona_id; evitar pantallas de credenciales, datos originales adicionales o logs sensibles. Preparar zoom legible y una navegación breve con Tab para mostrar acceso por teclado.
- [ ] Anotar los KPI originales y los resultados de los cinco cambios del ensayo. Guardar captura posterior a 02 para el cierre, porque 03 está construido sobre el original y puede cambiar nuevamente el plan.
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
| 0:00–1:00 | No dejar archivos nuevos. Partir de la base con 01_original y reglas ya cargadas. | Nacional: fecha de última carga, dotación, atenciones, meta y FOJA. Luego Control Room: recurso disponible y sesión previa de 01_original completada. | «Este es el punto de partida: contratos y reglas ya cargados por Blue Prism. La meta inicial es 90 % y FOJA relaciona horas directas con horas contratadas. Ahora cargaremos un archivo con cinco cambios conocidos». |
| 1:00–2:00 | Dejar **02_cambios.xlsx** en `C:\PlanBot\entrada\buk`; iniciar el orquestador de P01–P05 o dejar actuar el schedule ensayado. | Control Room: sesión en ejecución. Cola: ítem adquirido/bloqueado y resultado al terminar, según el diseño real (por archivo o fila). Registro de carga: archivo, carga_id y conteos; etapa de limpieza/validación/cálculo. | «El robot identifica el archivo, limpia cabeceras y blancos, valida contra catálogos y carga las filas válidas. Después llama al motor SQL para detectar cambios y recalcular desde su vigencia». |
| 2:00–3:00 | Esperar fin correcto de 02 antes de continuar. | Dashboard Cambios: filtrar por carga_id recién obtenido y contrastar las cinco filas del CSV. Abrir Profesional 71555, comparar abril con mayo; mostrar traslado 71146 de junio a julio. Volver a Nacional y guardar la captura posterior a cambios. | «Aquí están las cinco decisiones: cargo desde marzo, alta desde abril, jornada desde mayo, baja desde junio y traslado desde julio. La jornada pasa de 40 a 30; el historial anterior se conserva. El SQL del ensayo verifica también los meses anteriores, no solo el total». |
| 3:00–4:00 | Dejar **03_errores.xlsx** en `C:\PlanBot\entrada\buk`; ejecutar el mismo flujo de entrada acordado con Lucas. | Control Room y cola: procesamiento y estado real de filas/carga. Dashboard Cambios/errores: filtrar por el nuevo carga_id y mostrar persona, campo, fila original y motivo. Si esa pantalla aún no está integrada, usar la consulta api.v_errores_carga del guion E2E y explicitarlo. | «Este segundo archivo contiene cinco errores intencionales. No se pierde la ubicación: se informa el campo y la fila para corregirla. Una fila puede tener varios errores; las filas rechazadas no se envían como válidas. En la prueba local se detectaron los cinco; aquí comprobamos el recorrido completo». |
| 4:00–5:00 | Una vez terminado 03 y retirado de entrada, volver a dejar **el mismo 03_errores.xlsx**, con igual contenido. | Control Room/cola: resultado «archivo repetido» por hash y ausencia de una nueva carga de filas. Cerrar con la captura de Nacional posterior a 02, claramente identificada, o con la pantalla actual explicando a qué carga corresponde. | «Aunque se vuelva a dejar el archivo, su huella evita procesarlo dos veces. Conservamos archivo, carga, errores y cambios para auditar. Mediremos ahorro de intervención humana y duración del recálculo: la meta es liberar tiempo de planificación para apoyar la atención». |

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

La simulación de meta 0.85 es una extensión opcional si sobra tiempo y está integrada: mostrar borrador, diferencias y aprobación humana. No aprobar reglas durante una falla ni sacrificar la demostración de Blue Prism para abrir una pantalla aún no operativa.

## Si algo falla en vivo

| Falla | Acción del operador | Qué comunicar |
|---|---|---|
| Recurso desconectado, inicio lento o sin respuesta por más de 20 segundos | Revisar estado una vez; no lanzar sesiones adicionales. Continuar con video local del ensayo. | «La ejecución en vivo está detenida; mostraremos el ensayo grabado y su resultado identificado». |
| ODBC/SQL falla o el proceso termina en excepción | Mostrar el estado sin claves, guardar carga_id y detener nuevos archivos. No reintentar una carga masiva completa a ciegas: puede tener lotes confirmados. | «La carga queda identificada para conciliar y recuperar; no la damos por completada». |
| El archivo aparece como repetido al primer intento | No renombrar para intentar saltar el hash ni alterar contenido. Usar evidencia del ensayo; restaurar snapshot después de exponer. | «Esta base ya registraba la huella del archivo; la detección está evitando duplicarlo». |
| Dashboard vacío o API inaccesible | Comprobar URL una vez; si SQL está disponible, mostrar consulta contractual o captura/video con fecha y carga. | «Esta es la evidencia SQL/del ensayo; la vista en vivo no está disponible». No cambiar silenciosamente a mocks. |
| Los errores o cambios no coinciden con CSV | Conservar archivos/IDs y anotar discrepancia. No declarar éxito ni cambiar esperado_*.csv en vivo. | «El resultado difiere del caso esperado y debe revisarse antes de aprobarlo». |
| Falta tiempo | Omitir repetición de archivo o extensión de escenarios; cerrar con el resultado de 02 ya obtenido. | «La detección de errores/repetidos está documentada en el ensayo; hoy mostramos el recorrido que alcanzó a completarse». |

No reiniciar servicios ni restaurar una base durante los cinco minutos frente al jurado. La recuperación se realiza después, con respaldo y conciliación. Mantener visibles los límites reales del MVP.
