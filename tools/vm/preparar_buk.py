"""Lee únicamente Dotacion_2026; transmite tipos al C# original y excluye datos ajenos."""
import argparse
import datetime as dt
import json
import unicodedata
from pathlib import Path
import xml.etree.ElementTree as ET

from openpyxl import load_workbook


def clave(valor):
    return ''.join(c.lower() for c in unicodedata.normalize('NFD', str(valor or ''))
                   if c.isalnum() and not unicodedata.combining(c))


def preparar(archivo, catalogos, salida):
    libro = load_workbook(archivo, read_only=True, data_only=True)
    try:
        hoja = libro['Dotacion_2026']
        cabecera = next(hoja.iter_rows(min_row=2, max_row=2, values_only=True))
        excluir = {'fechadenacimiento', 'tipotrab161225', 'regsic'}
        indices = {i for i, v in enumerate(cabecera) if clave(v) in excluir}
        raiz = ET.Element('buk', columnas=str(len(cabecera)))
        datos = ET.SubElement(raiz, 'datos')
        for fila in hoja.iter_rows(max_col=len(cabecera), values_only=True):
            nodo = ET.SubElement(datos, 'fila')
            for i, valor in enumerate(fila):
                celda = ET.SubElement(nodo, 'c')
                if i in indices:
                    # Preservar solo presencia: el C# prueba fila vacía en TODAS
                    # las columnas antes de descartar estos campos. Nunca copiar DOB.
                    celda.set('tipo', 'texto' if valor is not None and str(valor).strip() else 'null')
                    if celda.get('tipo') == 'texto':
                        celda.text = '[dato excluido]'
                elif valor is None:
                    celda.set('tipo', 'null')
                elif isinstance(valor, (dt.date, dt.datetime)):
                    celda.set('tipo', 'fecha')
                    celda.text = valor.strftime('%Y-%m-%d')
                elif isinstance(valor, (int, float)) and not isinstance(valor, bool):
                    celda.set('tipo', 'numero')
                    celda.text = str(valor)
                else:
                    celda.set('tipo', 'texto')
                    celda.text = str(valor)
        aprobados = json.loads(Path(catalogos).read_text(encoding='utf-8-sig'))
        its = ET.SubElement(raiz, 'institutos')
        for registro in aprobados['institutos']:
            ET.SubElement(its, 'it').text = str(registro['it'])
        cargos = ET.SubElement(raiz, 'cargos')
        for registro in aprobados['cargos']:
            ET.SubElement(cargos, 'cargo').text = registro['cargo_origen']
        ET.ElementTree(raiz).write(salida, encoding='utf-8', xml_declaration=True)
    finally:
        libro.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archivo')
    parser.add_argument('catalogos')
    parser.add_argument('salida')
    args = parser.parse_args()
    preparar(args.archivo, args.catalogos, args.salida)
