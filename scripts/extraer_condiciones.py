"""Extrae de la hoja Dotacion_Asistencial (Excel de planificación) los datos por persona que el BUK no trae.

Genera en <destino>:
  asignaciones.csv        persona_id,it,tipo,horas            (asignaciones 1-4 con horas > 0)
  condiciones_persona.csv persona_id,it,colacion_h,dias_semana_contrato,feriado_adicional_dias,
                          capacitacion_dias,vacaciones_pendientes_dias,licencia_extensa
Sin nombres, RUT ni fecha de nacimiento. Si una persona-IT aparece dos veces se toma la fila con más horas en diciembre.
Uso: python scripts\\extraer_condiciones.py "data\\excel\\Nac - Planificacion Asistencial x mes.xlsx" database\\seed\\csv
Requiere openpyxl (pip install --user openpyxl).
"""
import csv
import pathlib
import sys
import warnings

import openpyxl

warnings.filterwarnings("ignore", category=UserWarning)

ASIGNACIONES = [  # (columna del tipo o None, columna de horas, tipo por defecto)
    ("Asignación 1 (seleccionar de lista desplegable)", "Hrs. Asignación 1", "Asignación 1"),
    ("Asignación 2 (seleccionar de lista desplegable)", "Hrs. Asignación 2", "Asignación 2"),
    ("Por Autorizar DMN y VP  (seleccionar de lista desplegable)", "Hrs. Asignación 3", "Por autorizar DMN y VP"),
    (None, "Hrs. Asignación 4", "Asignación 4"),
]
CONDICIONES = [
    ("Horas Colación en Contrato", "colacion_h"),
    ("N° Días Semana Contrato", "dias_semana_contrato"),
    ("Feriado legal adicional", "feriado_adicional_dias"),
    ("Plan anual capacitación por cargo", "capacitacion_dias"),
    ("Vacaciones Legales Pendientes Periodos Anteriores", "vacaciones_pendientes_dias"),
    ("Licencia Extensa", "licencia_extensa"),
]


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def txt(v):
    if v is None:
        return ""
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).strip()


def main(origen, destino):
    destino = pathlib.Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.load_workbook(origen, read_only=True, data_only=True)
    ws = wb["Dotacion_Asistencial"]
    filas = ws.iter_rows(min_row=4, values_only=True)
    hdr = [str(h).replace("\n", " ").strip() if h is not None else "" for h in next(filas)]

    def col(nombre):
        if nombre not in hdr:
            raise SystemExit(f"Falta la columna '{nombre}'")
        return hdr.index(nombre)

    c_persona, c_it, c_hsdic = col("PersonaId"), col("IT"), col("H/S dic")
    elegidas = {}
    for r in filas:
        if not isinstance(r[c_persona], (int, float)) or not isinstance(r[c_it], (int, float)):
            continue
        clave = (int(r[c_persona]), int(r[c_it]))
        if clave not in elegidas or num(r[c_hsdic]) > num(elegidas[clave][c_hsdic]):
            elegidas[clave] = r

    n_asig = 0
    with open(destino / "asignaciones.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["persona_id", "it", "tipo", "horas"])
        for (persona, it), r in sorted(elegidas.items()):
            for c_tipo, c_horas, defecto in ASIGNACIONES:
                horas = num(r[col(c_horas)])
                if horas > 0:
                    tipo = txt(r[col(c_tipo)]) if c_tipo else ""
                    w.writerow([persona, it, tipo or defecto, horas])
                    n_asig += 1

    with open(destino / "condiciones_persona.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["persona_id", "it"] + [c for _, c in CONDICIONES])
        for (persona, it), r in sorted(elegidas.items()):
            valores = []
            for excel, campo in CONDICIONES:
                v = r[col(excel)]
                valores.append(txt(v) if campo == "licencia_extensa" else num(v))
            w.writerow([persona, it] + valores)
    print(f"{len(elegidas)} persona-IT, {n_asig} asignaciones -> {destino}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
