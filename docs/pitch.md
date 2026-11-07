# Pitch · Tres minutos

Guion hablado de unas 400 palabras. Ensayar con cronómetro. El contexto de «más de 600 profesionales» proviene del desafío descrito en [contexto.md](contexto.md); el archivo BUK de prueba tiene una cobertura menor y solo enero–julio. Presentar las funciones de escenario/accesibilidad como demostradas únicamente después de verificarlas en la VM. Las metas de impacto siguientes no son resultados de un piloto.

## Guion hablado

En Teletón, cada hora cuenta. Sin embargo, planificar la atención de más de seiscientos profesionales todavía exige coordinar planillas, revisar contratos y reunir asignaciones que llegan por correo. Planificación central y las jefaturas necesitan saber cuántas horas pueden destinar a atención y qué metas corresponden a cada instituto. Cuando cambia una jornada o un cargo, volver a revisar el Excel consume tiempo y dificulta reconstruir quién cambió qué.

Somos el equipo 33 y proponemos PlanBot: convertir esa carga administrativa en un proceso trazable, para que el equipo dedique más tiempo a organizar la atención de niños, niñas y jóvenes.

¿Por qué un bot? Porque los reportes y las tareas de hoy ya existen. Blue Prism puede recibirlos, validarlos y coordinar el trabajo sin exigir que todas las fuentes cambien primero. Si mañana hay una API autorizada, podremos incorporarla conservando las mismas validaciones y cálculos.

Así funciona: el robot recibe un archivo, comprueba si ya fue procesado y limpia las filas vacías. Revisa personas, fechas, horas, institutos y cargos. Informa los errores por fila, para corregirlos sin revisar toda la planilla. PostgreSQL guarda reglas versionadas, detecta cambios y recalcula desde el mes en que rigen. El dashboard presenta el resultado nacional y permite bajar al instituto y al profesional.

Nuestra propuesta reúne reglas editables, recálculo automático, cuadratura contra el Excel y simulación antes de aprobar un cambio. La meta inicial es el noventa por ciento de las atenciones planificadas. FOJA muestra la proporción de horas contratadas disponible para atención directa. Las decisiones quedan vinculadas a una versión y un motivo.

La solución usa Blue Prism, PostgreSQL y una web sin instalación para sus usuarios. Un mismo proceso puede atender todos los institutos; más Digital Workers permiten distribuir las cargas. Buscamos una interfaz operable con teclado, compatible con lector de pantalla, con tablas alternativas y lenguaje claro.

¿Cómo mediremos el impacto? Compararemos las horas de trabajo manual por carga con el tiempo de supervisión del robot. Contaremos errores detectados automáticamente y correcciones pendientes. Cronometraremos el recálculo: el objetivo es pasar de revisiones que pueden tomar días a resultados en segundos, verificando siempre su exactitud. En las pruebas locales, el validador detectó los cinco errores intencionales del archivo de ensayo.

PlanBot no promete crear horas clínicas por sí solo. Propone recuperar tiempo de planificación, hacer visibles los cambios y dar a las jefaturas información consistente para decidir mejor.

## Ocho preguntas del jurado

| Pregunta | Respuesta breve |
|---|---|
| ¿Por qué no usar directamente la API de BUK? | No asumimos que esté habilitada ni autorizada para el desafío. Partimos de los reportes disponibles; una API puede sustituir la recepción sin cambiar el motor de reglas. |
| ¿Cómo protegen los datos? | Usamos persona_id como identificador, acceso por roles y claves en Credential Manager; evitamos nombres, RUT y datos de pacientes en la carga del motor. El identificador sigue siendo dato personal si puede vincularse a una persona. |
| ¿Cuánto cuesta? | Deben presupuestarse licencias de Blue Prism, workers, VM, operación y soporte; PostgreSQL y el front no requieren un servidor de aplicación propio. No tenemos una cotización de producción validada. |
| ¿Cómo escala? | Misma lógica por instituto, colas compartidas y más workers cuando la medición lo justifique. Hay que controlar duplicados, cargas parciales y recálculos concurrentes; aún no afirmamos una prueba nacional de carga. |
| ¿Qué pasa si cambia la ley de jornada? | Se actualiza el parámetro y su vigencia, se prueba contra casos conocidos y se aprueba una nueva versión. Si cambia la fórmula, requiere además modificación y pruebas del SQL. |
| ¿Quién aprueba las reglas? | El flujo propuesto separa preparación, simulación y aprobación por una persona autorizada. La versión anterior y el motivo deben conservarse; el robot no aprueba por sí solo. |
| ¿Qué pasa si falla el robot? | La cola y carga_id permiten ubicar el punto de falla. Se revisan los lotes confirmados antes de reintentar. Para la demo tenemos respaldo y video; en operación se acuerdan alertas, responsables y recuperación. |
| ¿Cómo se audita? | Archivo y hash identifican la carga; los cambios incluyen antes/después y vigencia; el registro de auditoría vincula cambios con motivo y versión. Esa cadena debe verificarse en el ensayo integrado. |

## Hoja de medición para el ensayo

| Indicador | Cómo medir | Resultado |
|---|---|---|
| Horas ahorradas por carga | (minutos manuales − minutos de intervención humana con robot) / 60; misma entrada y alcance | Pendiente de medir |
| Errores intencionales detectados | Persona/campo contra esperado_errores.csv | 5/5, prueba local C#; falta ensayo BP |
| Tiempo total del robot | Fin − inicio de sesión, incluyendo esperas y carga | Pendiente de medir |
| Tiempo de recálculo | Tiempo reportado por función/cronómetro y comprobación de meses previos | Pendiente; objetivo contractual <10 s |
| Cuadratura | Resultado de cuadratura() y explicación de diferencias por campo/mes | Pendiente de integración |

No convertir el objetivo de segundos, los días del proceso manual ni las horas ahorradas en cifras medidas hasta registrar una comparación real.
