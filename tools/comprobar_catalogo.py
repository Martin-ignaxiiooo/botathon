r"""Compara el JSON de inspeccionar_contrato.sql con el contrato v1.1 congelado.

Uso: python tools\comprobar_catalogo.py catalogo_bot.json
No conecta a la BD. Salida 1 = contrato incompleto/diferente, no error ocultado.
"""
import argparse
import json
import re
from pathlib import Path


def tipos(argumentos):
    equivalencias = {'int': 'integer', 'int4': 'integer', 'int8': 'bigint'}
    return [equivalencias.get(p.strip().split()[-1].lower(), p.strip().split()[-1].lower())
            for p in argumentos.split(',') if p.strip()]


def comprobar(catalogo, contrato):
    tablas = {r['tabla']: r for r in catalogo['tablas_stg']}
    vistas = {r['vista']: r for r in catalogo['vistas_api']}
    resultado = dict(contrato=contrato['git_ref'], usuario=catalogo['usuario'], stg=[], rpc=[], vistas=[],
        alcance='Columnas, tipos de argumentos y permisos. Tipos stg y retornos RPC se informan para revisión; no certifica ODBC, CORS ni ejecución.')
    for nombre, columnas in contrato['stg'].items():
        r = tablas.get(nombre)
        reales = [c['columna'] for c in r['columnas']] if r else []
        resultado['stg'].append(dict(tabla=nombre, compatible=reales == columnas,
            faltantes=sorted(set(columnas)-set(reales)), extras=sorted(set(reales)-set(columnas)),
            tipos_reales=r['columnas'] if r else [],
            insert_bot=r.get('puede_insertar', False) if r else False))
    for nombre, esperado in contrato['rpc'].items():
        firma = re.search(r'\((.*)\)', esperado['firma_contrato']).group(1)
        candidatas = [r for r in catalogo['funciones_api'] if r['funcion'] == nombre and tipos(r['argumentos']) == tipos(firma)]
        resultado['rpc'].append(dict(funcion=nombre, firma_compatible=bool(candidatas),
            ejecutar_bot=any(r['puede_ejecutar'] for r in candidatas), detalles=candidatas))
    for nombre, columnas in contrato['vistas'].items():
        r = vistas.get(nombre)
        reales = r['columnas'] if r else []
        resultado['vistas'].append(dict(vista=nombre, compatible=reales == columnas,
            faltantes=sorted(set(columnas)-set(reales)), extras=sorted(set(reales)-set(columnas)),
            lectura_web=r.get('lectura_web', False) if r else False))
    resultado['contrato_completo'] = all(r['compatible'] and r['insert_bot'] for r in resultado['stg']) and all(r['firma_compatible'] and r['ejecutar_bot'] for r in resultado['rpc']) and all(r['compatible'] and r['lectura_web'] for r in resultado['vistas'])
    return resultado


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalogo', type=Path)
    parser.add_argument('--contrato', type=Path, default=Path(__file__).resolve().parents[1] / 'tests/e2e/contrato_v1_1.json')
    args = parser.parse_args()
    r = comprobar(json.loads(args.catalogo.read_text(encoding='utf-8-sig')), json.loads(args.contrato.read_text(encoding='utf-8')))
    print(json.dumps(r, ensure_ascii=False, indent=2))
    raise SystemExit(0 if r['contrato_completo'] else 1)
