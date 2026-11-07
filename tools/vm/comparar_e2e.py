"""Comparación independiente de eventos, errores y meses previos; nunca corrige SQL."""
import argparse
from collections import Counter
import csv
from decimal import Decimal
import json
from pathlib import Path


def leer_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'), parse_float=Decimal)


def comparar(carpeta, esperados):
    resultados = []
    diferencias = []
    def caso(nombre, ok, detalle):
        resultados.append(dict(caso=nombre, estado='OK' if ok else 'FALLA', detalle=detalle))
    def diferencia(persona, mes, campo, esperado, obtenido, caso_nombre):
        diferencias.append(dict(caso=caso_nombre, persona_id=persona, mes=mes, campo=campo,
                                esperado=esperado, obtenido=obtenido))

    with (esperados / 'esperado_cambios.csv').open(encoding='utf-8-sig', newline='') as f:
        eventos = list(csv.DictReader(f))
    clave = lambda r: (r['tipo'], int(r['persona_id']), int(r['it']), int(r['mes_vigencia']))
    e, o = Counter(map(clave, eventos)), Counter(map(clave, leer_json(carpeta / 'cambios.json')))
    for etiqueta, delta in [('faltante', e-o), ('sobrante', o-e)]:
        for (tipo, persona, it, mes), cantidad in delta.items():
            diferencia(persona, mes, 'evento:'+tipo, 'presente' if etiqueta=='faltante' else 'ausente',
                        f'{etiqueta}; it={it}; cantidad={cantidad}', '02_cambios')
    caso('02_eventos', e==o, f'{sum(o.values())} eventos obtenidos; {sum(e.values())} esperados')
    cortes = {int(r['persona_id']): int(r['mes_vigencia']) for r in eventos}
    antes = {(int(r['persona_id']), int(r['it']), int(r['mes'])): r['fila'] for r in leer_json(carpeta/'antes.json')}
    despues = {(int(r['persona_id']), int(r['it']), int(r['mes'])): r['fila'] for r in leer_json(carpeta/'despues.json')}
    # Impactos anuales confirmados: no son excepciones de cálculo. Se exige
    # coincidencia exacta antes/después, no una exclusión por persona o por mes.
    with (Path(__file__).resolve().parents[2]/'tests/e2e/esperado_impacto_anual.csv').open(encoding='utf-8-sig', newline='') as f:
        anual = {(int(r['persona_id']),int(r['it']),int(r['mes']),r['campo']):
                 (Decimal(r['antes']),Decimal(r['despues'])) for r in csv.DictReader(f)}
    anual_visto = set()
    nprevias = 0
    corte_global=int(leer_json(carpeta/'02/resumen.json')['mes_minimo'])
    anteriores_global=0
    for k in sorted(antes.keys() | despues.keys()):
        persona, it, mes = k
        if persona in cortes and mes >= cortes[persona]:
            continue
        a, b = antes.get(k), despues.get(k)
        if a == b:
            continue
        if mes < corte_global:
            anteriores_global += 1
        fila_inesperada = False
        campos = (a or {}).keys() | (b or {}).keys()
        for campo in sorted(campos):
            va, vb = (a or {}).get(campo), (b or {}).get(campo)
            if va != vb:
                clave_anual = (persona,it,mes,campo)
                if clave_anual in anual and (va,vb) == anual[clave_anual]:
                    anual_visto.add(clave_anual)
                else:
                    fila_inesperada = True
                    diferencia(persona, mes, f'{campo} (it {it})', va, vb, '02_invariancia')
        if fila_inesperada:
            nprevias += 1
    for persona,it,mes,campo in sorted(anual.keys()-anual_visto):
        diferencia(persona,mes,f'{campo} (it {it})',anual[(persona,it,mes,campo)],
                    (antes.get((persona,it,mes),{}).get(campo),despues.get((persona,it,mes),{}).get(campo)),
                    '02_impacto_anual')
    caso('02_impacto_anual',anual_visto==anual.keys(),f'{len(anual_visto)}/{len(anual)} cambios de campos coinciden con esperado anual confirmado')
    caso('02_meses_previos', nprevias==0, f'{nprevias} filas con cambios no previstos por vigencia o impacto anual; calculado_en excluido')
    caso('02_corte_global',anteriores_global==0,f'{anteriores_global} cambios antes de mes_minimo_afectado={corte_global}')

    with (esperados/'esperado_errores.csv').open(encoding='utf-8-sig', newline='') as f:
        ee = list(csv.DictReader(f))
    eo = leer_json(carpeta/'errores.json')
    ke = lambda r: (int(r['persona_id']), r['campo'])
    ce, co = Counter(map(ke, ee)), Counter(map(ke, eo))
    for etiqueta, delta in [('faltante', ce-co), ('sobrante', co-ce)]:
        for (persona, campo), cantidad in delta.items():
            diferencia(persona, '', campo, 'presente' if etiqueta=='faltante' else 'ausente',
                        f'{etiqueta}; cantidad={cantidad}', '03_errores')
    motivos = all(str(r.get('motivo') or '').strip() and r.get('fila') is not None for r in eo)
    caso('03_errores', ce==co and motivos, f'{sum(co.values())} errores con fila/motivo; {sum(ce.values())} esperados (persona/campo; texto no literal)')
    for nombre, archivo, esperado in [('01_conteos','01/resumen.json',(3123,3123,0)), ('03_conteos','03/resumen.json',(3124,3119,5))]:
        r=leer_json(carpeta/archivo)
        obtenido=tuple(int(r['conteos'][c]) for c in ('leidas','validas','con_error'))
        caso(nombre, obtenido==esperado, f'leidas/validas/filas con error: {obtenido}')
    duplicado=leer_json(carpeta/'duplicado/resumen.json')
    caso('archivo_repetido',duplicado['duplicado'] and duplicado['estado']=='archivo repetido','sin nueva carga ni recálculo')
    sin=leer_json(carpeta/'sin_cambios/resumen.json')
    caso('minimo_NULL',sin['mes_minimo'] is None and 'recalculo' not in sin and not sin['duplicado'],'otra huella con misma dotación: NULL no llama recalcular')
    reinicio={(int(r['persona_id']),int(r['it']),int(r['mes'])): r['fila']
              for r in leer_json(carpeta/'reinicio_01.json')}
    caso('reinicio_01',reinicio==antes,
         f'reiniciar_demo.ps1 recupera {len(reinicio)} filas; comparación exacta con 01 sin calculado_en')
    with (carpeta/'diferencias_back.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['caso','persona_id','mes','campo','esperado','obtenido'])
        w.writeheader(); w.writerows(diferencias)
    (carpeta/'resultados.json').write_text(json.dumps(resultados,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
    for r in resultados:
        print(f"{r['estado']}: {r['caso']}: {r['detalle']}")
    return all(r['estado']=='OK' for r in resultados)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('carpeta',type=Path); p.add_argument('esperados',type=Path)
    a=p.parse_args()
    raise SystemExit(0 if comparar(a.carpeta,a.esperados) else 1)
