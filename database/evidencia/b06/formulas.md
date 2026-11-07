# B-06 · Fórmulas completas del plan mensual, meta y FOJA

> **Estado (7-nov):** B-06 se implementó en versión SIMPLIFICADA (`database\functions\040_calcular_plan.sql`).
> - **Semanas hábiles:** se usa `semhab` de `stg.esperado`; si la persona no tiene valor, las semanas del calendario.
> - **Atenciones, meta y horas/FOJA:** las fórmulas de §2 y §3 sí están implementadas.
> - **Aún no implementado:**
>   - el cálculo de semanas hábiles desde ausencias y beneficios (§1);
>   - la V006 completa de §5. La V006 real solo crea `calc.plan_mes_traza`.
>
> Ambos quedan como **mejora**, con la evidencia de abajo.

Fuente: hoja `Dotacion_Asistencial` del Excel de planificación (solo valores; no tiene fórmulas en las filas de datos).
Cada regla indica su **estado**:
- **comprobada:** el Excel la reproduce y la cifra está abajo.
- **inferida:** calza con los datos, pero no está escrita en ninguna parte.
- **pendiente:** no hay evidencia.

Las evidencias se reproducen con `scripts\evidencia_b06.ps1`; los resultados quedan en `resumen.md`.

Notación: persona-IT `p`, mes `m` (1-12) y periodo `per(m)`: `ene_abr` si m ≤ 4, `may_dic` si m ≥ 5.
Solo se calcula `p,m` si existe fila en `core.dotacion_mes` (real o proyectada). Los meses sin contrato no generan fila.

## 1 · Semanas hábiles `SH(p,m)` [semanas/mes]

### 1.1 Datos de entrada y unidades

| Símbolo | Dato | Unidad | Columna Excel (origen) | Tabla destino (V006) |
|---|---|---|---|---|
| `S(m,z)` | semanas del mes en la zona `z` del instituto | semanas | hoja calendario → `param.calendario_mes.semanas` | (ya existe) |
| `L(m)`, `V(m)`, `P(m)` | licencias, vacaciones, permisos del mes | **semanas** | `Lic1..12`, `Vac1..12`, `Perm1..12` | `core.ausencia_mes` |
| `FZ(m)` | feriado legal zona extrema (solo ene, feb) | días | `Feriado legal zona extrema ene'26/feb'26` | `core.ausencia_mes` |
| `C`, `mC` | días de cumpleaños y su mes | días, mes | `Días de cumpleaños`, `Mes cumpleaños` | `core.beneficio_persona` (no se guarda la fecha de nacimiento) |
| `VFP` | víspera de Fiestas Patrias | días | `Visperas Fiestas Patrias` | `core.beneficio_persona` (mes 9) |
| `VNA` | vísperas de Navidad y Año Nuevo | días | `Visperas Navidad y Año Nuevo` | `core.beneficio_persona` (mes 12) |
| `DA` | días adicionales: suma de 11 columnas | días | ver 1.3 | `core.beneficio_persona` (una fila por columna) |
| `d` | un día en semanas | semanas/día | — | `param.general.dia_en_semanas` = 0,2 |
| `SH_ref(m)` | semanas hábiles del Excel | semanas | `SemHab1..12` | `core.semanas_habiles_ref` (referencia trazable) |

Las unidades de `L`, `V` y `P` se comprueban con el ejemplo 137732: `Vac2 = 3` y `SemHab2 = 4,0 − 3 = 1`. Otro caso, `Perm3 = 0,25`, da `SemHab3 = 4,4 − 0,25 = 4,15`.

### 1.2 Fórmula

```
X(m)  = S(m,z) − L(m) − V(m) − P(m)
        − d × ( FZ(m) + [m = mC]·C + [m = 9]·VFP + [m = 12]·VNA )
        − [7 ≤ m ≤ 12] · PR
PR    = d × DA / M2            si M2 > 0;  0 si M2 = 0          [semanas/mes]
M2    = meses con contrato entre julio y diciembre
SH(m) = max(0, techo1(X(m)))    si m ∈ {5, 7}
SH(m) = max(0, X(m))            en los demás meses
techo1(x) = ceil(10·x − 1e-9) / 10   (hacia arriba, a 1 decimal)
```

### 1.3 Componentes y evidencia

Base: las 471 filas del Excel, contando solo meses con `SemHab > 0`.

| Componente | Estado | Evidencia |
|---|---|---|
| `S − L − V − P` en ene, feb, mar, abr, jun | comprobada | 450/450, 409/409, 447/447, 451/451, 443/443 |
| Cumpleaños: `C` días en el mes `mC` | comprobada para quienes están en el Excel | Valores por persona: 1 (256 filas), 0,5 (40), 0 (175). Se usa el valor de cada persona; **no** se asume 0,5 |
| Víspera de Fiestas Patrias en septiembre, Navidad y Año Nuevo en diciembre | inferida (mes) / comprobada (valor por persona) | Sep 448/448 y dic 447/447 con esos meses. Valores: VFP 0,5 (439) o 0 (32); VNA 1 (439) o 0 (32) |
| Prorrata `PR = d × DA / M2` | comprobada | 445/448 filas con `M2 > 0` reproducen `Semanas/mes a prorratear 2do semestre` |
| La prorrata se aplica de julio a diciembre | inferida | Ago-dic 100 %. Julio también calza al restar `PR` completo y redondear hacia arriba |
| **Julio:** `techo1` | inferida | Sin redondeo: 31/446. Truncando la prorrata a 1 decimal: 317/446. Con `techo1` del total: **446/446**. No hay fórmula que lo explique; se pregunta al dueño del Excel |
| **Mayo:** `techo1` | inferida | Sin redondeo: 280/450; con `techo1`: **450/450**. Los fallos sin redondeo son permisos fraccionarios (p. ej. `Perm5` = 0,1786) |
| `techo1` en los otros meses | descartada | Los rompe: ago 36/448 |
| Feriado de zona extrema | pendiente | Las 471 filas tienen 0 en ene y feb de 2026; no hay evidencia del valor para Arica (11) ni Aysén (111) |
| Calendario por zona | pendiente | `param.calendario_mes` solo tiene la zona `general`. Si una zona no tiene fila, se usa `general` y queda indicado en `fuente_calendario` |
| `M2` calculado como meses con contrato jul-dic | inferida | Se compara con la columna `Meses 2do semestre` del Excel en `resumen.md` |
| `Ajuste por diferencia en días contrato` | no se usa | Solo 3 filas tienen valor y las 12 `SemHab` calzan sin él |

Días adicionales (`DA`), una fila por columna, con su nombre de origen: `Feriado legal adicional`, `Días administrativos y 1/2 jornada familiar`, `Plan anual capacitación por cargo`, `HEXA - CTR`, `Jornada nacional`, `Días Progresivos`, `Días Complementario`, `Ley 21530`, `Vacaciones Legales Pendientes Periodos Anteriores`, `Jornadas Directiva Sindical` y `Lactancia (Equiv_días/año)`.

### 1.4 Qué semanas usa el plan (`fuente_semanas`)

| Caso | `fuente_semanas` | SH usada |
|---|---|---|
| Hay `SH_ref(p,m)` (persona-IT en el Excel) | `excel` | `SH_ref`, como referencia trazable (versión inicial de B-06) |
| No hay referencia, pero sí ausencias y beneficios registrados de `p` | `calculada` | `SH(m)` de 1.2 |
| No hay datos de `p`: altas nuevas, cambio de IT o persona fuera del Excel | `pendiente` | **NULL**: atenciones, meta, horas dir/ind/nas y FOJA quedan NULL. No se usa 0 ni el calendario completo |

`calc.calcular_plan(desde_mes, fuente)` acepta `fuente = 'calculada'` para medir el cálculo completo. Nada se completa con valores por defecto: no hay 0,5 de cumpleaños ni vísperas para las altas.

## 2 · Atenciones y meta del mes

| Fórmula | Estado | Evidencia (may-dic, 3.752 persona-mes, entradas del Excel) |
|---|---|---|
| `ate_dir(m) = floor(Wdg(per) × SH(m) + 1e-9)`, con `Wdg` = atenciones semanales directa + grupal | comprobada | 3750/3752 |
| `ate_dir_ind(m) = floor((Wdg(per) + Wi(per)) × SH(m) + 1e-9)`, con `Wi` = indirectas por semana | comprobada | 3750/3752 |
| `meta(m) = floor(ate_dir(m) × param meta + 1e-9)` | comprobada | 3747/3752 |
| Ene-abr con `Wdg` y `Wi` del periodo `ene_abr` | **pendiente** | El Excel no guarda el semanal de ene-abr. Con el de may-dic, ene-abr calza en 1217/1876 (65 %). Se calcula con las horas de ene-abr y queda como limitación |

`Wdg`, `Wi`, `pct_dir_final`, `pct_ind_final` y `pct_nas_asig` vienen de `calc.v_semanal` para el periodo `per(m)`, igual que en B-05.

## 3 · Horas del mes y FOJA (unidades)

| Símbolo | Definición | Unidad |
|---|---|---|
| `h(m)` | `core.dotacion_mes.horas_semanales` del mes | h/semana |
| `col` | colación en contrato (`core.condicion_persona.colacion_h`) | h/semana |
| `D(m)` | `h(m) − col`: horas disponibles del mes | h/semana |

```
horas_contratadas(m) = h(m) × S(m,z)                       [h/sem × sem/mes = h/mes]
horas_dir(m)         = D(m) × pct_dir_final × SH(m)         [h/sem × 1 × sem/mes = h/mes]
horas_ind(m)         = D(m) × pct_ind_final × SH(m)         [h/mes]
horas_nas(m)         = D(m) × pct_nas_asig  × SH(m)         [h/mes]
foja(m)              = horas_dir(m) / horas_contratadas(m)  [h/mes ÷ h/mes = adimensional]
```

- **FOJA** sigue la definición acordada: horas directas disponibles en el mes dividido por horas contratadas en el mes. Cada término multiplica por semanas una sola vez:
  - `horas_contratadas` usa las semanas del calendario, `S`.
  - `horas_dir` usa las semanas hábiles, `SH`.
  - Los porcentajes no llevan semanas.
- **`horas_nas`** es NAS + asignaciones (pausa, colación de 15 min, otras NAS y asignaciones), como en la regla "% NAS con asignaciones":
  - Con horas constantes, `D × pct_nas_asig = horas NAS + horas de asignaciones` por semana, con horas NAS = `%NAS × promedio`.
  - No es un resto: se calcula con su propio porcentaje.
- **Identidad que se prueba:**
  - Como `pct_dir_final + pct_ind_final + pct_nas_asig = 1`, se cumple `horas_dir + horas_ind + horas_nas = D(m) × SH(m)`.
  - La diferencia con lo contratado, `col × S + D × (S − SH)`, es colación y ausencias. **No se asigna a ninguna de las tres horas.**
- **Limitación:** si la jornada cambia dentro del periodo, los porcentajes salen del promedio del periodo (B-05) y `D(m)` es la jornada del mes.

## 4 · Recálculo desde un mes

- `calc.calcular_plan(desde_mes)` borra y vuelve a escribir solo `calc.plan_mes` con `mes >= desde_mes`; los meses anteriores no se tocan (B-08 la envuelve en `api.recalcular`).
- Si un cambio en un mes posterior mueve el promedio anual y con él el tramo, los meses anteriores **no** se recalculan. La diferencia queda visible comparando con un recálculo desde 1.

## 5 · Propuesta V006 y compatibilidad

```sql
core.ausencia_mes (persona_id bigint, it int, mes smallint 1-12,
    concepto text CHECK IN ('licencia','vacaciones','permiso','feriado_zona_extrema'),
    cantidad numeric NOT NULL CHECK >= 0, unidad text CHECK IN ('semanas','dias'),
    columna_origen text NOT NULL, fuente text NOT NULL DEFAULT 'excel_planificacion', carga_id bigint,
    actualizado_en timestamptz, PK (persona_id, it, mes, concepto))
core.beneficio_persona (persona_id, it, concepto text, grupo CHECK IN ('dias_adicionales','cumpleanos','visperas'),
    mes smallint NULL 1-12, cantidad numeric NOT NULL CHECK >= 0, unidad CHECK IN ('dias'),
    columna_origen, fuente, carga_id, actualizado_en, PK (persona_id, it, concepto))
core.semanas_habiles_ref (persona_id, it, mes, semanas numeric NOT NULL CHECK >= 0, columna_origen, fuente,
    carga_id, actualizado_en, PK (persona_id, it, mes))
```

- **Registro de valores:** se guardan todos los valores de cada persona del Excel, **también los 0**. Así, "0" significa que el Excel dice 0 y "sin fila" significa pendiente.
- **Origen de los datos:** vienen del Excel de planificación, no del BUK.
  - Los extrae `scripts\extraer_condiciones.py` a `database\seed\csv\{ausencias,beneficios,semanas_habiles_ref}.csv`.
  - Los carga el seed 050, con su propia `stg.carga` de tipo `asignaciones` y hash `seed:ausencias:excel-v2`.
- **Compatibilidad con el esquema actual:**
  - Solo agrega tablas en `core`. No cambia `stg.*`, firmas de `api.*` ni vistas `api.*` (contrato v1.1 intacto).
  - No cambia `calc.plan_mes` ni `calc.plan_mes_escenario`; la fuente de las semanas se ve en `calc.v_semanas_habiles`.
  - `core.condicion_persona` se mantiene. Sus columnas `feriado_adicional_dias`, `capacitacion_dias` y `vacaciones_pendientes_dias` (V005) repiten 3 de los 11 días adicionales; B-06 usa `core.beneficio_persona`.
  - Si una persona-IT aparece dos veces en el Excel (72190/41, 137356/22), se toma la misma fila que en B-05: la de más horas en diciembre.
- **Parámetros nuevos** en `param.general` (versión vigente; `cargar_parametros` los hereda):
  - `prorrata_mes_desde` = 7 y `prorrata_mes_hasta` = 12;
  - `semhab_redondeo_mes_5` = 1 y `semhab_redondeo_mes_7` = 1 (1 = `techo1`), inferidos;
  - `semhab_decimales` = 1.
  - Los meses de las vísperas (9 y 12) se guardan en la fila de cada beneficio.
