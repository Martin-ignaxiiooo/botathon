# E2E de contingencia por psql

Blue Prism es el camino principal. El script no usa su Runtime, ODBC ni Work Queue y no mueve archivos. Requiere Windows/.NET Framework 4, PostgreSQL 16 binarios, Python + openpyxl. No solicita entrada interactiva.

```powershell
# Base de demo con reglas/esperado ya migrados. Pausar cargas BP y acordar ventana.
.\tools\vm\simular_robot.ps1 -Archivo .\data\buk\02_cambios.xlsx -Servidor localhost -Puerto 5432 -Base planbot -EnvArchivo .\.env
# Ensayo independiente: no usa esa base; crea cluster/puerto propios, 01→02 y restaura 01→03.
.\tests\e2e\e2e.ps1
```

- Conexión: Usuario=bot_carga; VariableClave=BOT_CARGA_PASSWORD, leída del entorno o -EnvArchivo. Catálogos aprobados: UsuarioCatalogos=owner_planbot y VariableClaveCatalogos=POSTGRES_PASSWORD, solo consulta READ ONLY. Alternativa sin credencial del propietario: -Catalogos archivo.json con `{ "institutos":[{"it":131}], "cargos":[{"cargo_origen":"KINESIOLOGO"}] }` completo y aprobado (el ejemplo de una fila no es el catálogo real). No se deriva el catálogo del BUK ni se amplían permisos.
- La conexión se indica explícitamente; -EnvArchivo importa solo las dos claves y restaura su estado al terminar. No pasa claves a argv. -PgBin permite localizar binarios; -Salida debe ser nueva/vacía. La ruta de evidencia predeterminada es una carpeta única de TEMP.
- Solo se lee Dotacion_2026. El lector excluye Fecha de Nacimiento, Tipo_Trab_161225 y Reg_SIC del XML temporal. Compila/llama los fuentes originales PlanBot_Limpieza, PlanBot_Validador y Preparar Carga; conserva tipos, blancos, cabecera repetida y fila original. Exporta CSV con NULL real y fechas ISO, y ejecuta COPY cliente en lotes de 500, cada lote con su transacción.
- Flujo: SHA/INSERT ON CONFLICT → limpieza/validación → errores y válidas → cargar_dotacion → detectar_cambios → mes_minimo_afectado → recalcular solo si no es NULL → cierre por filas distintas → cuadratura. Un hash repetido termina antes de cargar/recalcular; una carga parcial no se reintenta sola. Con cero válidas no reemplaza la foto core. Si la BD agrega errores, se detiene para conciliar.
- El e2e congela SQL/seed de HEAD en TEMP y comprueba el data_directory de su cluster antes de cargar. pg_dump posterior a 01 se restaura en una segunda base nueva del mismo cluster para 03. No hace DROP ni restaura sobre servicios existentes; detiene su instancia al terminar. Los tests SQL se ejecutan sobre 01 (su esperado original), no contra 02 modificada. En Linux se imprime OMITIDO por dependencia de .NET Framework, sin declarar un E2E aprobado.
- Muestra OK/FALLA por caso y genera ejecucion.json, resultados.json, diferencias_back.csv, errores CSV y resúmenes con hash del Excel y C# usados. Exit 1 conserva fallos reales; no hay modo que los convierta en verdes. La verificación por vigencia individual es más fuerte que el corte global de recalcular: los dos resultados se muestran separados para revisar el efecto del promedio por período/tramo anual con Andrés/Teletón. No modificar fórmulas por alcanzar el esperado.
- No guardar la evidencia con claves o datos adicionales. El script deja artefactos mínimos persona_id/contrato/errores para trazabilidad, nunca RUT/nombres. Borrar solo la carpeta propia cuando el equipo ya tenga el respaldo; no limpiar manualmente stg de una carga con lotes confirmados.
