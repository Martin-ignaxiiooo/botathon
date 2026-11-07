"""Extrae reglas y resultado esperado de la planilla de planificación a CSV.

Uso (PowerShell):
    python data\\extraer.py "data\\excel\\Nac - Planificacion Asistencial x mes.xlsx" data\\csv

Genera, con las columnas del contrato stg.* (sin carga_id):
    param_cargo.csv, param_asignacion.csv, param_calendario.csv,
    param_grupal.csv, excepciones.csv, esperado.csv
"""
import csv
import sys
import warnings
from pathlib import Path

import openpyxl
from openpyxl.utils import column_index_from_string as col
from openpyxl.utils.cell import range_boundaries

warnings.filterwarnings("ignore")


# Archivo auxiliar independiente: no modifica ningún contrato stg.*.
INSUMOS_CAMPOS = {
    "persona_id": "PersonaId", "it": "IT", "cargo": "Cargo", "area": "Area",
    "horas_semana_dic": "H/S dic", "prom_pond_horas": "Prom_Pond Horas Semanales",
    "dias_semana": "N° Días Semana Contrato", "colacion_contrato": "Horas Colación en Contrato",
    "horas_nas_total": "H/Sem NAS Total", "horas_asignacion": "Total Hrs. Asignación",
    "asignacion_1": "Asignación 1 (seleccionar de lista desplegable)", "horas_asig_1": "Hrs. Asignación 1",
    "asignacion_2": "Asignación 2 (seleccionar de lista desplegable)", "horas_asig_2": "Hrs. Asignación 2",
    "pct_dir_base": "%Directo", "pct_ind_base": "%Indirecto", "pct_nas_base": "% NAS",
    "min_directa": "Estándar Minutos Atención Directa", "min_indirecta": "Estándar Minutos Atención Indirecta",
    **{f"semhab_{m}": f"SemHab{m}" for m in range(1, 13)},
}


def insumos(wbv):
    """Copia fiel del cuerpo de Dot_Asistencial; no consolida contratos repetidos."""
    ws = wbv["Dotacion_Asistencial"]
    tabla = ws.tables["Dot_Asistencial"]
    _, primera, _, ultima = range_boundaries(tabla.ref)
    if primera != 4:
        raise ValueError("La cabecera Dot_Asistencial debe estar en la fila 4")
    ultima -= tabla.totalsRowCount or 0
    cabeceras = {" ".join(str(c.value).split()): c.column for c in ws[primera] if c.value is not None}
    indices = {campo: cabeceras[encabezado] for campo, encabezado in INSUMOS_CAMPOS.items()}
    textos = {"cargo", "area", "asignacion_1", "asignacion_2"}
    filas = []
    for r in range(primera + 1, ultima + 1):
        persona, it = ws.cell(r, indices["persona_id"]).value, ws.cell(r, indices["it"]).value
        if not isinstance(persona, (int, float)) or not isinstance(it, (int, float)):
            continue
        valores = []
        for campo, ci in indices.items():
            valor = ws.cell(r, ci).value
            if campo in {"persona_id", "it"}:
                if int(valor) != valor:
                    raise ValueError(f"Identificador no entero en fila {r}")
                valor = int(valor)
            elif campo in textos:
                valor = "" if valor is None else str(valor).strip()
            else:
                if valor is not None and valor != "" and num(valor) is None:
                    raise ValueError(f"Insumo no numérico: {campo}, fila {r}")
                valor = num(valor)  # Mantener NULL, no inventar un cero.
            valores.append(valor)
        filas.append(valores)
    return filas


def num(v, default=None):
    if v is None or v == "":
        return default
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def escribir(ruta, columnas, filas):
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(columnas)
        w.writerows(filas)
    print(f"  {ruta.name}: {len(filas)} filas")


def param_cargo(wb):
    ws = wb["Distribucion_NAC"]
    filas, alertas = [], []
    for r in range(7, 93):
        cargo = ws.cell(r, col("B")).value
        if not cargo:
            continue
        cod = ws.cell(r, col("A")).value or ""
        unidad = ws.cell(r, col("C")).value or ""
        mdir = int(num(ws.cell(r, col("D")).value, 0))
        mind = int(num(ws.cell(r, col("E")).value, 30))
        for tramo, (cd, ci, cn) in enumerate([("F", "G", "H"), ("I", "J", "K"), ("L", "M", "N")], start=1):
            d = num(ws.cell(r, col(cd)).value, 0.0)
            i = num(ws.cell(r, col(ci)).value, 0.0)
            n = num(ws.cell(r, col(cn)).value, 0.0)
            if abs(d + i + n - 1) > 0.001:
                alertas.append(f"fila {r} {cargo} tramo {tramo}: suma {d + i + n:.3f}")
            filas.append([cod, str(cargo).strip(), unidad, mdir, mind, tramo, d, i, n])
    return filas, alertas


def param_asignacion(wb):
    ws = wb["Distribucion_NAC"]
    filas = []
    for r in range(7, 40):
        tipo = ws.cell(r, col("R")).value
        if not tipo:
            continue
        desc = ws.cell(r, col("T")).value or ""
        horas = num(ws.cell(r, col("S")).value)
        filas.append([str(tipo).strip(), "" if horas is None else horas, "DMN" in str(desc).upper(), desc])
    return filas


def param_calendario(wbv):
    ws = wbv["Parámetros"]
    filas = []
    for r in range(3, 15):
        mes = int(ws.cell(r, col("S")).value)
        dias = int(num(ws.cell(r, col("W")).value, 0))
        inhabiles = int(num(ws.cell(r, col("U")).value, 0))  # sin vacaciones colectivas
        habiles = int(num(ws.cell(r, col("Y")).value, 0))
        semanas = num(ws.cell(r, col("AD")).value, 0)
        filas.append([mes, "general", dias, inhabiles, habiles, semanas])
    return filas


def param_grupal(wbv):
    ws = wbv["Parámetros"]
    filas = []
    for r in range(4, 26):
        cod = ws.cell(r, col("F")).value
        pct = num(ws.cell(r, col("G")).value)
        if not cod or pct is None:
            continue
        filas.append([cod, "San-Con", pct, num(ws.cell(r, col("H")).value, 0)])
        filas.append([cod, "otros", pct, num(ws.cell(r, col("I")).value, 0)])
    return filas


def excepciones(wbv):
    ws = wbv["Excepciones"]
    filas = []
    meses = [col(c) for c in ["K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V"]]
    for r in range(3, ws.max_row + 1):
        persona = ws.cell(r, col("E")).value
        it = ws.cell(r, col("C")).value
        if persona is None or it is None:
            continue
        for m, c in enumerate(meses, start=1):
            h = num(ws.cell(r, c).value)
            if h is not None:
                filas.append([int(persona), int(it), m, h])
    return filas


def esperado(wbv):
    ws = wbv["Dotacion_Asistencial"]
    hdr = {str(ws.cell(4, c).value).replace("\n", " ").strip(): c for c in range(1, ws.max_column + 1)}

    def c(nombre):
        for k, v in hdr.items():
            if k.startswith(nombre):
                return v
        raise KeyError(nombre)

    simples = {
        "pct_dir_final": c("%Directo Final"),
        "pct_ind_final": c("%Indirecto Final"),
        "ate_dir_semana": c("N° Ate Directas"),
        "ate_ind_semana": c("N° Ate Indirectas"),
        "ate_semana_total": c("Total Atenciones por Semana"),
        "horas_semana_dic": c("H/S dic"),
        "prom_pond_horas": c("Prom_Pond Horas Semanales"),
    }
    mensuales = {
        "semhab": "SemHab",
        "plan_ate_dir": "PlanAteDir",
        "plan_ate_dir_ind": "PlanAteDir+Ind",
        "meta": "MG_AteDir",
        "meta_dir_ind": "MG_AteDir+Ind",
    }
    filas = []
    for r in range(5, ws.max_row + 1):
        persona = ws.cell(r, c("PersonaId")).value
        it = ws.cell(r, c("IT")).value
        if not isinstance(persona, (int, float)) or not isinstance(it, (int, float)):
            continue
        for campo, ci in simples.items():
            v = num(ws.cell(r, ci).value)
            if v is not None:
                filas.append([int(persona), int(it), campo, "", v])
        for campo, pref in mensuales.items():
            for m in range(1, 13):
                v = num(ws.cell(r, hdr[f"{pref}{m}"]).value)
                if v is not None:
                    filas.append([int(persona), int(it), campo, m, v])
    return filas


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    origen, destino = Path(sys.argv[1]), Path(sys.argv[2])
    destino.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.load_workbook(origen)
    wbv = openpyxl.load_workbook(origen, data_only=True)

    print("Generando CSV en", destino)
    cargos, alertas = param_cargo(wb)
    escribir(destino / "param_cargo.csv",
             ["cod_esp", "cargo", "unidad", "min_directa", "min_indirecta", "tramo", "pct_dir", "pct_ind", "pct_nas"], cargos)
    escribir(destino / "param_asignacion.csv", ["tipo", "horas_semana", "requiere_dmn", "descripcion"], param_asignacion(wb))
    escribir(destino / "param_calendario.csv", ["mes", "zona", "dias", "inhabiles", "dias_habiles", "semanas"], param_calendario(wbv))
    escribir(destino / "param_grupal.csv", ["cod_esp", "grupo_it", "pct_grupal", "pacientes_grupo"], param_grupal(wbv))
    escribir(destino / "excepciones.csv", ["persona_id", "it", "mes", "horas"], excepciones(wbv))
    escribir(destino / "esperado.csv", ["persona_id", "it", "campo", "mes", "valor"], esperado(wbv))
    filas_insumos = insumos(wbv)
    escribir(destino / "insumos.csv", list(INSUMOS_CAMPOS), filas_insumos)
    pares_insumos = {(f[0], f[1]) for f in filas_insumos}
    if len(pares_insumos) != len(filas_insumos):
        print(f"Aviso insumos: {len(filas_insumos)} filas fuente, {len(pares_insumos)} pares persona/IT. "
              "Se conservan los contratos repetidos sin agregarlos; revisar diagnóstico por fila Excel.")
    if alertas:
        print(f"Alertas ({len(alertas)}) cargos cuyo %dir+%ind+%nas no suma 1:")
        for a in alertas:
            print("  -", a)


if __name__ == "__main__":
    main()
