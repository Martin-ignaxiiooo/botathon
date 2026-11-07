# D-07 · Ensayo de punta a punta

Ejecutar en la VM Windows con Blue Prism 7.5.1, PostgreSQL preparado y dashboard en modo API. Registrar hora, archivo, hash y carga_id de cada ensayo. **No marcar OK antes de observar el resultado.** Usar una base de demo restaurable; no mezclar cargas anteriores. Los casos BUK usan enero–julio: cargo desde marzo, alta desde abril, jornada 40 → 30 desde mayo, baja desde junio y traslado desde julio.

| Paso | Acción | Resultado esperado | Resultado real | OK |
|---|---|---|---|---|
| 1 | Dejar la planilla de reglas en `C:\PlanBot\entrada\planificacion`; ejecutar P00. | Carga registrada sin errores; `param.cargo_distribucion` tiene reglas y una versión vigente. | Pendiente | ☐ |
| 2 | Dejar `data\buk\01_original.xlsx` en `C:\PlanBot\entrada\buk`; ejecutar P01–P05 y abrir Nacional. | Archivo cargado, dotación y planificación visibles en Nacional; KPI coinciden con SQL. | Pendiente | ☐ |
| 3 | Antes de cargar, capturar `calc.plan_mes`; dejar `02_cambios.xlsx` y ejecutar P01–P05. | Exactamente los cinco cambios del CSV; meses previos de cada persona intactos y recálculo desde cada vigencia. | Pendiente | ☐ |
| 4 | Restaurar la base posterior al paso 2; dejar `03_errores.xlsx`. | Los cinco errores intencionales figuran en `api.v_errores_carga`, con persona, campo y motivo correspondientes; filas inválidas no pasan al cálculo. | Pendiente | ☐ |
| 5 | Volver a dejar el mismo archivo, con otro nombre si hace falta. | Blue Prism informa «archivo repetido» por SHA-256; no duplica carga ni filas ni recalcula. | Pendiente | ☐ |
| 6 | Restaurar base limpia del paso 2; crear escenario con meta 0.85, simular, revisar y aprobar. | La simulación no cambia el plan vigente. La aprobación crea versión y aplica meta 85 %; atenciones y horas se conservan si solo varió meta. | Pendiente | ☐ |

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

-- Paso 5: guardar los conteos antes y contrastar después del reintento.
SELECT count(*) AS cargas FROM stg.carga;
SELECT hash, count(*) FROM stg.carga GROUP BY hash HAVING count(*) > 1;
SELECT count(*) AS filas_buk FROM stg.buk_fila;
SELECT count(*) AS filas_plan FROM calc.plan_mes;

-- Paso 6: capturar plan antes de simular en una sesión nueva.
CREATE TEMP TABLE demo_plan_pre_simulacion AS TABLE calc.plan_mes;
-- Crear escenario mediante el flujo aprobado por Andrés; la estructura de
-- calc.escenario no está fijada en contratos, no inventar INSERT/UPDATE.
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
