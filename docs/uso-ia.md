# Uso de inteligencia artificial

PlanBot fue desarrollado por el equipo 33 con apoyo de IA. Las herramientas ayudaron a analizar, redactar y programar; las decisiones de alcance y la responsabilidad del resultado permanecen en las personas.

| Etapa | Apoyo de IA | Revisión humana y evidencia disponible |
|---|---|---|
| Análisis del Excel | Claude Code/ChatGPT apoyaron la lectura de estructura, reconstrucción de reglas y preparación de explicaciones; el extractor produce CSV para trabajar sin recorrer planillas completas en cada consulta. | Andrés debe contrastar fórmulas y supuestos con reglas y cuadratura. docs/reglas.md conserva los puntos abiertos; no afirmar que todos fueron resueltos. |
| Plan de trabajo | IA ayudó a ordenar historias, contratos, límites de carpetas y tareas para el MVP. | César definió el reparto y las prioridades; pidió explícitamente mantener contratos y no modificar el trabajo paralelo. |
| Código y datos | Claude Code apoyó SQL/front; Codex creó C# de referencia, generador BUK, CI y documentación. | César eligió el alcance de los casos y corrigió los meses a enero–julio y la jornada 40 → 30 desde mayo. Hay commits locales y comprobaciones reproducibles. La revisión cruzada César/Andrés está prevista; no se presume realizada para cada archivo. |
| Guía de Blue Prism | ChatGPT apoyó la explicación del montaje; Codex preparó Code stages y LEEME para Lucas. | Lucas construye los objetos/procesos y debe ejecutar Check Code, revisar mapeos y probar el Runtime. No hay evidencia aquí de que el release completo ya haya pasado esas pruebas. |
| Pitch y presentación | IA ayudó a redactar arquitectura, guion, preguntas y preparación de la demo. | El equipo debe validar afirmaciones, duración y resultados antes de presentarlos. No atribuir mediciones que no se han realizado. |

## Qué se comprobó en esta entrega

Las pruebas automáticas ejecutadas por Codex incluyen copia idéntica de la fuente, reapertura de Excel, contraste de cambios por vigencia y CSV, compilaciones C# y programa de consola que detecta los cinco errores intencionales. También se verificó lint del front integrado. Son comprobaciones técnicas del agente; **no equivalen a una aprobación humana ni a una prueba integrada de Blue Prism/PostgreSQL**. El detalle está en [progreso-codex.md](progreso-codex.md).

Para cerrar la revisión, Andrés verifica reglas, resultados y permisos; César verifica escenarios, navegación y accesibilidad; Lucas verifica objetos, colas, credenciales y recuperación del robot. Registrar fecha, versión y resultado real en el [guion E2E](../tests/e2e/guion.md).

## Datos usados y límites

El trabajo utiliza contratos y datos de demostración autorizados del proyecto. No enviar credenciales, nombres, RUT ni datos de pacientes a herramientas de IA. Limpiar Dotacion elimina Fecha de Nacimiento y columnas ajenas al contrato antes de la carga. Los archivos originales pueden conservar campos adicionales: restringirlos y revisar su origen antes de compartirlos. Una cuenta o un repositorio privados no sustituyen la autorización de tratamiento.

Los textos generados por IA no certifican exactitud clínica, cumplimiento legal ni ahorro operativo. El equipo conserva los supuestos abiertos y distingue pruebas locales, objetivos y resultados de integración. No se han delegado decisiones de asignación asistencial ni aprobación de reglas a un modelo.
