"""Genera los JSON de web/mock/ con datos ficticios y coherentes (D-03).

Uso (desde la raíz del repo):  python web\\mock\\generar_mocks.py

Salida: un JSON por vista de docs/contratos.md (Contrato 3) + escenarios.json.
La semilla es fija: ejecutar de nuevo produce los mismos archivos.
Los parámetros (cargo/tramo, calendario) se leen de data\\csv; no se modifican.
"""
import csv
import json
import math
import random
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = Path(__file__).resolve().parent
EPS = 1e-9

# --- Parámetros (en el sistema real viven en param.*) ---------------------------------
META_PCT = 0.9
MES_JORNADA_42 = 5          # desde mayo la jornada legal baja de 44 a 42 h
FACTOR_JORNADA_42 = 0.96    # "mayo a dic: 4 % menos de atenciones"
MIN_DIRECTA = 40
MIN_INDIRECTA = 30
COLACION_HORAS = 1.25       # 0,25 h x 5 días, solo jornadas >= 30 h

INSTITUTOS = {131: "Santiago", 81: "Concepción", 11: "Arica"}
CARGO_AREA = {
    "KI": "KINESIOLOGO",
    "TO": "TERAPEUTA OCUPACIONAL",
    "FI": "MEDICO FISIATRA",
    "ED": "EDUCADOR",
}
AREA_DE_CARGO = {v: k for k, v in CARGO_AREA.items()}
# cod_esp de param_cargo para cada cargo del mock
COD_ESP = {"KINESIOLOGO": "KI", "TERAPEUTA OCUPACIONAL": "UTA",
           "MEDICO FISIATRA": "FI", "EDUCADOR": "ED"}


def leer_csv(nombre):
    with open(RAIZ / "data" / "csv" / nombre, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


SEMANAS = {int(r["mes"]): float(r["semanas"]) for r in leer_csv("param_calendario.csv")}
PARAM_CARGO = {}
for r in leer_csv("param_cargo.csv"):
    if r["cod_esp"] == COD_ESP.get(r["cargo"]):
        PARAM_CARGO[(r["cargo"], int(r["tramo"]))] = (
            float(r["pct_dir"]), float(r["pct_ind"]), float(r["pct_nas"]))


def piso(x):
    return math.floor(x + EPS)


# --- Profesionales ficticios -----------------------------------------------------------
# cambios: lista de (mes_vigencia, dict de campos que cambian)
PROFESIONALES = [
    dict(id=104512, it=131, area="KI", h=44),
    dict(id=108377, it=131, area="TO", h=44),
    dict(id=112960, it=131, area="FI", h=22),
    dict(id=115043, it=131, area="ED", h=44),
    dict(id=118826, it=131, area="KI", h=44, cambios=[(7, dict(area="TO"))]),
    dict(id=121407, it=81, area="KI", h=44),
    dict(id=124981, it=81, area="TO", h=30),
    dict(id=127354, it=81, area="FI", h=22),
    dict(id=130690, it=81, area="ED", h=44),
    dict(id=133218, it=81, area="ED", h=30, ultimo_mes=9),            # baja vigente mes 10
    dict(id=136745, it=11, area="KI", h=44),
    dict(id=139902, it=11, area="TO", h=44),
    dict(id=142571, it=11, area="ED", h=44, cambios=[(9, dict(h=30))]),
    dict(id=145836, it=11, area="KI", h=44, cambios=[(8, dict(it=131))]),
    dict(id=149120, it=11, area="TO", h=44, primer_mes=11),           # alta vigente mes 11
]
# horas semanales de asignaciones (NAS adicional) por persona
ASIGNACION = {104512: 1, 108377: 0, 112960: 1, 115043: 0, 118826: 1, 121407: 2,
              124981: 2, 127354: 2, 130690: 1, 133218: 0, 136745: 0, 139902: 1,
              142571: 2, 145836: 1, 149120: 0}


def estado_en_mes(p, m):
    """Instituto, área y horas de la persona en el mes m (None si no tiene fila)."""
    if m < p.get("primer_mes", 1) or m > p.get("ultimo_mes", 12):
        return None
    e = dict(it=p["it"], area=p["area"], h=p["h"])
    for mes_v, cambio in p.get("cambios", []):
        if m >= mes_v:
            e.update(cambio)
    return e


def tramo_de(h):
    return 1 if h >= 40 - EPS else 2 if h >= 22 - EPS else 3


def descuentos():
    """Semanas no trabajadas por persona y mes (vacaciones, licencias, días adicionales)."""
    rng = random.Random(33)
    d = {}
    for p in PROFESIONALES:
        for m in range(1, 13):
            if m == 1:
                x = rng.choice([0, 0, 0.2, 0.4])
            elif m == 2:
                x = rng.choice([1.4, 1.8, 2.2, 2.6, 3.0])   # vacaciones de verano
            else:
                x = rng.choice([0, 0, 0, 0.2, 0.2, 0.6])
            if m >= 7:
                x += 0.1
            if m == 9:
                x += 0.1
            if m == 12:
                x += 0.2
            d[(p["id"], m)] = round(x, 2)
    return d


DESC = descuentos()


def calcular(meta_pct=META_PCT, mes_jornada=MES_JORNADA_42, param_cargo=None):
    """Una fila por persona y mes con todo lo que publican las vistas."""
    pc = dict(PARAM_CARGO)
    if param_cargo:
        pc.update(param_cargo)
    filas = []
    for p in PROFESIONALES:
        meses = [m for m in range(1, 13) if estado_en_mes(p, m)]
        prom_h = sum(estado_en_mes(p, m)["h"] for m in meses) / len(meses)
        tramo = tramo_de(prom_h)
        for m in meses:
            e = estado_en_mes(p, m)
            cargo = CARGO_AREA[e["area"]]
            pdir, pind, pnas = pc[(cargo, tramo)]
            h = e["h"] * (FACTOR_JORNADA_42 if m >= mes_jornada else 1.0)
            col = COLACION_HORAS if e["h"] >= 30 else 0.0
            disp = h - col
            pnas_asig = (pnas * h + ASIGNACION[p["id"]]) / disp
            pct_dir = pdir * (1 - pnas_asig) / (pdir + pind)
            pct_ind = pind * (1 - pnas_asig) / (pdir + pind)
            ate_sem = piso(disp * pct_dir * 60 / MIN_DIRECTA)
            ind_sem = piso(disp * pct_ind * 60 / MIN_INDIRECTA)
            sem_cal = SEMANAS[m]
            sem_hab = max(0.0, round(sem_cal - DESC[(p["id"], m)], 2))
            ate = piso(ate_sem * sem_hab)
            ate_i = piso(ind_sem * sem_hab)
            hc = h * sem_cal
            h_dir = pct_dir * disp * sem_cal
            h_ind = pct_ind * disp * sem_cal
            filas.append(dict(
                persona_id=p["id"], it=e["it"], area=e["area"], cargo=cargo, mes=m,
                horas_contratadas=hc, h_dir=h_dir, h_ind=h_ind, h_nas=pnas_asig * disp * sem_cal,
                pct_dir_final=pct_dir, ate_sem=ate_sem, ate=ate, ate_ind=ate_i,
                sem_hab=sem_hab, meta=piso(ate * meta_pct), foja=h_dir / hc,
            ))
    return filas


def agrupar(filas, clave):
    g = defaultdict(list)
    for f in filas:
        g[clave(f)].append(f)
    return g


def sumar(fs, campo):
    return sum(f[campo] for f in fs)


def foja_pond(fs):
    return sumar(fs, "h_dir") / sumar(fs, "horas_contratadas")


BASE = calcular()
assert all(0.45 <= f["foja"] <= 0.65 for f in BASE), \
    sorted(round(f["foja"], 3) for f in BASE)[::10]
assert all(f["meta"] == piso(f["ate"] * META_PCT) for f in BASE)


# --- Vistas ---------------------------------------------------------------------------
def v_profesional_mes():
    return [dict(persona_id=f["persona_id"], it=f["it"], cargo=f["cargo"], area=f["area"],
                 mes=f["mes"], horas_contratadas=round(f["horas_contratadas"], 2),
                 pct_dir_final=round(f["pct_dir_final"], 6), atenciones_dir=f["ate"],
                 atenciones_dir_ind=f["ate"] + f["ate_ind"], meta=f["meta"],
                 foja=round(f["foja"], 4)) for f in BASE]


def v_instituto_area_mes():
    out = []
    g = agrupar(BASE, lambda f: (f["it"], f["area"], f["cargo"], f["mes"]))
    for (it, area, cargo, mes), fs in sorted(g.items(), key=lambda kv: (-kv[0][0], kv[0][1], kv[0][3])):
        out.append(dict(it=it, instituto=INSTITUTOS[it], area=area, cargo=cargo, mes=mes,
                        atenciones_dir=sumar(fs, "ate"), meta=sumar(fs, "meta"),
                        foja=round(foja_pond(fs), 4), dotacion=len(fs),
                        horas_contratadas=round(sumar(fs, "horas_contratadas"), 2),
                        horas_dir=round(sumar(fs, "h_dir"), 2), horas_ind=round(sumar(fs, "h_ind"), 2),
                        horas_nas=round(sumar(fs, "h_nas"), 2)))
    return out


def v_nacional_mes():
    out = []
    for mes, fs in sorted(agrupar(BASE, lambda f: f["mes"]).items()):
        out.append(dict(mes=mes, atenciones_dir=sumar(fs, "ate"), atenciones_ind=sumar(fs, "ate_ind"),
                        meta=sumar(fs, "meta"), horas_dir=round(sumar(fs, "h_dir"), 2),
                        horas_ind=round(sumar(fs, "h_ind"), 2), horas_nas=round(sumar(fs, "h_nas"), 2),
                        foja=round(foja_pond(fs), 4)))
    return out


ULTIMA_CARGA = "2026-11-04T09:15:42-03:00"


def v_kpi():
    return [dict(atenciones_plan=sumar(BASE, "ate"), meta=sumar(BASE, "meta"),
                 foja=round(foja_pond(BASE), 4),
                 horas_contratadas=round(sumar(BASE, "horas_contratadas"), 2),
                 dotacion=sum(1 for f in BASE if f["mes"] == 12), ultima_carga=ULTIMA_CARGA)]


# --- Cargas, errores y cambios ---------------------------------------------------------
CARGA_ERRORES = 1
CARGA_CAMBIOS = 2
ARCHIVO_ERRORES = "buk_2026-10.xlsx"


def v_errores_carga():
    filas = [
        (12, 124981, "horas_semanales", "La jornada debe ser un número entre 1 y 45"),
        (25, 142571, "fecha_termino", "La fecha de término es anterior a la fecha de ingreso"),
        (31, None, "persona_id", "Campo obligatorio vacío: PersonaId"),
        (48, 133218, "cod_esp", "El código de especialidad no existe en los parámetros"),
        (63, 118826, "periodo", "El período 2025-12-01 está fuera del año de planificación"),
    ]
    return [dict(carga_id=CARGA_ERRORES, archivo=ARCHIVO_ERRORES, fila=fi, persona_id=pid,
                 campo=c, motivo=mo) for fi, pid, c, mo in filas]


def v_cambios():
    det = "2026-11-04T09:16:30-03:00"
    return [
        dict(carga_id=CARGA_CAMBIOS, tipo="cambio_cargo", persona_id=118826, it=131, mes_vigencia=7,
             antes={"cargo": "KINESIOLOGO", "area": "KI"},
             despues={"cargo": "TERAPEUTA OCUPACIONAL", "area": "TO"}, detectado_en=det),
        dict(carga_id=CARGA_CAMBIOS, tipo="cambio_it", persona_id=145836, it=131, mes_vigencia=8,
             antes={"it": 11, "instituto": "Arica"},
             despues={"it": 131, "instituto": "Santiago"}, detectado_en=det),
        dict(carga_id=CARGA_CAMBIOS, tipo="cambio_jornada", persona_id=142571, it=11, mes_vigencia=9,
             antes={"horas_semanales": 44}, despues={"horas_semanales": 30}, detectado_en=det),
        dict(carga_id=CARGA_CAMBIOS, tipo="baja", persona_id=133218, it=81, mes_vigencia=10,
             antes={"fecha_termino": None, "horas_semanales": 30},
             despues={"fecha_termino": "2026-09-30", "horas_semanales": 30}, detectado_en=det),
        dict(carga_id=CARGA_CAMBIOS, tipo="alta", persona_id=149120, it=11, mes_vigencia=11,
             antes=None,
             despues={"cargo": "TERAPEUTA OCUPACIONAL", "area": "TO", "horas_semanales": 44,
                      "fecha_ingreso": "2026-11-02"}, detectado_en=det),
    ]


# --- Cuadratura ------------------------------------------------------------------------
def v_cuadratura():
    rng = random.Random(7)
    por_clave = {(f["persona_id"], f["mes"]): f for f in BASE}
    ed = [p["id"] for p in PROFESIONALES if p["area"] == "ED"]
    otros = [p["id"] for p in PROFESIONALES if p["area"] != "ED"]
    pool = ed + rng.sample(otros, 7)             # ~10 personas con diferencias
    usados = set()
    out = []

    def agregar(pid, campo, mes, sistema, dif, causa, dec=0):
        clave = (pid, campo, mes)
        if clave in usados:
            return False
        usados.add(clave)
        if dec:
            sistema = round(sistema, dec)
            excel = round(sistema - dif, dec)
            diferencia = round(sistema - excel, dec)
        else:
            excel = int(round(sistema - dif))
            diferencia = sistema - excel
        out.append(dict(persona_id=pid, campo=campo, mes=mes, excel=excel,
                        sistema=sistema, diferencia=diferencia, causa=causa))
        return True

    def con_fila(pid, mes):
        # busca un mes en el que la persona exista
        while (pid, mes) not in por_clave:
            mes = mes % 12 + 1
        return por_clave[(pid, mes)], mes

    def hacer(n, causa, generador):
        hechos = 0
        while hechos < n:
            if generador():
                hechos += 1

    def redondeo():
        pid = rng.choice(pool)
        campo = rng.choice(["meta", "meta_dir_ind", "plan_ate_dir"])
        f, mes = con_fila(pid, rng.randint(5, 12))
        s = {"meta": f["meta"], "plan_ate_dir": f["ate"],
             "meta_dir_ind": piso((f["ate"] + f["ate_ind"]) * META_PCT)}[campo]
        return agregar(pid, campo, mes, s, rng.choice([-1, 1]), "redondeo")

    def ene_abr():
        pid = rng.choice(pool)
        f, mes = con_fila(pid, rng.randint(1, 4))
        campo = rng.choice(["plan_ate_dir", "plan_ate_dir_ind"])
        s = f["ate"] if campo == "plan_ate_dir" else f["ate"] + f["ate_ind"]
        return agregar(pid, campo, mes, s, rng.choice([-1, 1]) * rng.randint(4, 12), "regla_ene_abr")

    def julio():
        pid = rng.choice(pool)
        f, mes = con_fila(pid, 7)
        return agregar(pid, "semhab", 7, f["sem_hab"], rng.choice([-0.1, -0.2]), "descuento_julio", 1)

    def asignacion():
        pid = rng.choice(pool)
        f, _ = con_fila(pid, 12)
        return agregar(pid, "pct_dir_final", None, f["pct_dir_final"],
                       rng.choice([-1, 1]) * round(rng.uniform(0.02, 0.05), 3), "asignacion_no_calza", 4)

    def grupal():
        pid = rng.choice(ed)
        f, _ = con_fila(pid, 12)
        return agregar(pid, "ate_dir_semana", None, f["ate_sem"], -rng.randint(2, 4), "atencion_grupal")

    def colacion():
        pid = rng.choice(pool)
        f, _ = con_fila(pid, 12)
        return agregar(pid, "ate_dir_semana", None, f["ate_sem"], rng.choice([-1, 1]), "colacion_contrato")

    hacer(8, "redondeo", redondeo)
    hacer(7, "regla_ene_abr", ene_abr)
    hacer(4, "descuento_julio", julio)
    hacer(4, "asignacion_no_calza", asignacion)
    hacer(4, "atencion_grupal", grupal)
    hacer(3, "colacion_contrato", colacion)
    assert len(out) == 30
    rng.shuffle(out)
    return out


# --- Parámetros vigentes ---------------------------------------------------------------
def v_parametros_vigentes():
    f1, f2 = "2026-01-01", "2026-05-01"
    g = "param.general"
    filas = [
        # Claves reales de param.general en la base de Andrés
        (g, "meta", "0.9", 1, f1),
        (g, "jornada_ene_abr", "44", 1, f1),
        (g, "jornada_may_dic", "42", 2, f2),
        (g, "pausa_pct_alta", "0.10", 1, f1),
        (g, "pausa_pct_baja", "0.06", 1, f1),
        (g, "colacion_h_dia", "0.25", 1, f1),
        (g, "tramo_limite_bajo", "22", 1, f1),
        (g, "tramo_limite_alto", "40", 1, f1),
        (g, "max_asignaciones", "2", 1, f1),
        (g, "horas_min_para_max", "30", 1, f1),
        (g, "min_indirecta", "30", 1, f1),
        (g, "dia_en_semanas", "0.2", 1, f1),
    ]
    for (cargo, tramo), (pd, pi, pn) in sorted(PARAM_CARGO.items()):
        filas.append(("param.cargo", f"{cargo}|tramo_{tramo}",
                      f"dir {pd:g} · ind {pi:g} · nas {pn:g} · {MIN_DIRECTA} min", 1, f1))
    for tipo, horas in [("Líder Equipo", "2"), ("Docencia DMN", "4"), ("Capacitación", "2"),
                        ("Coordinador Kinesiología", "6")]:
        filas.append(("param.asignacion", tipo, f"{horas} horas por semana", 1, f1))
    for mes, sem in SEMANAS.items():
        filas.append(("param.calendario", f"general|mes_{mes}", f"{sem:g} semanas", 1, f1))
    filas.append(("param.grupal", "ED|San-Con", "10 % grupal · 3 pacientes por grupo", 1, f1))
    filas.append(("param.grupal", "ED|otros", "10 % grupal · 1,5 pacientes por grupo", 1, f1))
    return [dict(tabla=t, clave=c, valor=v, version=ve, vigente_desde=d) for t, c, v, ve, d in filas]


# --- Cuadratura de totales y escenarios -----------------------------------------------
def impacto(antes, despues):
    out = []
    for it in INSTITUTOS:
        a = [f for f in antes if f["it"] == it]
        d = [f for f in despues if f["it"] == it]
        out.append(dict(it=it, instituto=INSTITUTOS[it],
                        atenciones_antes=sumar(a, "ate"), atenciones_despues=sumar(d, "ate"),
                        meta_antes=sumar(a, "meta"), meta_despues=sumar(d, "meta"),
                        diferencia_meta=sumar(d, "meta") - sumar(a, "meta")))
    return out


def escenarios():
    e1 = calcular(meta_pct=0.92)
    e2 = calcular(param_cargo={("EDUCADOR", 1): (0.60, 0.15, 0.25)})
    return [
        dict(escenario_id=1,
             descripcion="Subir la meta de gestión de 90 % a 92 % de las atenciones planificadas",
             parametro="param.general.meta_gestion", valor_actual="0.9", valor_propuesto="0.92",
             estado="pendiente", creado_por="planificador", creado_en="2026-11-03T16:40:00-03:00",
             decision_motivo=None, impacto=impacto(BASE, e1)),
        dict(escenario_id=2,
             descripcion="Educador tramo 1: bajar el % no asistencial de 30 % a 25 % y subir el % directo de 55 % a 60 %",
             parametro="param.cargo.EDUCADOR|tramo_1", valor_actual="dir 0.55 · ind 0.15 · nas 0.3",
             valor_propuesto="dir 0.6 · ind 0.15 · nas 0.25",
             estado="aprobado", creado_por="planificador", creado_en="2026-10-28T11:05:00-03:00",
             decision_motivo="Alineado con el plan de educación 2026", impacto=impacto(BASE, e2)),
    ]


def escribir(nombre, filas):
    cuerpo = ",\n".join("  " + json.dumps(f, ensure_ascii=False) for f in filas)
    (SALIDA / f"{nombre}.json").write_text(f"[\n{cuerpo}\n]\n", encoding="utf-8")


def main():
    vistas = {
        "v_kpi": v_kpi(), "v_nacional_mes": v_nacional_mes(),
        "v_instituto_area_mes": v_instituto_area_mes(), "v_profesional_mes": v_profesional_mes(),
        "v_cambios": v_cambios(), "v_errores_carga": v_errores_carga(),
        "v_parametros_vigentes": v_parametros_vigentes(), "v_cuadratura": v_cuadratura(),
    }
    for nombre, filas in vistas.items():
        escribir(nombre, filas)
        print(f"{nombre}.json: {len(filas)} filas")
    esc = escenarios()
    (SALIDA / "escenarios.json").write_text(
        json.dumps(esc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"escenarios.json: {len(esc)} escenarios")


if __name__ == "__main__":
    main()
