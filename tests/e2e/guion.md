# D-07 · Ensayo de punta a punta

Ejecutar en la VM Windows con Blue Prism 7.5.1, PostgreSQL preparado y dashboard en modo API. Registrar hora, archivo, SHA-256, carga_id y commits/release de cada ensayo. **No marcar OK antes de observar el resultado.** Acordar primero con Lucas y Andrés una ventana y una base restaurable; pausar otras cargas durante capturas, recálculos o restauraciones. No ejecutar estos pasos sobre su trabajo activo sin coordinación. Los casos BUK usan enero–julio: cargo desde marzo, alta desde abril, jornada 40 → 30 desde mayo, baja desde junio y traslado desde julio.

## Estado comprobado · 7 de noviembre de 2026

Inspección iniciada en `codex/trabajo` / `a259e78`, árbol limpio, sin merge ni push. `git fetch origin` solo actualizó referencias. Estas referencias **son snapshots distintos**, no una versión integrada desplegada:

| Componente | Evidencia observada | Dependencia / responsable |
|---|---|---|
| Contrato v1.1 | `0fb3a930da5a58516dd9a6bb2b0af455c6351d1a:docs/contratos.md`; copia de columnas/firmas en contrato_v1_1.json. El contrato local es anterior. | César y Andrés: seleccionar v1.1 para el despliegue; no se editó el contrato. |
| Back `9f172cc625c9be8e69044ac17d70ba8f26894765` | Snapshot de origin/feat/B-05-semanal probado en PostgreSQL 16.15 **aislado**. Diez tablas stg coinciden; bot_carga puede insertar. Dos RPC api disponibles con firmas/retornos correctos: cargar_parametros(bigint) → integer; cargar_dotacion(bigint) → TABLE(filas integer, alertas integer). | Andrés: entregar resto del back y publicar versión integrada. |
| Cálculo y API | Hay calc.v_semanal y tabla calc.plan_mes, pero plan_mes queda vacío. Faltan detectar_cambios, mes_minimo_afectado, recalcular, simular, aplicar_escenario y cuadratura; no hay ninguna de las ocho vistas api del contrato. cargar_asignaciones es auxiliar adicional, no sustituye las RPC faltantes. | Andrés: B-06–B-09 y funciones opcionales de escenarios/cuadratura. |
| Dashboard `4b6b1c4f903088ba55b7ae831ead06b9f0608ea8` | origin/main: cliente y ocho fixtures compatibles con v1.1, incluidos horas_contratadas, horas_dir, horas_ind y horas_nas de v_instituto_area_mes. Nacional consume esas horas. Prueba Node del módulo real con fetch simulado; **no es una prueba del navegador/API**. | César: desplegar ese front o una revisión posterior validada. Esta rama aún tiene pantallas iniciales y mocks sin las cuatro horas. |
| Blue Prism | Lucas reporta robot listo. El repositorio contiene .cs de referencia, sin release exportado que permita comprobar versión importada, procesos o colas. | Lucas: Check Code, driver y ensayo del release real en Runtime Resource. |
| Entorno | Servicios PostgreSQL locales activos en 5432, sin consultar sus datos. Docker no disponible; HTTP 3000/8080 sin servicio; driver PostgreSQL ODBC 64 bits no encontrado en este PC. No hay URL/acceso a VM aportados. | César/Lucas: acceso y ventana; Andrés: PostgREST, permisos y base de ensayo. |

El ensayo aislado ejecutó migrar.ps1, test.ps1 -Modulo db, cargar_buk_prueba.ps1 con 01_original y nuevamente las pruebas SQL: todos terminaron en 0 (000_humo, 001_parametros y 002_dotacion). Conteos: **stg.buk_fila 3.123, core.dotacion_mes 5.338, calc.v_semanal 912, calc.plan_mes 0**. Las 2.215 filas adicionales son proyección del back, no meses añadidos al archivo BUK. La prueba de promedio informa 456/466 = 97,9 %; su salida verde no certifica el umbral semanal ni un E2E completo. El cargador de prueba usa Python/psql, **no Blue Prism ni ODBC**. Se detuvo la instancia propia al terminar; ningún servicio compartido se migró o cargó.

## Diferencias que deben resolverse antes del recorrido real

- **Contadores, demostrado en SQL:** insertar un error de BP en stg.error_fila y una fila válida en stg.buk_fila, y llamar cargar_dotacion, deja con_error=0 con un error presente. El back recalcula sus contadores desde las filas que recibe y omite los rechazos previos de BP. Andrés y Lucas deben acordar el cierre P05; medir filas originales con error, no cantidad de mensajes. Sonda aislada con ROLLBACK en tools/probar_back_aislado.ps1. No se modificó SQL ni contrato.
- **Tipos y llamadas BP:** usar esquema api. Para Number → bigint, probar Ejecutar Consulta con `SELECT * FROM api.cargar_dotacion(CAST(? AS bigint))` y cargaId posicional. La acción genérica Ejecutar Función no fuerza bigint; binding ODBC real pendiente. Convertir fechas ISO de validas a DateTime antes de Carga Masiva según el LEEME; no insertar columna fila en stg.buk_fila, conservarla solo para errores.
- **Auditoría:** set_config en una acción y la RPC en otra pueden usar conexiones distintas. Lucas debe mantener motivo y operación en la misma conexión; auditoría real pendiente de Andrés. No certificarla por reutilización accidental del pool.
- **Distribución:** el C# alerta cuando la suma difiere más de 0.001; SQL rechaza más de 0.000001. Una suma 1.0005 pasaría sin alerta en el primero y fallaría en el segundo. Requiere acuerdo de Andrés/Lucas; no se cambió la tolerancia.
- **Claves de parámetros:** Nacional en main busca meta_gestion, mes_cambio_jornada y jornada_legal_horas_desde_mayo. Seed del back publica meta, jornada_ene_abr y jornada_may_dic. César/Andrés deben acordar el mapeo: la tarjeta usa alternativa y el marcador de jornada puede faltar. No renombrar claves unilateralmente.
- **Pantalla Cambios:** deriva las cargas de v_cambios/v_errores_carga. Una carga sin cambios ni errores no aparece; archivo no está en v_cambios. Para comprobar 01, conservar ID/archivo desde SQL y Control Room. No añadir columnas al contrato para resolverlo aquí. Parámetros/simulación todavía es una pantalla inicial en main.

## Comprobaciones reproducibles sin alterar servicios compartidos

Desde la raíz, PowerShell 7. Requiere Python con las dependencias del proyecto, Node y binarios PostgreSQL 16. Los verificadores manuales están en tools para que test.ps1 -Modulo todo no arranque clusters ni consulte una VM automáticamente.

```powershell
# Congelar referencias antes del ensayo. No hace checkout/merge.
git rev-parse HEAD origin/main origin/feat/B-05-semanal
python -m unittest discover -s tools -p 'test_*.py'
node --experimental-vm-modules tests\e2e\probar_cliente.mjs 4b6b1c4f903088ba55b7ae831ead06b9f0608ea8
# Instancia propia, puerto libre loopback; se detiene al terminar.
pwsh -NoProfile -File tools\probar_back_aislado.ps1 -Referencia 9f172cc625c9be8e69044ac17d70ba8f26894765
# Con la ruta que imprime el ensayo:
python tools\comprobar_catalogo.py "$env:TEMP\PlanBot_Integracion_<id>\catalogo_bot.json"
```

El último comando devuelve **1** con B-05 por las seis RPC y ocho vistas ausentes; es un bloqueo esperado, no una aprobación. Informa tipos stg y retornos para revisión; no certifica conversiones ODBC ni semántica de negocio. El cliente Node pasa en el main indicado; con a259e78 falla por horas_contratadas ausente en los mocks. No sustituir esa falla por un dato inventado.

En la VM, solo después de recibir host/puerto/base y rol autorizados, ejecutar catálogo de **solo lectura** y guardar JSON (psql pide la clave, no escribirla en el comando):

```powershell
psql -h <host> -p <puerto> -U bot_carga -d <base_demo> -X -At -v ON_ERROR_STOP=1 -f tests\e2e\inspeccionar_contrato.sql > C:\PlanBot\respaldo\catalogo_bot.json
python tools\comprobar_catalogo.py C:\PlanBot\respaldo\catalogo_bot.json
# URL real de PostgREST, no la del dashboard. Solo GET, sin RPC ni cargas.
pwsh -NoProfile -File tools\probar_api_planbot.ps1 -ApiUrl http://<host>:3000 -Origen http://<host>:8080 -Salida C:\PlanBot\respaldo\api_integracion.json
```

Los marcadores entre < > deben reemplazarse antes de ejecutar. Si requiere JWT, usar PLANBOT_TEST_TOKEN en entorno sin guardarlo en logs. Se prueban las ocho vistas con select explícito y CORS: un array vacío solo valida la consulta, **no la existencia de datos**. Con 127.0.0.1:3000 aquí, ocho conexiones rechazadas (comprobado, pendiente de servicio). En el navegador abrir `http://<host>:8080/?modo=api#nacional`; DevTools/Red debe mostrar llamadas a PostgREST, ninguna lectura mock/*.json. config.js usa apiUrl localhost:3000 y compose permite origen localhost:8080; si el navegador está en otro PC, César/Andrés deben configurar URL alcanzable y origen exacto del despliegue antes de probar (localhost designa ese otro PC). Guardar captura, endpoint/estado, conteos y hora; un HAR debe revisarse para retirar tokens y datos antes de compartirlo. Cotejar KPI y las cuatro horas con SQL, filtrar IT/área/mes y comprobar Instituto y Profesional. Si falla API, debe mostrarse error, no datos mock.

## Ejecución coordinada en VM · todos los pasos siguen pendientes

| Paso | Acción | Resultado esperado | Evidencia que guardar | Resultado real | OK |
|---|---|---|---|---|---|
| 1 | Acordar base/ventana; dejar la planilla de reglas en C:\PlanBot\entrada\planificacion; ejecutar P00. | Carga registrada sin errores; param.cargo_distribucion con reglas/versiones. No continuar si faltan RPC/vistas del recorrido. | Hash de entrada, carga_id, versión param, sesión Control Room y conteo SQL. | Pendiente VM | ☐ |
| 2 | Copiar data\buk\01_original.xlsx a C:\PlanBot\entrada\buk; ejecutar P01–P05. Ver cola durante procesamiento y resultado; abrir Nacional con ?modo=api. Guardar snapshot posterior a 01. | Limpieza de encabezados/blancos; 3.123 filas BUK antes de validación. Dotación y plan visibles, KPI/horas iguales a SQL. Revisar errores reales, sin exigir cero por su nombre «original». | SHA, ID, leídas/válidas/filas con error, cola/sesión, conteos stg/core/calc, consultas y captura Red/SQL/pantalla; dump restaurable. | Pendiente BP/API; carga por psql aislada aprobada únicamente | ☐ |
| 3 | Desde snapshot 01, capturar calc.plan_mes y copiar 02_cambios.xlsx a entrada\buk; ejecutar P01–P05. | Exactamente cinco eventos CSV, sin meses previos alterados: cargo 71132/131 marzo; alta 999001/131 abril; jornada 71555/131 mayo 40→30; baja 71027/101 junio; traslado 71146 a IT 101 julio. | Hash/ID, cola, consultas EXCEPT ALL sin filas, planes antes/después y tiempos de recálculo; pantalla Cambios filtrada por carga y Profesional. | Pendiente funciones de cambios/recálculo | ☐ |
| 4 | Restaurar snapshot 01 con robot pausado; comprobar hash de 03 no procesado. Copiar 03_errores.xlsx a entrada\buk y ejecutar flujo de carga. No usar el estado posterior a 02. | Detectar cinco casos CSV: 71027 horas 0, 71132 fechas, 71146 cargo inexistente, 71232 duplicado, 71247 horas «cuarenta». Cada caso con fila/motivo semántico; inválidas fuera de stg.buk_fila/cálculo. Pueden existir errores adicionales del origen. | Hash/ID, resultados CSV↔SQL con faltantes cero, fila original, sesión/cola y pantalla Cambios/errores; cotejo de contadores. | Pendiente BP/API; no aprobado por pruebas de consola previas | ☐ |
| 5 | Reentregar exactamente los bytes del archivo anterior (puede cambiar nombre). | «archivo repetido» por hash; no aumenta carga/stg/plan ni se recalcula. | SHA igual, conteos antes/después, ítem/sesión de cola y mensaje del robot. | Pendiente VM | ☐ |
| 6 | Opcional, cuando B-12/C-09 existan: restaurar 01; crear escenario meta 0.85, simular, revisar y aprobar con usuario autorizado. | Simulación conserva plan vigente; aprobación aplica versión/meta, con motivo auditado; horas/atenciones intactas si solo varió meta. | ID escenario, aprobación humana, planes/versiones antes/después y audit.log. | Bloqueado: funciones y pantalla pendientes | ☐ |

## Consultas de verificación

Abrir psql desde la raíz del repositorio. Con Docker: `docker compose exec postgres psql -U owner_planbot -d planbot`. Para `\copy` el CSV debe estar en el equipo donde corre psql: usar psql local o copiar los CSV al contenedor y ajustar las rutas. Las variables `carga_cambios`, `carga_errores` y `escenario` se asignan con los IDs observados; no usar IDs supuestos.

```sql
-- Paso 1
SELECT count(*) FROM param.cargo_distribucion;
SELECT * FROM api.v_parametros_vigentes ORDER BY tabla, clave;
SELECT carga_id, tipo, archivo, estado, leidas, validas, con_error
FROM stg.carga ORDER BY carga_id DESC;

-- Paso 2
SELECT * FROM api.v_kpi;
SELECT * FROM api.v_nacional_mes ORDER BY mes;
-- Cuatro columnas obligatorias v1.1; cotejar también respuesta HTTP y gráfico.
SELECT it, area, cargo, mes, horas_contratadas, horas_dir, horas_ind, horas_nas
FROM api.v_instituto_area_mes ORDER BY it, area, cargo, mes;
SELECT count(*) FROM calc.plan_mes;
SELECT * FROM api.v_errores_carga ORDER BY carga_id DESC, fila;

-- Paso 3: ejecutar ANTES de entregar 02_cambios; mantener abierta esta sesión.
CREATE TEMP TABLE demo_plan_antes AS TABLE calc.plan_mes;
CREATE TEMP TABLE demo_cambios_esperados (
  tipo text, persona_id bigint, it int, mes_vigencia int
);
\copy demo_cambios_esperados FROM 'data/buk/esperado_cambios.csv' CSV HEADER

-- DESPUÉS de P01–P05: consultar cargas y asignar el ID real.
SELECT carga_id, archivo, estado FROM stg.carga ORDER BY carga_id DESC;
\prompt 'carga_id de 02_cambios: ' carga_cambios
SELECT tipo, persona_id, it, mes_vigencia, antes, despues
FROM api.v_cambios WHERE carga_id = :carga_cambios
ORDER BY persona_id, mes_vigencia;

-- Debe devolver CERO filas (incluye duplicados mediante EXCEPT ALL).
WITH reales AS (
  SELECT tipo, persona_id, it, mes_vigencia
  FROM api.v_cambios WHERE carga_id = :carga_cambios
)
SELECT 'faltante' AS diferencia, f.* FROM (
  SELECT * FROM demo_cambios_esperados EXCEPT ALL SELECT * FROM reales
) f
UNION ALL
SELECT 'sobrante', s.* FROM (
  SELECT * FROM reales EXCEPT ALL SELECT * FROM demo_cambios_esperados
) s;

-- Debe devolver CERO filas: cambios en filas antes del corte individual,
-- o en personas ajenas a los casos. Compara todas las columnas.
WITH limites AS (
  SELECT persona_id, min(mes_vigencia) AS desde
  FROM demo_cambios_esperados GROUP BY persona_id
), diferencias AS (
  SELECT coalesce(a.persona_id,b.persona_id) AS persona_id,
         coalesce(a.mes,b.mes) AS mes, to_jsonb(a) AS antes, to_jsonb(b) AS despues
  FROM demo_plan_antes a FULL JOIN calc.plan_mes b USING (persona_id,it,mes)
  WHERE to_jsonb(a) IS DISTINCT FROM to_jsonb(b)
)
SELECT d.* FROM diferencias d LEFT JOIN limites l USING (persona_id)
WHERE l.desde IS NULL OR d.mes < l.desde;

-- Revisar también cada mes posterior al corte; ausencia de diferencias
-- anteriores no demuestra por sí sola que se recalculó lo posterior.
SELECT p.* FROM calc.plan_mes p JOIN demo_cambios_esperados e USING (persona_id)
WHERE p.mes >= e.mes_vigencia ORDER BY p.persona_id, p.it, p.mes;
SELECT * FROM audit.log;

-- Paso 4 (en la base restaurada del paso 2)
CREATE TEMP TABLE demo_errores_esperados(persona_id bigint, campo text, motivo text);
\copy demo_errores_esperados FROM 'data/buk/esperado_errores.csv' CSV HEADER
\prompt 'carga_id de 03_errores: ' carga_errores
SELECT fila, persona_id, campo, motivo FROM api.v_errores_carga
WHERE carga_id = :carga_errores ORDER BY fila;
SELECT e.*, r.fila, r.motivo AS motivo_real
FROM demo_errores_esperados e LEFT JOIN api.v_errores_carga r
  ON r.carga_id = :carga_errores AND r.persona_id = e.persona_id AND r.campo = e.campo;
-- Ningún esperado debe carecer de fila; revisar semántica del motivo.
-- Los contratos no fijan textos literales: alinear CSV y validación con Lucas.
SELECT c.carga_id, c.leidas, c.validas, c.con_error,
       (SELECT count(DISTINCT e.fila) FROM stg.error_fila e
        WHERE e.carga_id=c.carga_id) AS filas_con_error_registradas
FROM stg.carga c WHERE c.carga_id=:carga_errores;
-- Guardar discrepancias: en B-04 este contador omite rechazos previos de BP.

-- Paso 5: guardar los conteos antes y contrastar después del reintento.
SELECT count(*) AS cargas FROM stg.carga;
SELECT hash, count(*) FROM stg.carga GROUP BY hash HAVING count(*) > 1;
SELECT count(*) AS filas_buk FROM stg.buk_fila;
SELECT count(*) AS filas_plan FROM calc.plan_mes;

-- Paso 6: capturar plan antes de simular en una sesión nueva.
CREATE TEMP TABLE demo_plan_pre_simulacion AS TABLE calc.plan_mes;
-- Crear escenario mediante el flujo aprobado por Andrés; la estructura de
-- calc.escenario no está fijada en contratos, no inventar INSERT/UPDATE.
-- Paso opcional BLOQUEADO hasta que ambas funciones existan. No ejecutarlo ahora.
-- Usar esquema real de las funciones: localizarlo primero.
SELECT n.nspname AS esquema, p.proname, pg_get_function_identity_arguments(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('simular','aplicar_escenario');
-- Configurar search_path con el esquema encontrado antes de estas llamadas.
\prompt 'ID del escenario borrador con meta 0.85: ' escenario
SELECT * FROM simular(:escenario);
-- CERO filas: el plan vigente debe permanecer idéntico tras simular.
(TABLE demo_plan_pre_simulacion EXCEPT ALL TABLE calc.plan_mes)
UNION ALL
(TABLE calc.plan_mes EXCEPT ALL TABLE demo_plan_pre_simulacion);
-- Solo después de la aprobación humana del escenario:
SELECT set_config('planbot.motivo', 'Demo: aprobar escenario meta 85 %', false);
SELECT aplicar_escenario(:escenario);
SELECT * FROM api.v_parametros_vigentes ORDER BY tabla, clave;
SELECT * FROM api.v_nacional_mes ORDER BY mes;
```

Para cambios de IT el CSV usa el IT **destino**. Confirmar esa convención con Andrés, pues el contrato fija la columna pero no su sentido en un traslado. En la baja no deben quedar meses desde junio; en el alta deben aparecer abril–julio. Un cambio de cargo puede modificar varias magnitudes; comparar contra reglas vigentes, no solo un total nacional. Si el motor actualiza metadatos de todas las filas durante el recálculo, documentar esa diferencia antes de aceptar el chequeo de invariancia.

## Respaldo previo a la demo

- [ ] Generar dump de la base en formato custom, verificar salida y probar restauración en una base aparte: `pg_dump -h localhost -U owner_planbot -d planbot -Fc -f C:\PlanBot\respaldo\planbot_pre_demo.dump`. Pedir clave por prompt; no incluirla en el comando. Roles/credenciales se configuran por separado al restaurar.
- [ ] Exportar release de Blue Prism con procesos, objetos, colas y definiciones necesarias; guardar versión y probar importación. Credenciales deben configurarse en destino.
- [ ] Copiar los archivos de entrada y CSV esperados; comprobar conexión ODBC, SQL y API, y estado de las colas.
- [ ] Grabar un video de cinco minutos mostrando Blue Prism, carga original, cambios y dashboard como respaldo.
- [ ] Reservar copia limpia de la VM/base y anotar cómo restaurarla; no borrar el historial sin respaldo.
- [ ] Desactivar logging de claves y disponer de los responsables de back, front y robot durante el ensayo.
