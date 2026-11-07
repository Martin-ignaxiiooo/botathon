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
import zipfile
import xml.etree.ElementTree as ET
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


def leer_asistencial(path):
    """Lee solo columnas del diagnóstico y solo el cuerpo de Dot_Asistencial."""
    from openpyxl import load_workbook
    from openpyxl.utils.cell import range_boundaries
    with zipfile.ZipFile(path) as z:
        tablas = [ET.fromstring(z.read(n)) for n in z.namelist()
                  if n.startswith('xl/tables/') and n.endswith('.xml')]
    tablas = [t for t in tablas if t.get('name') == 'Dot_Asistencial']
    if len(tablas) != 1:
        raise ValueError('No se encontró una única tabla Dot_Asistencial')
    tabla = tablas[0]
    _, cabecera, _, fin = range_boundaries(tabla.get('ref'))
    if cabecera != 4:
        raise ValueError('La cabecera de Dot_Asistencial debe estar en fila 4')
    fin -= int(tabla.get('totalsRowCount', '0'))
    wb = load_workbook(path, read_only=True, data_only=True)
    try:
        headers = {normalizar(' '.join(str(c.value).split())): c.column - 1
                   for c in next(wb['Dotacion_Asistencial'].iter_rows(min_row=4, max_row=4)) if c.value is not None}
    finally:
        wb.close()
    campos = {
        'persona_id': 'PersonaId', 'it': 'IT', 'cargo': 'Cargo', 'area': 'Area',
        'horas_semana_dic': 'H/S dic', 'prom_pond_horas': 'Prom_Pond Horas Semanales',
        'dias_semana': 'N° Días Semana Contrato', 'colacion_contrato': 'Horas Colación en Contrato',
        'horas_nas_total': 'H/Sem NAS Total', 'horas_asignacion': 'Total Hrs. Asignación',
        'asignacion_1': 'Asignación 1 (seleccionar de lista desplegable)', 'horas_asig_1': 'Hrs. Asignación 1',
        'asignacion_2': 'Asignación 2 (seleccionar de lista desplegable)', 'horas_asig_2': 'Hrs. Asignación 2',
        'pct_dir_base': '%Directo', 'pct_ind_base': '%Indirecto', 'pct_nas_base': '% NAS',
        'min_directa': 'Estándar Minutos Atención Directa', 'min_indirecta': 'Estándar Minutos Atención Indirecta',
        'disponible_antes_nas': 'H/Sem Disponible antes NAS dic', 'pct_nas_asignaciones': '%NAS + Asig. Especiales',
        'pct_dir_final': '%Directo Final', 'pct_ind_final': '%Indirecto Final',
        'ate_dir_semana': 'N° Ate Directas (minutos estándar) - Semana may - dic',
        'ate_ind_semana': 'N° Ate Indirectas (30 min) - Semana may - dic',
        'pct_grupal': '% Atención Grupal Estándar', 'cambio_grupal': 'Cambio %Ate. Grupal V°B° DMN y VP',
        'pacientes_grupo': 'N° Pacientes por Grupo', 'ate_dir_grupal': 'Atención Semanal Directa + Grupal',
    }
    for m in range(1, 13):
        campos[f'semhab_{m}'] = f'SemHab{m}'
    for m in MONTHS:
        campos[f'plan_{m}'] = f'PlanAteDir{m}'
        campos[f'meta_{m}'] = f'MG_AteDir{m}'
    indices = {c: headers[normalizar(h)] for c, h in campos.items()}
    orden = sorted(indices.values())
    df = pd.read_excel(path, sheet_name='Dotacion_Asistencial', header=3,
                       nrows=fin - cabecera, usecols=orden, engine='openpyxl')
    inversa = {i: c for c, i in indices.items()}
    df.columns = [inversa[i] for i in orden]
    df['fila_excel'] = df.index + cabecera + 1
    for c in ['persona_id', 'it']:
        df[c] = pd.to_numeric(df[c], errors='coerce')
    df = df[df['persona_id'].notna() & df['it'].notna()].copy()
    df[['persona_id', 'it']] = df[['persona_id', 'it']].astype('int64')
    for c in set(campos) - {'persona_id', 'it', 'cargo', 'area', 'asignacion_1', 'asignacion_2'}:
        df[c] = pd.to_numeric(df[c], errors='raise')
    return df


def capas_asistencial(df, params, reglas):
    """Diagnóstico por fila física: las dos claves repetidas no se mezclan."""
    resultados = []
    def registrar(capa, campo, referencia, calculado, mes=0, mascara=None, hipotesis=''):
        for i, r in df.iterrows():
            if mascara is not None and not mascara.loc[i]:
                continue
            ref, calc = referencia.loc[i], calculado.loc[i]
            comparable = pd.notna(ref) and pd.notna(calc) and math.isfinite(ref) and math.isfinite(calc)
            tol = 0 if campo in {'ate_dir_semana', 'ate_ind_semana', 'plan_ate_dir', 'meta'} else 1e-9
            resultados.append(dict(capa=capa, campo=campo, fila_excel=r['fila_excel'], persona_id=r['persona_id'], it=r['it'], mes=mes,
                                   referencia=ref, calculado=calc, comparable=comparable,
                                   coincide=comparable and abs(calc - ref) <= tol,
                                   diferencia=calc-ref if comparable else math.nan, hipotesis=hipotesis))
    def fl(s):
        return s.map(lambda n: abajo(n) if pd.notna(n) and math.isfinite(n) else math.nan)
    for contextual in [False, True]:
        for base in ['prom_pond_horas', 'horas_semana_dic']:
            seleccion = []
            for _, r in df.iterrows():
                valor = r[base]
                tramo = 1 if valor >= params['tramo_limite_alto'] else 2 if valor >= params['tramo_limite_bajo'] else 3
                cargo = normalizar(r['cargo'])
                candidato = normalizar(str(r['cargo']) + ' ' + str(r['area']))
                # Variante declarada; no ajusta por valores objetivo ni por persona.
                if contextual and (candidato, tramo) in reglas:
                    cargo = candidato
                seleccion.append(reglas.get((cargo, tramo), {}))
            for destino, param in [('pct_dir_base', 'pct_dir'), ('pct_ind_base', 'pct_ind'), ('pct_nas_base', 'pct_nas')]:
                pred = pd.Series([r.get(param, math.nan) for r in seleccion], index=df.index)
                registrar(('a_cargo_area_tramo_' if contextual else 'a_tramo_') + base, destino, df[destino], pred,
                          hipotesis='Cargo+área es homologación candidata cuando existe en param_cargo; revisar excepción residual')
    disponibles = df['horas_semana_dic'] - df['colacion_contrato']
    registrar('b_insumos', 'disponible_antes_nas', df['disponible_antes_nas'], disponibles)
    nas = (df['horas_nas_total'] + df['horas_asignacion']) / disponibles.where(disponibles > 0)
    registrar('b_nas_reconstruido', 'pct_nas_asignaciones', df['pct_nas_asignaciones'], nas,
              hipotesis='Jornada cambiante: revisar denominador/ponderación; no sustituir por H/S dic sin evidencia')
    suma = df['pct_dir_base'] + df['pct_ind_base']
    predicciones = {}
    for modo, pct_nas in [('pct_nas_excel', df['pct_nas_asignaciones']), ('nas_reconstruido', nas)]:
        pred_dir = df['pct_dir_base'] * (1-pct_nas) / suma.where(suma != 0)
        pred_ind = df['pct_ind_base'] * (1-pct_nas) / suma.where(suma != 0)
        registrar('b_' + modo, 'pct_dir_final', df['pct_dir_final'], pred_dir)
        registrar('b_' + modo, 'pct_ind_final', df['pct_ind_final'], pred_ind)
        directas = fl(df['disponible_antes_nas'] * pred_dir * params['minutos_hora'] / df['min_directa'].where(df['min_directa'] > 0))
        indirectas = fl(df['disponible_antes_nas'] * pred_ind * params['minutos_hora'] / df['min_indirecta'].where(df['min_indirecta'] > 0))
        for sufijo, mascara in [('_todas', None), ('_activas', df['horas_semana_dic'] > 0)]:
            registrar('b_' + modo + sufijo, 'ate_dir_semana', df['ate_dir_semana'], directas, mascara=mascara,
                      hipotesis='H/S dic=0 puede conservar semanal histórico; en activas revisar jornada/estándar aplicado')
            registrar('b_' + modo + sufijo, 'ate_ind_semana', df['ate_ind_semana'], indirectas, mascara=mascara)
        predicciones[modo] = directas
    pct_grupal = df['cambio_grupal'].fillna(df['pct_grupal']).fillna(0)
    factor = 1-pct_grupal+pct_grupal*df['pacientes_grupo'].fillna(1)
    registrar('c_grupal_desde_semanal_excel', 'ate_dir_grupal', df['ate_dir_grupal'], df['ate_dir_semana']*factor,
              hipotesis='Revisar override individual de grupo/pacientes y reglas de redondeo')
    variantes = {'c_aislada_semanal_grupal_excel': df['ate_dir_grupal'],
                 'c_encadenada_pct_nas_excel': predicciones['pct_nas_excel']*factor,
                 'c_encadenada_nas_reconstruido': predicciones['nas_reconstruido']*factor}
    for capa, semana in variantes.items():
        for m in MONTHS:
            plan = fl(semana * df[f'semhab_{m}'])
            registrar(capa, 'plan_ate_dir', df[f'plan_{m}'], plan, m,
                      hipotesis='Aislada verifica fórmula mensual; encadenada propaga diferencias semanales/grupales')
            registrar(capa, 'meta', df[f'meta_{m}'], fl(plan * params['meta']), m,
                      hipotesis='Frontera de floor/epsilon o diferencia propagada del plan')
    detalle = pd.DataFrame(resultados)
    resumen = detalle.groupby(['capa', 'campo'], sort=True).agg(referencias=('fila_excel', 'size'), comparables=('comparable', 'sum'), coinciden=('coincide', 'sum')).reset_index()
    resumen['sin_comparar'] = resumen['referencias'] - resumen['comparables']
    resumen['pct_comparables'] = 100*resumen['coinciden']/resumen['comparables'].replace(0, math.nan)
    resumen['pct_total'] = 100*resumen['coinciden']/resumen['referencias']
    return resumen, detalle


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
    parser.add_argument('--capas', action='store_true', help='Además, diagnosticar capas A/B/C contra Dot_Asistencial por fila Excel')
    parser.add_argument('--planificacion', type=Path, default=ROOT / 'data/excel/Nac - Planificacion Asistencial x mes.xlsx')
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
    if args.capas:
        asistencial = leer_asistencial(args.planificacion)
        resumen_capas, detalle_capas = capas_asistencial(asistencial, p, reglas)
        resumen_capas.to_csv(args.salida / 'capas_resumen.csv', index=False)
        detalle_capas.to_csv(args.salida / 'capas_detalle.csv', index=False)
        errores_capas = detalle_capas[detalle_capas['comparable'] & ~detalle_capas['coincide']].copy()
        errores_capas['abs_diferencia'] = errores_capas['diferencia'].abs()
        errores_capas.sort_values('abs_diferencia', ascending=False).groupby(['capa', 'campo']).head(20).to_csv(args.salida / 'capas_top20.csv', index=False)
        asistencial[asistencial.duplicated(['persona_id', 'it'], keep=False)].to_csv(args.salida / 'capas_claves_repetidas.csv', index=False)
        print('\nCAPAS A/B/C (diagnóstico condicionado a insumos Excel; no es BUK independiente):\n' + resumen_capas.to_string(index=False))
    fuentes = [args.buk, args.param_generales, *sorted(args.csv.glob('param_*.csv')), args.csv / 'esperado.csv']
    if args.plan:
        fuentes.append(args.plan)
    if args.capas:
        fuentes.append(args.planificacion)
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
