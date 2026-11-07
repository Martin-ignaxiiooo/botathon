# Contratos entre módulos

Los módulos se comunican solo por estos 3 contratos. Cambiarlos exige un PR con la etiqueta `contrato` aprobado por César y Andrés.

## Contrato 1 · Tablas `stg.*` (Blue Prism escribe, la base lee)

| Tabla | Columnas | La llena |
|---|---|---|
| `stg.carga` | carga_id bigserial pk, tipo ('buk','planificacion','parametros','asignaciones'), archivo, hash unique, recibido_en timestamptz default now(), estado, leidas int, validas int, con_error int | P01, P00, P07, P10 |
| `stg.buk_fila` | carga_id, it int, instituto, persona_id bigint, area, sub_area, centro_costo, periodo date, tipo_contrato, tipo_trabajador, fecha_ingreso date, fecha_termino date null, horas_semanales numeric, cargo, dias_jornada, ndias int, cod_esp | P02 |
| `stg.error_fila` | carga_id, fila int, persona_id bigint, campo, valor, motivo | P02 |
| `stg.param_cargo` | carga_id, cod_esp, cargo, unidad, min_directa int, min_indirecta int, tramo smallint (1: >=40 h, 2: 22–40 h, 3: <22 h), pct_dir, pct_ind, pct_nas | P00 / CSV |
| `stg.param_asignacion` | carga_id, tipo, horas_semana numeric, requiere_dmn boolean, descripcion | P00 / CSV |
| `stg.param_calendario` | carga_id, mes smallint, zona, dias int, inhabiles int, dias_habiles int, semanas numeric | P00 / CSV |
| `stg.param_grupal` | carga_id, cod_esp, grupo_it ('San-Con','otros'), pct_grupal, pacientes_grupo | P00 / CSV |
| `stg.excepcion` | carga_id, persona_id, it, mes, horas | P00 / CSV |
| `stg.asignacion` | carga_id, persona_id, it, tipo, horas, desde date, hasta date, solicitante, motivo, estado | P10 |
| `stg.esperado` | carga_id, persona_id, it, campo, mes smallint null, valor numeric | CSV (`data\csv\esperado.csv`) |

Los CSV de `data\csv` tienen exactamente estas columnas sin `carga_id`.

Campos de `esperado.csv`: `pct_dir_final`, `pct_ind_final`, `ate_dir_semana`, `ate_ind_semana`, `ate_semana_total`, `horas_semana_dic`, `prom_pond_horas` (sin mes) y por mes 1–12: `semhab`, `plan_ate_dir`, `plan_ate_dir_ind`, `meta`, `meta_dir_ind`.

## Contrato 2 · Funciones SQL (Blue Prism llama, la base implementa)

| Función | Entrada | Devuelve | La llama |
|---|---|---|---|
| `cargar_parametros(carga_id bigint)` | carga planificacion o parametros | int (versión creada) | P00, P09 |
| `cargar_dotacion(carga_id bigint)` | carga validada | table(filas int, alertas int) | P02 |
| `detectar_cambios(carga_id bigint)` | carga cargada | table(tipo, persona_id, it, mes_vigencia, antes jsonb, despues jsonb) | P03 |
| `mes_minimo_afectado(carga_id bigint)` | carga con cambios | int | P03 |
| `recalcular(desde_mes int)` | mes 1–12 | table(filas int, ms int) | P04, P09, P10 |
| `simular(escenario_id bigint)` | escenario borrador | diferencia por it y área | P08 |
| `aplicar_escenario(escenario_id bigint)` | escenario aprobado | int (versión) | P09 |
| `cuadratura()` | stg.esperado lleno | numeric (% coincidencia) | P06 |

Antes de cambios auditables: `SELECT set_config('planbot.motivo', '<motivo>', false)`.

## Contrato 3 · Vistas `api.*` (la base publica, el dashboard lee por PostgREST)

| Vista | Una fila por | Columnas |
|---|---|---|
| `v_kpi` | total nacional | atenciones_plan, meta, foja, horas_contratadas, dotacion, ultima_carga |
| `v_nacional_mes` | mes | mes, atenciones_dir, atenciones_ind, meta, horas_dir, horas_ind, horas_nas, foja |
| `v_instituto_area_mes` | instituto × área × cargo × mes | it, instituto, area, cargo, mes, atenciones_dir, meta, foja, dotacion, horas_contratadas, horas_dir, horas_ind, horas_nas |
| `v_profesional_mes` | persona × instituto × mes | persona_id, it, cargo, area, mes, horas_contratadas, pct_dir_final, atenciones_dir, atenciones_dir_ind, meta, foja |
| `v_cambios` | cambio detectado | carga_id, tipo, persona_id, it, mes_vigencia, antes, despues, detectado_en |
| `v_errores_carga` | error de fila | carga_id, archivo, fila, persona_id, campo, motivo |
| `v_parametros_vigentes` | regla vigente | tabla, clave, valor, version, vigente_desde |
| `v_cuadratura` | persona × campo × mes | persona_id, campo, mes, excel, sistema, diferencia, causa |

Cambio v1.1 (6-nov 23:35): se agregan horas_contratadas, horas_dir, horas_ind y horas_nas a v_instituto_area_mes para el gráfico de horas por área de la pantalla Nacional.

Convenciones: minúsculas con guion bajo, meses 1–12, porcentajes decimales (0.65), horas decimales, `persona_id` como único identificador de persona.
