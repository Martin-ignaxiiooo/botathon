# Contexto del proyecto

Botathon 2026, desafío "Cada hora cuenta" de Teletón Chile. Equipo 33: Andrés (back: SQL y cálculo, con Claude Code), César (front, datos de prueba, CI y código C# para Blue Prism, con Claude Code y Codex de respaldo), Lucas (Blue Prism). Revisión cruzada de PR entre Andrés y César.

## El problema
La planificación asistencial de Teletón vive en un Excel de más de 600 profesionales, alimentado a mano desde reportes de BUK (RR.HH.) y SIC (atenciones realizadas). Define, por profesional y mes, cómo se reparten sus horas contratadas entre atención directa (con pacientes), indirecta (registros, informes) y no asistencial (NAS: coordinación, capacitación, comités, asignaciones especiales), y con eso su meta de atenciones (indicador de desempeño). Dolores: errores manuales, sin trazabilidad ni versiones, carga manual desde BUK, parámetros escondidos, poca visibilidad, asignaciones juntadas por correo.

## El MVP (16 horas)
Debe reemplazar el Excel: incorporar los reportes sin copiar y pegar (detectando e informando errores), aplicar reglas parametrizables, calcular por profesional y mes, detectar cambios durante el año (jornada, cargo, altas, bajas) y recalcular desde la fecha en que rigen, y mostrar un dashboard nacional filtrable por instituto, área, cargo, mes y profesional.
Indicadores: Meta de Gestión Asistencial = atenciones planificadas × 90 %; % FOJA = horas mensuales disponibles para atención directa / horas mensuales contratadas.
Blue Prism es obligatorio y debe verse en la demo (5 minutos: procesar un BUK y mostrar su efecto).
Deseables: trazabilidad, comparación con SIC, multi-instituto, reemplazos y vacantes, aprobación de asignaciones, simulación de parámetros, distribución de reportes.
Datos ficticios; diseño con protección de datos personales (ley chilena): control de acceso, trazabilidad, mínimo de datos.

## Solución en 3 partes
1. **Ayudante que recibe los datos:** Blue Prism 7.5.1 en una VM Windows. Lee los Excel de `C:\PlanBot\entrada\*`, limpia, valida fila por fila (cola de trabajo), escribe en `stg.*` por ODBC y llama funciones SQL.
2. **Aplicación que arma todo:** PostgreSQL 16 con las reglas en tablas `param.*` y el cálculo en funciones y vistas; PostgREST como API.
3. **Dashboards:** HTML + JavaScript + ECharts + Tabulator.

## Fuentes
- `data\excel\Nac - Base contratos x mes.xlsx`: hoja Dotacion_2026, encabezados en la fila 2, ~878 filas vacías y un encabezado repetido; una fila por persona y mes (464 personas, ~3.100 filas). Columnas: IT, Instituto, PersonaId, Área, Nombre Sub-área, Centro de Costo, Fecha de Nacimiento, Periodo, Tipo de Contrato, Tipo_Trab_161225, Fecha Ingreso Compañía, Fecha Término, Horas Semanales, Cargo, Tipo_Trabajador, Días de la Jornada, Reg_SIC, Cod_Esp, Ndias.
- `data\excel\Nac - Planificacion Asistencial x mes.xlsx`: reglas (Parámetros, Distribucion_NAC, Excepciones, Calendario 2026) y resultado esperado (Dotacion_Asistencial, 471 filas). Ya extraído a `data\csv\`.

## Institutos (IT)
11 Ari · 12 Iqu · 21 Ant · 22 Cal · 31 Cop · 41 Coq · 51 Val · 61 OHi · 71 Tal · 81 Con · 91 Tem · 101 PMo · 102 Cas · 111 Coy · 131 San · 141 Vdv. Grupo San-Con (Santiago y Concepción) para la regla grupal. Zonas con calendario especial: Arica (feriado 7 de junio), Ñuble (20 de agosto), Aysén/Coyhaique (vacaciones distintas).

Más detalle: `docs\reglas.md` y `docs\contratos.md`.
