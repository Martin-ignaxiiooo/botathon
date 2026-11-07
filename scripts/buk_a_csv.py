"""Convierte la hoja Dotacion_2026 de una base BUK (.xlsx) a CSV con las columnas de stg.buk_fila (Contrato 1).

Solo para pruebas sin Blue Prism (en el sistema final la carga la hace el robot, P02).
Uso: python scripts\\buk_a_csv.py <archivo.xlsx> <salida.csv>
Requiere openpyxl (pip install --user openpyxl). No exporta la fecha de nacimiento ni nombres.
"""
import csv
import datetime
import sys

import openpyxl

# columna del Excel -> columna de stg.buk_fila (sin carga_id)
COLUMNAS = [
    ("IT", "it"),
    ("Instituto", "instituto"),
    ("PersonaId", "persona_id"),
    ("Área", "area"),
    ("Nombre Sub-área", "sub_area"),
    ("Centro de Costo", "centro_costo"),
    ("Periodo", "periodo"),
    ("Tipo de Contrato", "tipo_contrato"),
    ("Tipo_Trabajador", "tipo_trabajador"),
    ("Fecha Ingreso Compañía", "fecha_ingreso"),
    ("Fecha Término", "fecha_termino"),
    ("Horas Semanales", "horas_semanales"),
    ("Cargo", "cargo"),
    ("Días de la Jornada", "dias_jornada"),
    ("Ndias", "ndias"),
    ("Cod_Esp", "cod_esp"),
]


def texto(v):
    if v is None:
        return ""
    if isinstance(v, datetime.datetime):
        return v.date().isoformat()
    if isinstance(v, datetime.date):
        return v.isoformat()
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).strip()


NUMERICOS = {"it": int, "persona_id": int, "horas_semanales": float, "ndias": int}
FECHAS = ("periodo", "fecha_ingreso", "fecha_termino")


def validar(columnas, valores):
    """Devuelve (campo, valor, motivo) del primer valor ilegible o None."""
    for campo, v in zip(columnas, valores):
        if v == "":
            continue
        if campo in NUMERICOS:
            try:
                NUMERICOS[campo](float(v.replace(",", ".")))
            except ValueError:
                return campo, v, f"{campo} no es numérico"
        elif campo in FECHAS:
            try:
                datetime.date.fromisoformat(v[:10])
            except ValueError:
                return campo, v, f"{campo} no es una fecha"
    return None


def main(origen, destino):
    wb = openpyxl.load_workbook(origen, read_only=True, data_only=True)
    ws = wb["Dotacion_2026"] if "Dotacion_2026" in wb.sheetnames else wb[wb.sheetnames[0]]
    filas = ws.iter_rows(values_only=True)
    encabezado = None
    for fila in filas:  # el encabezado está en la fila 2 (la 1 viene vacía)
        if fila and "PersonaId" in [texto(c) for c in fila]:
            encabezado = [texto(c) for c in fila]
            break
    if encabezado is None:
        raise SystemExit("No encontré el encabezado (columna PersonaId)")
    idx = {}
    for excel, _ in COLUMNAS:
        if excel not in encabezado:
            raise SystemExit(f"Falta la columna '{excel}' en la hoja")
        idx[excel] = encabezado.index(excel)

    columnas = [c for _, c in COLUMNAS]
    n = 0
    errores = []
    with open(destino, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(columnas)
        for num_fila, fila in enumerate(filas, start=3):  # datos desde la fila 3 del Excel
            if not fila:
                continue
            valores = [texto(fila[idx[e]]) if idx[e] < len(fila) else "" for e, _ in COLUMNAS]
            it, persona = valores[0], valores[2]
            if it in ("", "IT") or persona in ("", "PersonaId"):  # filas vacías y encabezado repetido
                continue
            error = validar(columnas, valores)
            if error:
                pid = persona if persona.isdigit() else ""
                errores.append([num_fila, pid, *error])
                continue
            w.writerow(valores)
            n += 1
    with open(destino + ".errores.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["fila", "persona_id", "campo", "valor", "motivo"])
        w.writerows(errores)
    print(f"{n} filas -> {destino} · {len(errores)} filas rechazadas")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
