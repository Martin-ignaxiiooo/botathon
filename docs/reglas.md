# Reglas de cálculo (reconstruidas del Excel)

La hoja `Dotacion_Asistencial` del Excel tiene las fórmulas pegadas como valores; estas reglas se reconstruyeron desde los números y se compararon contra las 447 filas con horas. Toda constante va en `param.general` o en las tablas `param.*`.

| Paso | Regla | Coincide con el Excel |
|---|---|---|
| Tramo | Promedio ponderado anual de horas: tramo 1 si >= 40, tramo 2 si >= 22, tramo 3 si < 22 | (definido por el enunciado) |
| Distribución | %Dir, %Ind, %NAS por cargo homologado y tramo (`param_cargo`) | tabla |
| Pausa saludable | 10 % de las horas semanales si son >= 40; 6 % si son menos | 100 % |
| Horas NAS | %NAS × promedio ponderado de horas | 100 % |
| % NAS con asignaciones | (horas NAS + horas de asignaciones) / (horas semanales − colación en contrato) | 90 % |
| % Dir final | %Dir × (1 − %NAS con asignaciones) / (%Dir + %Ind); igual para el indirecto | 100 % |
| Atenciones por semana | floor(horas disponibles × %Dir final × 60 / minutos directa); indirecta con 30 min. Horas disponibles = horas semanales − colación en contrato | 98–99 % |
| Semanas del mes | round((días del mes − inhábiles) / 5, 1) | 100 % |
| Semanas hábiles del profesional | semanas del mes − licencias − vacaciones − permisos; en jul–dic además: días adicionales / 6 meses, cumpleaños 0,5 día en su mes, víspera Fiestas Patrias 0,5 en septiembre, Navidad/Año Nuevo 1 en diciembre. 1 día = 0,2 semanas | casi siempre |
| Atenciones del mes | floor(atenciones por semana × semanas hábiles) | 100 % en may–dic |
| Meta del mes | floor(atenciones del mes × 0,9) | 99,8 % |
| % FOJA | horas mensuales disponibles para atención directa / horas mensuales contratadas | (definido por el enunciado) |

## Dos períodos
2026 tiene jornada legal de 44 h hasta abril y 42 h desde mayo. El Excel solo guarda el cálculo semanal de mayo–diciembre ("N° Ate Directas ... may - dic"), por eso enero–abril coincide solo 64 % si se usa ese valor: hay que calcular enero–abril con las horas de ese período.

## Ejemplo verificado (PersonaId 137732, Arica, médico fisiatra, 40 h)
- NAS 20 % (8 h) + asignación "Líder Equipo" 2 h → %NAS con asignaciones = 10/40 = 0,25
- %Dir final = 0,65 × 0,75 / 0,80 = 0,609375 · %Ind final = 0,140625
- Directas/semana = floor(40 × 0,609375 × 60 / 40) = 36 · Indirectas = floor(40 × 0,140625 × 60 / 30) = 11
- Enero: 4,2 semanas → floor(36 × 4,2) = 151; meta floor(151 × 0,9) = 135
- Febrero: 1 semana (vacaciones) → 36; meta 32

## Puntos abiertos (consultar con mentores, dejar parametrizado)
- Regla exacta de enero–abril.
- Julio descuenta menos que agosto–diciembre.
- Algunos casos de % NAS con asignaciones no calzan (posibles cambios de jornada).
- Fórmula de atención grupal (ED, AS, UTAC, UEDA, ULAB): % grupal y pacientes por grupo según Santiago/Concepción u otros.
- Beneficio de colación 15 min = 0,25 h × días/semana, pero algunos cargos lo tienen en 0.

## Datos que el BUK no trae
Licencias, vacaciones, permisos, asignaciones, colación en contrato, días adicionales: en el MVP salen de `stg.esperado`/Excel o quedan en 0 y parametrizables; documentar el supuesto.
