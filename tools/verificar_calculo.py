r"""Verificador offline. python tools\verificar_calculo.py [--plan archivo.csv]

No consulta SQL ni usa esperado.csv como entrada del cálculo independiente.
Genera escenario estricto (meses BUK) y escenario continuidad explícito.
Constantes reconstruidas en param_general_verificacion.csv; no son un seed SQL.
"""
import argparse
import calendar
import hashlib
import json
import math
import unicodedata
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
KEY = ['persona_id', 'it', 'campo', 'mes']
MONTHS = range(5, 13)
FIELDS = ['pct_dir_final', 'ate_dir_semana', 'plan_ate_dir']


def normalizar(texto):
    return ''.join(c for c in unicodedata.normalize('NFKD', str(texto)).upper()
                   if not unicodedata.combining(c)).strip()


def abajo(x):
    return math.floor(x + 1e-9)


def semanal(horas, promedio, regla, params, dias_jornada=None, colacion=False, asignaciones=0):
    """Solo reglas explícitas; sin asignaciones individuales no disponibles."""
    comida = params['colacion_h_dia'] * dias_jornada if colacion and pd.notna(dias_jornada) else 0
    disponibles = horas - comida
    nas = regla['pct_nas'] * promedio + asignaciones
    suma = regla['pct_dir'] + regla['pct_ind']
    if disponibles <= 0 or regla['min_directa'] <= 0 or suma <= 0:
        return math.nan, math.nan, nas, disponibles
    pct = regla['pct_dir'] * (1 - nas / disponibles) / suma
    if not 0 <= pct <= 1:
        return math.nan, math.nan, nas, disponibles
    return pct, abajo(disponibles * pct * params['minutos_hora'] / regla['min_directa']), nas, disponibles


def unicos(df, claves, nombre):
    if df.duplicated(claves).any():
        raise ValueError(f'{nombre}: claves duplicadas; no se promedian ni se escoge una fila arbitraria')


def leer_buk(path):
    # Solo nueve columnas necesarias. De nacimiento se conserva solo el mes
    # para el medio día de cumpleaños; nunca se exporta la fecha completa.
    # L se selecciona por posición para soportar cabeceras con acentos dañados.
    df = pd.read_excel(path, sheet_name='Dotacion_2026', header=1,
                       usecols='A,C,G:H,L:N,R:S', engine='openpyxl')
    df.columns = ['it', 'persona_id', 'nacimiento', 'periodo', 'termino', 'horas', 'cargo', 'cod_esp', 'ndias']
    df['fila'] = df.index + 3
    df['persona_id'] = pd.to_numeric(df['persona_id'], errors='coerce')
    desc = len(df) - int(df['persona_id'].notna().sum())
    df = df[df['persona_id'].notna()].copy()
    df['mes_cumple'] = pd.to_datetime(df.pop('nacimiento'), errors='coerce').dt.month
    for c in ['persona_id', 'it']:
        nums = pd.to_numeric(df[c], errors='raise')
        if (nums % 1 != 0).any():
            raise ValueError(f'BUK: {c} no entero')
        df[c] = nums.astype('int64')
    df['periodo'] = pd.to_datetime(df['periodo'], errors='raise')
    df['termino'] = pd.to_datetime(df['termino'].replace('', None), errors='raise')
    df['horas'] = pd.to_numeric(df['horas'], errors='raise')
    df['ndias'] = pd.to_numeric(df['ndias'], errors='coerce')
    if (df['horas'] <= 0).any() or not df['horas'].map(math.isfinite).all():
        raise ValueError('BUK: jornada no positiva o no finita')
    df['mes'] = df['periodo'].dt.month
    df['anio'] = df['periodo'].dt.year
    if df['anio'].nunique() != 1:
        raise ValueError('Se necesita un solo año BUK')
    unicos(df, ['persona_id', 'it', 'mes'], 'BUK')
    return df, desc


def parametros(carpeta, generales):
    g = pd.read_csv(generales)
    unicos(g, ['clave'], 'param.general reconstruido')
    params = dict(zip(g['clave'], pd.to_numeric(g['valor'], errors='raise')))
    cargo = pd.read_csv(carpeta / 'param_cargo.csv').fillna({'cod_esp': ''})
    cargo['clave_cargo'] = cargo['cargo'].map(normalizar)
    # Repeticiones idénticas no son reglas diferentes; conflictos se rechazan.
    cargo = cargo.drop_duplicates()
    unicos(cargo, ['clave_cargo', 'tramo'], 'param_cargo')
    reglas = {(r['clave_cargo'], int(r['tramo'])): r for r in cargo.to_dict('records')}
    cal = pd.read_csv(carpeta / 'param_calendario.csv')
    unicos(cal, ['zona', 'mes'], 'param_calendario')
    cal = cal[cal['zona'] == 'general'].set_index('mes')
    for m in MONTHS:
        if m not in cal.index:
            raise ValueError(f'Falta calendario general mes {m}')
    grupal = pd.read_csv(carpeta / 'param_grupal.csv')
    unicos(grupal, ['cod_esp', 'grupo_it'], 'param_grupal')
    asig = pd.read_csv(carpeta / 'param_asignacion.csv', usecols=['tipo', 'horas_semana'])
    # Tabla de tipos, no de asignación persona/tipo: no sumar a todos los profesionales.
    return params, reglas, cal, grupal, len(asig)


def factor_grupal(cod_esp, it, grupal, params):
    grupo = 'San-Con' if it in [params['it_santiago'], params['it_concepcion']] else 'otros'
    filas = grupal[(grupal['cod_esp'] == cod_esp) & (grupal['grupo_it'] == grupo)]
    if filas.empty:
        return 1.0
    r = filas.iloc[0]
    return float(1 - r['pct_grupal'] + r['pct_grupal'] * r['pacientes_grupo'])


def calcular(buk, params, reglas, cal, grupal, colacion=False, grupal_hipotesis=False):
    calculos = []
    codigos_grupales = set(grupal['cod_esp'])
    ultimo_mes_fuente = int(buk['mes'].max())
    for modelo in ['estricto', 'continuidad']:
        for (persona, it), bloque in buk.groupby(['persona_id', 'it'], sort=True):
            registros = {int(r['mes']): r for r in bloque.to_dict('records')}
            ultimo = registros[max(registros)]
            anio = int(ultimo['anio'])
            if modelo == 'continuidad' and max(registros) == ultimo_mes_fuente:
                for mes in range(ultimo_mes_fuente + 1, 13):
                    fin = ultimo['termino']
                    inicio_mes = pd.Timestamp(anio, mes, 1)
                    # Sin inventar nuevas altas ni prolongar un término conocido.
                    if pd.notna(fin) and fin < inicio_mes:
                        continue
                    registros[mes] = {**ultimo, 'mes': mes, 'periodo': inicio_mes, 'proyectado': True}
            # Ponderación por días de calendario de los meses representados.
            peso = sum(calendar.monthrange(anio, m)[1] for m in registros)
            promedio = sum(r['horas'] * calendar.monthrange(anio, m)[1] for m, r in registros.items()) / peso
            tramo = 1 if promedio >= params['tramo_limite_alto'] else 2 if promedio >= params['tramo_limite_bajo'] else 3
            for mes in MONTHS:
                r = registros.get(mes)
                base = dict(modelo=modelo, persona_id=persona, it=it, mes=mes,
                            promedio_horas=promedio, tramo=tramo, pct_dir_final=math.nan,
                            ate_dir_semana=math.nan, plan_ate_dir=math.nan, semhab=math.nan,
                            cargo='', origen='sin_contrato', hipotesis='Sin mes BUK; no se presume baja ni jornada cero')
                if r is None:
                    calculos.append(base)
                    continue
                cargo = normalizar(r['cargo'])
                regla = reglas.get((cargo, tramo))
                causas = ['Asignaciones individuales no disponibles', 'Promedio anual parcial' if modelo == 'estricto' else 'Continuidad hipotética después de julio']
                factor = factor_grupal(r['cod_esp'], it, grupal, params)
                base.update(cargo=r['cargo'], origen='proyectado' if r.get('proyectado') else 'observado', factor_grupal_hipotesis=factor)
                if regla is None:
                    base['hipotesis'] = 'Cargo sin homologación exacta; no se infiere por cod_esp'
                    calculos.append(base)
                    continue
                if str(r['cod_esp']) in codigos_grupales or str(regla['cod_esp']) in codigos_grupales:
                    causas.append('Atención grupal: fórmula pendiente en reglas.md; base individual')
                if str(r['cod_esp']) != str(regla['cod_esp']):
                    causas.append('cod_esp BUK difiere del cargo parametrizado')
                if bloque['horas'].nunique() > 1:
                    causas.append('Jornada cambiante / ponderación anual incompleta')
                if it in [params['it_arica'], params['it_aysen']]:
                    causas.append('Calendario zonal no exportado; se usa general')
                pct, semana, nas, disponibles = semanal(r['horas'], promedio, regla, params, r['ndias'], colacion)
                pausa = r['horas'] * (params['pausa_pct_alta'] if r['horas'] >= params['tramo_limite_alto'] else params['pausa_pct_baja'])
                semanas = round((float(cal.loc[mes, 'dias']) - float(cal.loc[mes, 'inhabiles'])) / params['dias_semana'], 1)
                # Días adicionales/licencias/vacaciones/permisos sin fuente: 0.
                descuento = params['descuento_septiembre_dias'] if mes == 9 else params['descuento_diciembre_dias'] if mes == 12 else 0
                if mes >= params['mes_inicio_segundo_semestre'] and r.get('mes_cumple') == mes:
                    descuento += params['cumple_dias']
                semhab = max(0, semanas - descuento * params['dia_en_semanas'])
                causas.append('Sin licencias/vacaciones/permisos/días adicionales individuales')
                if mes >= params['mes_inicio_segundo_semestre']:
                    causas.append('Julio–diciembre: descuentos individuales faltantes')
                if pd.isna(pct):
                    causas.append('Distribución no calculable: denominador/minutos inválidos o NAS fuera de rango')
                base.update(pct_dir_final=pct, ate_dir_semana=semana,
                            plan_ate_dir=abajo(semana * semhab * (factor if grupal_hipotesis else 1)) if pd.notna(semana) else math.nan,
                            semhab=semhab, horas=r['horas'], horas_nas=nas, horas_disponibles=disponibles,
                            pausa_horas=pausa, hipotesis='; '.join(causas))
                calculos.append(base)
    return pd.DataFrame(calculos)


def leer_esperado(path):
    e = pd.read_csv(path)
    e['mes'] = pd.to_numeric(e['mes'], errors='raise').fillna(0).astype(int)
    e['valor'] = pd.to_numeric(e['valor'], errors='raise')
    e = e[e['campo'].isin(FIELDS + ['semhab']) & ((e['mes'] == 0) | e['mes'].isin(MONTHS))].copy()
    counts = e.groupby(KEY, dropna=False)['valor'].nunique(dropna=False)
    conflictivas = counts[counts > 1].reset_index()[KEY]
    duplicadas = int(e.duplicated(KEY).sum())
    e = e.merge(conflictivas.assign(conflicto=True), on=KEY, how='left')
    e['conflicto'] = e['conflicto'].fillna(False).astype(bool)
    # Conflicto no es un valor numérico comparable: conservar clave y señalarlo.
    e.loc[e['conflicto'], 'valor'] = math.nan
    e = e.drop_duplicates(KEY)
    return e, duplicadas, len(conflictivas)


def comparar(izquierda, derecha, etiqueta):
    """Join exterior: ni filas ausentes ni conflictos desaparecen del denominador."""
    unicos(izquierda, KEY, etiqueta + ' referencia')
    unicos(derecha, KEY, etiqueta + ' candidato')
    c = izquierda.merge(derecha, on=KEY, how='outer', suffixes=('_ref', '_calc'), indicator=True)
    c['comparacion'] = etiqueta
    c['diferencia'] = c['calculado'] - c['referencia']
    c['abs_diferencia'] = c['diferencia'].abs()
    c['comparable'] = c['referencia'].notna() & c['calculado'].notna()
    tol = c['campo'].map(lambda f: 1e-9 if f == 'pct_dir_final' else 0)
    c['coincide'] = c['comparable'] & (c['abs_diferencia'] <= tol)
    if 'hipotesis' not in c:
        c['hipotesis'] = ''
    c['hipotesis'] = c['hipotesis'].fillna('Clave ausente en el cálculo/catálogo; revisar cobertura')
    conflicto = c.get('conflicto', pd.Series(False, index=c.index)).fillna(False)
    c.loc[conflicto, 'hipotesis'] = 'Esperado tiene varios valores para la misma persona/IT/campo/mes; clave ambigua'
    return c


def resumir(comparaciones):
    filas = []
    for (nombre, campo), g in comparaciones.groupby(['comparacion', 'campo'], sort=True):
        referencia = g['_merge'] != 'right_only'
        n = int(referencia.sum())
        comp = int((g['comparable'] & referencia).sum())
        ok = int((g['coincide'] & referencia).sum())
        filas.append(dict(comparacion=nombre, campo=campo, esperados=n, comparables=comp,
                          coinciden=ok, sin_comparar=n-comp,
                          pct_coincidencia_comparables=100*ok/comp if comp else math.nan,
                          pct_coincidencia_total=100*ok/n if n else math.nan,
                          extras_candidato=int((~referencia).sum())))
    return pd.DataFrame(filas)


def propios_largos(calculos, modelo):
    c = calculos[calculos['modelo'] == modelo]
    # El Excel contiene un único valor semanal/% final may-dic, no uno por mes.
    # Se toma el último mes disponible; diciembre solo si se pudo proyectar.
    ultimo = c[c['origen'] != 'sin_contrato'].sort_values('mes').groupby(['persona_id', 'it']).tail(1)
    simples = ultimo.melt(id_vars=['persona_id', 'it', 'hipotesis'], value_vars=FIELDS[:2], var_name='campo', value_name='calculado')
    simples['mes'] = 0
    mensuales = c[KEY[:2] + ['mes', 'hipotesis', 'plan_ate_dir']].rename(columns={'plan_ate_dir': 'calculado'})
    mensuales['campo'] = 'plan_ate_dir'
    return pd.concat([simples, mensuales], ignore_index=True)


def leer_plan(path):
    """CSV ancho de calc.plan_mes o formato largo explícito campo/valor."""
    d = pd.read_csv(path)
    for key in ['persona_id', 'it', 'mes']:
        if key not in d:
            raise ValueError(f'--plan: falta {key}')
        d[key] = pd.to_numeric(d[key], errors='raise')
        if d[key].isna().any() or (d[key] % 1 != 0).any():
            raise ValueError(f'--plan: {key} debe ser entero sin NULL')
        d[key] = d[key].astype('int64')
    if not d['mes'].between(1, 12).all():
        raise ValueError('--plan: mes debe estar entre 1 y 12')
    d = d[d['mes'].isin(MONTHS)].copy()
    if {'campo', 'valor'} <= set(d):
        d = d[d['campo'].isin(FIELDS)].rename(columns={'valor': 'calculado'})
    else:
        if 'plan_ate_dir' not in d and 'atenciones_dir' in d:
            d = d.rename(columns={'atenciones_dir': 'plan_ate_dir'})
        columnas = [f for f in FIELDS if f in d]
        if not columnas:
            raise ValueError('--plan: ninguna columna reconocida; usar --columna-plan para plan mensual o formato largo')
        unicos(d, ['persona_id', 'it', 'mes'], '--plan')
        d = d.melt(id_vars=['persona_id', 'it', 'mes'], value_vars=columnas, var_name='campo', value_name='calculado')
    d['calculado'] = pd.to_numeric(d['calculado'], errors='raise')
    unicos(d, KEY, '--plan')
    return d[KEY + ['calculado']]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--buk', type=Path, default=ROOT / 'data/excel/Nac - Base contratos x mes.xlsx')
    parser.add_argument('--csv', type=Path, default=ROOT / 'data/csv')
    parser.add_argument('--param-generales', type=Path, default=Path(__file__).with_name('param_general_verificacion.csv'))
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--columna-plan', help='Nombre real del plan directo en CSV ancho; se renombra a plan_ate_dir')
    parser.add_argument('--colacion', action='store_true', help='Sensibilidad: aplicar 0.25 h × Ndias; base predeterminada sin colación')
    parser.add_argument('--grupal-hipotesis', action='store_true', help='Sensibilidad, NO regla confirmada: factor mensual 1-pct_grupal+pct_grupal*pacientes_grupo por cod_esp BUK')
    parser.add_argument('--salida', type=Path, default=Path(__file__).parent / 'resultados')
    args = parser.parse_args(argv)
    buk, descartadas = leer_buk(args.buk)
    p, reglas, cal, grupos, n_asig = parametros(args.csv, args.param_generales)
    # Cálculo independiente ANTES de abrir el esperado. No hay SQL ni ajustes por objetivo.
    calc = calcular(buk, p, reglas, cal, grupos, args.colacion, args.grupal_hipotesis)
    e, duplicadas, conflictos = leer_esperado(args.csv / 'esperado.csv')
    ref = e[e['campo'].isin(FIELDS)].rename(columns={'valor': 'referencia'})
    comparaciones = [comparar(ref, propios_largos(calc, m), m + '_vs_excel') for m in ['estricto', 'continuidad']]
    # Identidad del Excel para aislar la fórmula final: NO es cálculo independiente.
    ew = e[e['campo'] == 'ate_dir_semana'][['persona_id', 'it', 'valor']].rename(columns={'valor': 'semana_excel'})
    es = e[e['campo'] == 'semhab'][['persona_id', 'it', 'mes', 'valor']].rename(columns={'valor': 'semhab_excel'})
    diagnostico = es.merge(ew, on=['persona_id', 'it'], how='left', validate='many_to_one')
    diagnostico['calculado'] = (diagnostico['semana_excel'] * diagnostico['semhab_excel']).map(lambda x: abajo(x) if pd.notna(x) else math.nan)
    diagnostico['campo'] = 'plan_ate_dir'
    diagnostico['hipotesis'] = 'Identidad usando semana y semhab del Excel; no valida entradas ni independencia'
    comparaciones.append(comparar(ref[ref['campo'] == 'plan_ate_dir'], diagnostico[KEY + ['calculado', 'hipotesis']], 'identidad_excel_no_independiente'))
    ultimo_buk = buk.sort_values('mes').groupby(['persona_id', 'it']).tail(1).copy()
    ultimo_buk['factor'] = ultimo_buk.apply(lambda r: factor_grupal(r['cod_esp'], r['it'], grupos, p), axis=1)
    dg = diagnostico.drop(columns=['calculado', 'hipotesis']).merge(ultimo_buk[['persona_id', 'it', 'factor']], on=['persona_id', 'it'], how='left', validate='many_to_one')
    dg['calculado'] = (dg['semana_excel'] * dg['semhab_excel'] * dg['factor']).map(lambda x: abajo(x) if pd.notna(x) else math.nan)
    dg['hipotesis'] = 'Diagnóstico NO independiente: semana/semhab Excel y factor grupal hipotético por cod_esp BUK'
    comparaciones.append(comparar(ref[ref['campo'] == 'plan_ate_dir'], dg[KEY + ['calculado', 'hipotesis']], 'identidad_excel_grupal_hipotesis'))
    if args.plan:
        # No se cambia el CSV recibido ni se asume el nombre físico del esquema SQL.
        planpath = args.plan
        if args.columna_plan:
            ancho = pd.read_csv(planpath)
            if args.columna_plan not in ancho or ('plan_ate_dir' in ancho and args.columna_plan != 'plan_ate_dir'):
                raise ValueError('--columna-plan inexistente o colisión con plan_ate_dir')
            ancho = ancho.rename(columns={args.columna_plan: 'plan_ate_dir'})
            from io import StringIO
            planpath = StringIO(ancho.to_csv(index=False))
        db = leer_plan(planpath)
        # Expandir los valores escalares Excel a cada mes exportado de la base.
        scalar = ref[ref['mes'] == 0].drop(columns='mes').merge(pd.DataFrame({'mes': list(MONTHS)}), how='cross')
        mensual_ref = pd.concat([ref[ref['mes'] != 0], scalar], ignore_index=True)
        presentes = set(db['campo'])
        comparaciones.append(comparar(mensual_ref[mensual_ref['campo'].isin(presentes)], db, 'base_vs_excel'))
        for modelo in ['estricto', 'continuidad']:
            propio = calc[calc['modelo'] == modelo].melt(id_vars=['persona_id', 'it', 'mes', 'hipotesis'], value_vars=sorted(presentes), var_name='campo', value_name='referencia')
            comparaciones.append(comparar(propio, db, 'base_vs_' + modelo))
    todas = pd.concat(comparaciones, ignore_index=True)
    resumen = resumir(todas)
    diferencias = todas[todas['comparable'] & ~todas['coincide']].sort_values(['abs_diferencia', 'persona_id', 'it', 'mes'], ascending=[False, True, True, True])
    top = diferencias.groupby(['comparacion', 'campo'], sort=False).head(20)
    args.salida.mkdir(parents=True, exist_ok=True)
    for name, table in [('calculo', calc), ('resumen', resumen), ('comparaciones', todas), ('top20_por_campo', top)]:
        table.to_csv(args.salida / (name + '.csv'), index=False, encoding='utf-8')
    fuentes = [args.buk, args.param_generales, *sorted(args.csv.glob('param_*.csv')), args.csv / 'esperado.csv']
    if args.plan:
        fuentes.append(args.plan)
    info = dict(filas_buk=len(buk), descartadas_buk=descartadas,
                pares_buk=int(buk[['persona_id', 'it']].drop_duplicates().shape[0]),
                meses_buk=sorted(int(x) for x in buk['mes'].unique()),
                duplicadas_esperado=duplicadas, claves_conflictivas_esperado=conflictos,
                tipos_asignacion=n_asig, colacion=args.colacion, grupal_hipotesis=args.grupal_hipotesis,
                sin_regla=sorted(calc.loc[calc['hipotesis'].str.startswith('Cargo sin'), 'cargo'].unique().tolist()),
                campos_plan_presentes=sorted(presentes) if args.plan else [],
                campos_plan_no_exportados=sorted(set(FIELDS) - presentes) if args.plan else FIELDS,
                pandas=pd.__version__, fuentes_sha256={str(f.relative_to(ROOT) if f.is_relative_to(ROOT) else f): hashlib.sha256(f.read_bytes()).hexdigest() for f in fuentes})
    (args.salida / 'ejecucion.json').write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(info, ensure_ascii=False, indent=2))
    print(resumen.to_string(index=False, float_format=lambda x: f'{x:.3f}'))
    print('\n20 mayores diferencias por campo/comparación:')
    print(top[['comparacion', 'campo', 'persona_id', 'it', 'mes', 'referencia', 'calculado', 'diferencia', 'hipotesis']].to_string(index=False))
    print('\nResultados en', args.salida)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, FileNotFoundError) as error:
        raise SystemExit('Error de verificación: ' + str(error)) from error
