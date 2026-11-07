"""Evidencia B-05: cruza el cálculo semanal del sistema (v0 = horas de diciembre, v1 = promedio may-dic) con el Excel.

Entradas: database\\evidencia\\b05\\sistema_may_dic.csv y esperado_semanal.csv (los exporta b05_export.sql),
          hoja Dotacion_Asistencial (tabla Dot_Asistencial, encabezado fila 4) y data\\csv\\param_cargo.csv.
Salidas en database\\evidencia\\b05\\: excel_insumos.csv, tramo.csv, denominador.csv, diferencias_v0.csv,
          diferencias_v1.csv y resumen.md.
Solo persona_id (sin nombres, RUT ni fecha de nacimiento). No modifica la base.
Uso: python scripts\\evidencia_b05.py <planificacion.xlsx> <param_cargo.csv> <dir_evidencia>
"""
import collections
import csv
import datetime
import pathlib
import sys
import warnings

import openpyxl

warnings.filterwarnings("ignore", category=UserWarning)
TOL = 1e-6

COLS = {
    "persona_id": "PersonaId", "it": "IT", "cargo": "Cargo", "area": "Area", "cambio_jornada": "Cambio jornada",
    "inicio_jornada": "Periodo Inicio Jornada", "fin_jornada": "Perido Fin Jornada", "hs_dic": "H/S dic",
    "prom": "Prom_Pond Horas Semanales", "colacion_h": "Horas Colación en Contrato", "nas_total": "H/Sem NAS Total",
    "asig_total": "Total Hrs. Asignación", "pct_nas_asig": "%NAS + Asig. Especiales", "pct_dir": "%Directo",
    "pct_ind": "%Indirecto", "pct_nas": "% NAS", "pct_dir_final": "%Directo Final", "disp_ate_AX": "H/Sem Disp.Ate",
    "min_directa": "Estándar Minutos Atención Directa",
    "ate_dir_semana": "N° Ate Directas (minutos estándar) - Semana may - dic",
}


def num(v):
    if isinstance(v, datetime.timedelta):
        return v.total_seconds() / 3600
    if isinstance(v, datetime.time):
        return v.hour + v.minute / 60 + v.second / 3600
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def txt(v):
    if isinstance(v, datetime.datetime):
        return v.date().isoformat()
    return "" if v is None else str(v).strip()


def igual(a, b, tol=TOL):
    return a is not None and b is not None and abs(a - b) <= tol


def tramo(h, alto=40, bajo=22):  # umbrales documentados en reglas.md / param.general
    if h is None:
        return None
    return 1 if h >= alto else 2 if h >= bajo else 3


def leer_excel(ruta):
    wb = openpyxl.load_workbook(ruta, read_only=True, data_only=True)
    filas = wb["Dotacion_Asistencial"].iter_rows(min_row=4, values_only=True)
    hdr = [str(h).replace("\n", " ").strip() if h is not None else "" for h in next(filas)]
    ix = {k: hdr.index(v) for k, v in COLS.items()}
    out = []
    for n, r in enumerate(filas, start=5):
        if not isinstance(r[ix["persona_id"]], (int, float)):
            continue
        d = {"fila_excel": n}
        for k in COLS:
            v = r[ix[k]]
            d[k] = txt(v) if k in ("cargo", "area", "cambio_jornada", "inicio_jornada", "fin_jornada") else num(v)
        d["persona_id"], d["it"] = int(d["persona_id"]), int(d["it"])
        out.append(d)
    return out


def main(xlsx, param_csv, dir_ev):
    dir_ev = pathlib.Path(dir_ev)
    param = collections.defaultdict(dict)  # cargo -> tramo -> (dir, ind, nas, min)
    for x in csv.DictReader(open(param_csv, encoding="utf-8")):
        param[x["cargo"].strip()][int(x["tramo"])] = (float(x["pct_dir"]), float(x["pct_ind"]), float(x["pct_nas"]),
                                                      float(x["min_directa"]))
    excel = leer_excel(xlsx)
    sistema = {(int(r["persona_id"]), int(r["it"])): r for r in csv.DictReader(open(dir_ev / "sistema_may_dic.csv", encoding="utf-8"))}
    esperado = collections.defaultdict(list)
    for r in csv.DictReader(open(dir_ev / "esperado_semanal.csv", encoding="utf-8")):
        esperado[(int(r["persona_id"]), int(r["it"]), r["campo"])].append(float(r["valor"]))

    filas_por_par = collections.Counter((e["persona_id"], e["it"]) for e in excel)

    # ---------- insumos del Excel y denominador implícito ----------
    for e in excel:
        e["par_repetido"] = filas_por_par[(e["persona_id"], e["it"])] > 1
        pna = e["pct_nas_asig"]
        e["denominador_excel"] = ((e["nas_total"] or 0) + (e["asig_total"] or 0)) / pna if pna else None
        e["horas_periodo_excel"] = e["denominador_excel"] + (e["colacion_h"] or 0) if e["denominador_excel"] else None
        e["AX_consistente"] = igual(e["disp_ate_AX"], e["denominador_excel"] * (1 - pna), 0.01) if e["denominador_excel"] else None

    with open(dir_ev / "excel_insumos.csv", "w", newline="", encoding="utf-8") as f:
        campos = ["fila_excel", "par_repetido"] + list(COLS) + ["denominador_excel", "horas_periodo_excel", "AX_consistente"]
        w = csv.DictWriter(f, fieldnames=campos)
        w.writeheader()
        for e in excel:
            w.writerow({k: e.get(k) for k in campos})

    # ---------- tramo: qué tramos de param_cargo reproducen los % base del Excel ----------
    res_tramo = collections.Counter()
    filas_tramo = []
    for e in excel:
        cargo, variante = e["cargo"], f'{e["cargo"]} {e["area"]}'
        cand = []  # (cargo_param, tramo) que calzan con %Dir, %Ind, %NAS del Excel
        for c in (cargo, variante):
            for t, v in param.get(c, {}).items():
                if igual(v[0], e["pct_dir"]) and igual(v[1], e["pct_ind"]) and igual(v[2], e["pct_nas"]):
                    cand.append((c, t))
        t_prom, t_dic = tramo(e["prom"]), tramo(e["hs_dic"])
        tablas = [param[c] for c in {c for c, _ in cand}] or [param.get(cargo, {})]
        informativo = any(len({v[:3] for v in tb.values()}) > 1 for tb in tablas)
        tramos_ok = {t for _, t in cand}
        if not cand:
            clase = "sin_fila_en_param"
        elif not informativo:
            clase = "no_informativo (mismos % en los 3 tramos)"
        elif t_prom in tramos_ok and t_dic in tramos_ok:
            clase = "calza_promedio_y_hs_dic"
        elif t_prom in tramos_ok:
            clase = "calza_solo_promedio"
        elif t_dic in tramos_ok:
            clase = "calza_solo_hs_dic"
        else:
            clase = "calza_otro_tramo"
        uso_variante = bool(cand) and all(c == variante for c, _ in cand)
        res_tramo[clase] += 1
        filas_tramo.append({"fila_excel": e["fila_excel"], "persona_id": e["persona_id"], "it": e["it"], "cargo": cargo,
                            "area": e["area"], "prom_excel": e["prom"], "hs_dic_excel": e["hs_dic"],
                            "tramo_por_promedio": t_prom, "tramo_por_hs_dic": t_dic,
                            "pct_excel": f'{e["pct_dir"]}/{e["pct_ind"]}/{e["pct_nas"]}',
                            "filas_param_que_calzan": " ".join(f"{c}#t{t}" for c, t in cand),
                            "requiere_cargo_mas_area": uso_variante, "clase": clase})
    with open(dir_ev / "tramo.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(filas_tramo[0]))
        w.writeheader()
        w.writerows(filas_tramo)

    # ---------- denominador: qué jornada usa el Excel en may-dic ----------
    den = collections.Counter()
    filas_den = []
    exc_por_par = {}
    for e in excel:
        exc_por_par.setdefault((e["persona_id"], e["it"]), []).append(e)
    for e in excel:
        s = sistema.get((e["persona_id"], e["it"]))
        h = e["horas_periodo_excel"]
        if h is None or e["hs_dic"] in (None, 0):
            continue
        a = igual(h, e["hs_dic"], 0.01)
        b = s is not None and igual(h, float(s["horas_prom_may_dic"]), 0.01)
        c = s is not None and igual(h, float(s["horas_dic"]), 0.01)
        clave = ("=H/S dic Excel" if a else "≠H/S dic Excel") + " · " + ("=prom may-dic BUK" if b else "≠prom may-dic BUK")
        den[clave] += 1
        if not a or not b:
            filas_den.append({"fila_excel": e["fila_excel"], "persona_id": e["persona_id"], "it": e["it"],
                              "cambio_jornada": e["cambio_jornada"], "hs_dic_excel": e["hs_dic"],
                              "horas_periodo_excel": round(h, 4), "horas_dic_buk": s and s["horas_dic"],
                              "horas_prom_may_dic_buk": s and s["horas_prom_may_dic"],
                              "serie_may_dic_buk": s and s["serie_may_dic"], "AX_consistente": e["AX_consistente"],
                              "igual_hs_dic": a, "igual_prom_buk": b, "igual_dic_buk": c})
    with open(dir_ev / "denominador.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(filas_den[0]) if filas_den else ["vacio"])
        w.writeheader()
        w.writerows(filas_den)

    # ---------- diferencias y clasificación por variante ----------
    def clasificar(s, e, variante):
        causas = []
        if e is None:
            return ["sin_fila_excel"]
        cargo = e["cargo"]
        if cargo.upper() != (s["cargo"] or "").upper():
            causas.append(f"cargo_distinto (Excel {cargo} vs BUK {s['cargo']})")
        t = int(s["tramo"])
        p = param.get(cargo, {}).get(t)
        pv = param.get(f'{cargo} {e["area"]}', {}).get(t)
        pct_iguales = p and igual(p[0], e["pct_dir"]) and igual(p[1], e["pct_ind"]) and igual(p[2], e["pct_nas"])
        if not pct_iguales and not causas:
            if pv and igual(pv[0], e["pct_dir"]) and igual(pv[1], e["pct_ind"]):
                causas.append(f"distribucion_area ({cargo} {e['area']} vs {cargo})")
            elif any(igual(v[0], e["pct_dir"]) and igual(v[1], e["pct_ind"]) and igual(v[2], e["pct_nas"])
                     for v in param.get(cargo, {}).values()):
                causas.append("seleccion_tramo")
            else:
                causas.append("pct_sin_fila_en_param")
        if e["min_directa"] is not None and p and not igual(e["min_directa"], p[3]):
            causas.append(f"minutos_{int(e['min_directa'])}_vs_{int(p[3])}")
        if not igual(float(s["horas_dic"]), e["hs_dic"], 0.01) or not igual(float(s["promedio_ponderado"]), e["prom"], 0.01):
            causas.append("horas_buk_distintas_excel")
        if not igual(float(s["horas_dic"]), float(s["horas_prom_may_dic"]), 0.01):
            causas.append("cambio_jornada_may_dic")
        if not igual(float(s["horas_asignaciones"]), e["asig_total"] or 0) or not igual(float(s["colacion_h"]), e["colacion_h"] or 0):
            causas.append("asignacion_o_colacion")
        return causas or ["otra"]

    metricas = {}
    for var in ("v0", "v1"):
        ok_ate = ok_pdf = tot = 0
        filas = []
        for (pid, it), s in sorted(sistema.items()):
            esp_ate = esperado.get((pid, it, "ate_dir_semana"))
            esp_pdf = esperado.get((pid, it, "pct_dir_final"))
            if not esp_ate:
                continue
            tot += 1
            ate = int(s[f"ate_dir_semana_{var}"]) if s[f"ate_dir_semana_{var}"] else None
            pdf = float(s[f"pct_dir_final_{var}"]) if s[f"pct_dir_final_{var}"] else None
            a_ok = ate is not None and any(igual(ate, x) for x in esp_ate)
            p_ok = esp_pdf is not None and pdf is not None and any(igual(pdf, x, 0.0001) for x in esp_pdf)
            ok_ate += a_ok
            ok_pdf += p_ok
            if not a_ok:
                cand = exc_por_par.get((pid, it), [])
                e = max(cand, key=lambda x: x["hs_dic"] or 0) if cand else None
                causas = clasificar(s, e, var)
                filas.append({"persona_id": pid, "it": it, "cargo": s["cargo"], "area_excel": e and e["area"],
                              "fila_excel": e and e["fila_excel"], "par_repetido": len(cand) > 1,
                              "esperado_ate": "|".join(str(int(x)) for x in esp_ate), "obtenido_ate": ate,
                              "esperado_pct_dir_final": "|".join(f"{x:.6f}" for x in (esp_pdf or [])),
                              "obtenido_pct_dir_final": pdf, "tramo_sistema": s["tramo"],
                              "prom_sistema": s["promedio_ponderado"], "prom_excel": e and e["prom"],
                              "horas_dic_sistema": s["horas_dic"], "hs_dic_excel": e and e["hs_dic"],
                              "horas_prom_may_dic_sistema": s["horas_prom_may_dic"],
                              "horas_periodo_excel": e and e["horas_periodo_excel"] and round(e["horas_periodo_excel"], 4),
                              "pct_sistema": f'{s["pct_dir"]}/{s["pct_ind"]}/{s["pct_nas"]}',
                              "pct_excel": e and f'{e["pct_dir"]}/{e["pct_ind"]}/{e["pct_nas"]}',
                              "min_sistema": s["min_directa"], "min_excel": e and e["min_directa"],
                              "asig_sistema": s["horas_asignaciones"], "asig_excel": e and e["asig_total"],
                              "colacion_sistema": s["colacion_h"], "colacion_excel": e and e["colacion_h"],
                              "serie_may_dic_buk": s["serie_may_dic"], "causas": "; ".join(causas)})
        metricas[var] = (ok_ate, ok_pdf, tot, filas)
        with open(dir_ev / f"diferencias_{var}.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(filas[0]))
            w.writeheader()
            w.writerows(filas)

    # aciertos perdidos / ganados
    fallas = {v: {(r["persona_id"], r["it"]) for r in metricas[v][3]} for v in metricas}
    perdidos = sorted(fallas["v1"] - fallas["v0"])
    ganados = sorted(fallas["v0"] - fallas["v1"])

    def pct(a, b):
        return f"{a}/{b} = {100 * a / b:.1f} %"

    causas_v = {v: collections.Counter(c.split(" (")[0] for r in metricas[v][3] for c in r["causas"].split("; ")) for v in metricas}
    with open(dir_ev / "resumen.md", "w", encoding="utf-8") as f:
        f.write("# Evidencia B-05 · resumen generado por scripts\\evidencia_b05.py\n\n")
        f.write("Medida: capa `calc.v_semanal`, periodo `may_dic`, contra `stg.esperado` (sin mes). Numerador = persona-IT con "
                "`ate_dir_semana` igual (o `pct_dir_final` a ±0,0001); denominador = persona-IT con esperado `ate_dir_semana` "
                "y fila en el sistema. Pares repetidos del Excel: acierto si calza con cualquiera de sus filas.\n\n")
        f.write("| Variante | ate_dir_semana | pct_dir_final |\n|---|---|---|\n")
        for v, nombre in (("v0", "v0 · horas de diciembre (antes)"), ("v1", "v1 · promedio may-dic (después)")):
            a, p, t, _ = metricas[v]
            f.write(f"| {nombre} | {pct(a, t)} | {pct(p, t)} |\n")
        f.write(f"\nAciertos perdidos v0→v1: {len(perdidos)} {perdidos}. Ganados: {len(ganados)} {ganados}.\n\n")
        for v in metricas:
            f.write(f"Causas de las diferencias {v} (una fila puede tener varias): {dict(causas_v[v])}\n\n")
        f.write("## Tramo (tramo.csv)\n\n")
        for k, n in res_tramo.most_common():
            f.write(f"- {k}: {n}\n")
        f.write("\n## Jornada usada por el Excel en may-dic (denominador.csv)\n\n"
                "horas_periodo_excel = (H/Sem NAS Total + Total Hrs. Asignación) / %NAS + Asig. Especiales + colación.\n\n")
        for k, n in den.most_common():
            f.write(f"- {k}: {n}\n")
        f.write(f"\nAX (H/Sem Disp.Ate) = denominador × (1 − %NAS+Asig) en "
                f"{sum(1 for e in excel if e['AX_consistente'])}/{sum(1 for e in excel if e['AX_consistente'] is not None)} filas.\n")
    print((dir_ev / "resumen.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
