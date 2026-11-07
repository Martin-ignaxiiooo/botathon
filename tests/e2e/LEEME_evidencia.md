# Evidencia SQL en la VM

Coordinar con Lucas/Andrés base de demo, ventana, pausa de otras cargas y respaldo restaurable. Estos archivos no llaman funciones ni modifican tablas persistentes: 02/03 usan tablas temporales y ROLLBACK. Ejecutar desde la raíz en PowerShell; psql/pg_dump en PATH, claves por prompt. Preparar C:\PlanBot\respaldo. No ejecutar migraciones ni restauraciones contra trabajo activo.

```powershell
psql -h localhost -p 5433 -U owner_planbot -d planbot -X -f tests\e2e\evidencia_00_prevuelo.sql > C:\PlanBot\respaldo\00_prevuelo.txt
# Tras P00 y P01-P05 con 01: sustituir ID_01 por el ID observado.
psql -h localhost -p 5433 -U owner_planbot -d planbot -X -v carga_id=ID_01 -f tests\e2e\evidencia_01_snapshot.sql > C:\PlanBot\respaldo\01_resultado.txt
pg_dump -h localhost -p 5433 -U owner_planbot -d planbot -Fc -f C:\PlanBot\respaldo\01_base.dump
# Después de 02/P01-P05 sobre 01:
psql -h localhost -p 5433 -U owner_planbot -d planbot -X -v carga_id=ID_02 -f tests\e2e\evidencia_02_cambios.sql > C:\PlanBot\respaldo\02_resultado.txt
# RESTAURAR 01 con Andrés, en base de demo acordada y con robot pausado.
# Después entregar 03 y completar su flujo, con el robot reanudado:
psql -h localhost -p 5433 -U owner_planbot -d planbot -X -v carga_id=ID_03 -f tests\e2e\evidencia_03_errores.sql > C:\PlanBot\respaldo\03_resultado.txt
psql -h localhost -p 5433 -U owner_planbot -d planbot -X -f tests\e2e\evidencia_04_plan_excel.sql > C:\PlanBot\respaldo\04_plan_excel.txt
```

Sustituir host/puerto/base y los tres ID; 5433 es un ejemplo, no el puerto supuesto de la VM. Comprobar `$LASTEXITCODE` tras cada comando: cero indica que SQL ejecutó; **no significa** que todos los resultados sean correctos. Guardar stderr además si hay fallos.

Antes de 01/02/03 guardar `Get-FileHash data\buk\01_original.xlsx -Algorithm SHA256` (cambiar archivo), hora, SHA de back/front y release BP; capturas de Control Room, ítem/cola y dashboard con `?modo=api`, más red HTTP sin tokens. Para 02, ambas consultas de faltantes/sobrantes y cambios anteriores al corte deben devolver cero filas; revisar también que cambie lo posterior. CSV de traslado usa IT destino: confirmar interpretación con Andrés. Para 03 son cinco combinaciones persona/campo; revisar semántica de motivos, admitir varios mensajes por fila y errores originales adicionales. Conciliar con_error contra DISTINCT fila, no count de mensajes. Si el catálogo indica funciones faltantes, no marcar P03/P04/P05 como aprobados por una consulta exitosa.

En una base nueva con solo migraciones, las ocho vistas deben estar vacías. Si hay parámetros/errores/cambios sembrados, esas vistas reflejan sus tablas aun con calc.plan_mes vacío; las cuatro de planificación sí permanecen vacías. Los CSV de evidencia no restauran una base: conservar y ensayar el dump por separado.
