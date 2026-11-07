r"""Casos BUK reproducibles. Uso: python data\generar_casos.py

Requiere Python 3 y openpyxl (python -m pip install openpyxl).
Solo lee Dotacion_2026 para elegir casos; conserva las demás hojas al guardar.
Las constantes son entradas de prueba solicitadas, no reglas del motor SQL.
"""
import csv
import hashlib
from collections import Counter, defaultdict
from copy import copy
from datetime import datetime, timedelta
from pathlib import Path
import shutil
import openpyxl

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data' / 'excel' / 'Nac - Base contratos x mes.xlsx'
OUT = ROOT / 'data' / 'buk'
SHEET = 'Dotacion_2026'


def records(ws, cols):
    result = []
    for row in ws.iter_rows(min_row=3):
        values = tuple(c.value for c in row)
        pid, period = values[cols['PersonaId']], values[cols['Periodo']]
        if isinstance(pid, (int, float)) and isinstance(period, datetime):
            result.append((row[0].row, int(pid), period.month, values))
    return result


def write_csv(name, fields, rows):
    with (OUT / name).open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    with (OUT / name).open(encoding='utf-8', newline='') as f:
        assert list(csv.DictReader(f)) == [{k: str(v) for k, v in r.items()} for r in rows]


def matriz(ws):
    # openpyxl reabre las celdas de texto vacío como None; ambas son celdas vacías.
    return [tuple(None if c.value == '' else c.value for c in r) for r in ws]


def normalizar(filas):
    return [tuple(None if v == '' else v for v in r) for r in filas]


def generar_errores(cols, groups, eligible):
    ingreso = next(k for k in cols if k.startswith('Fecha Ingreso'))
    termino = next(k for k in cols if k.startswith('Fecha T'))
    wb = openpyxl.load_workbook(SOURCE)
    ws = wb[SHEET]
    error_rows = [groups[p][0] for p in eligible[:5]]
    expectations = []
    mutations = [('Horas Semanales', 0, 'horas_semanales', 'Horas semanales debe ser mayor que cero'),
                 (termino, None, 'fecha_termino', 'Fecha término anterior a fecha ingreso'),
                 ('Cargo', 'CARGO INEXISTENTE', 'cargo', 'Cargo sin homologar'),
                 (None, None, 'persona_id', 'Fila duplicada (persona_id, it, periodo)'),
                 ('Horas Semanales', 'cuarenta', 'horas_semanales', 'Horas semanales debe ser numérico')]
    expected_error_sheet = [tuple(c.value for c in row) for row in ws]
    for (rowno, pid, _, values), (column, value, field, reason) in zip(error_rows, mutations):
        if column == termino:
            value = values[cols[ingreso]] - timedelta(days=1)
        if column is None:
            ws.append(values)
            expected_error_sheet.append(values)
            for source, dest in zip(ws[rowno], ws[ws.max_row]):
                dest._style = copy(source._style)
        else:
            ws.cell(rowno, cols[column] + 1, value)
            vals = list(expected_error_sheet[rowno - 1]); vals[cols[column]] = value
            expected_error_sheet[rowno - 1] = tuple(vals)
        expectations.append(dict(persona_id=pid, campo=field, motivo=reason))
    wb.save(OUT / '03_errores.xlsx')
    wb.close()
    check = openpyxl.load_workbook(OUT / '03_errores.xlsx')
    assert matriz(check[SHEET]) == normalizar(expected_error_sheet)
    error_data = records(check[SHEET], cols)
    keys = Counter((p, v[cols['IT']], m) for _, p, m, v in error_data)
    dup = error_rows[3]
    assert keys[(dup[1], dup[3][cols['IT']], dup[2])] == 2
    assert check[SHEET].cell(error_rows[0][0], cols['Horas Semanales'] + 1).value == 0
    assert check[SHEET].cell(error_rows[1][0], cols[termino] + 1).value < error_rows[1][3][cols[ingreso]]
    assert check[SHEET].cell(error_rows[2][0], cols['Cargo'] + 1).value == 'CARGO INEXISTENTE'
    assert check[SHEET].cell(error_rows[4][0], cols['Horas Semanales'] + 1).value == 'cuarenta'
    check.close()
    write_csv('esperado_errores.csv', ['persona_id', 'campo', 'motivo'], expectations)
    print('Personas de errores:', [r[1] for r in error_rows])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.load_workbook(SOURCE)
    ws = wb[SHEET]
    cols = {c.value: c.column - 1 for c in ws[2] if c.value is not None}
    ingreso = next(k for k in cols if k.startswith('Fecha Ingreso'))
    termino = next(k for k in cols if k.startswith('Fecha T'))
    rows = records(ws, cols)
    groups = defaultdict(list)
    for row in rows:
        groups[row[1]].append(row)
    shutil.copyfile(SOURCE, OUT / '01_original.xlsx')
    assert SOURCE.read_bytes() == (OUT / '01_original.xlsx').read_bytes()
    original = openpyxl.load_workbook(OUT / '01_original.xlsx', read_only=True)
    assert all(c.value is None for c in next(original[SHEET].iter_rows()))
    assert [c.value for c in original[SHEET][2]] == [c.value for c in ws[2]]
    original.close()
    disponibles = sorted(p for p, rs in groups.items() if rs)
    generar_errores(cols, groups, disponibles)
    # Una sola fila por mes e IT estable evita introducir cambios extra.
    eligible = sorted(p for p, rs in groups.items()
                      if len(rs) == 12 and {r[2] for r in rs} == set(range(1, 13))
                      and len({r[3][cols['IT']] for r in rs}) == 1
                      and len({r[3][cols['Cargo']] for r in rs}) == 1)
    if len(eligible) < 5:
        wb.close()
        raise ValueError('Fuente sin cinco personas con 12 meses. Original y errores generados/verificados; 02_cambios y esperado_cambios pendientes de base anual. No se inventaron meses.')
    used = set()

    def choose(predicate):
        for pid in eligible:
            if pid not in used and all(predicate(r[3]) for r in groups[pid]):
                used.add(pid)
                return pid
        raise ValueError('No hay cinco personas elegibles con 12 meses para los casos requeridos.')

    jornada = choose(lambda v: v[cols['Horas Semanales']] == 40)
    baja = choose(lambda v: True)
    donor = choose(lambda v: v[cols['IT']] == 131 and str(v[cols['Cargo']]).upper() == 'KINESIOLOGO')
    cargo = choose(lambda v: True)
    traslado = choose(lambda v: True)
    assert 999001 not in groups
    alternate_cargo = next(v[cols['Cargo']] for _, _, _, v in rows
                           if v[cols['Cargo']] != groups[cargo][0][3][cols['Cargo']])
    target_it, target_name = next((v[cols['IT']], v[cols['Instituto']]) for _, _, _, v in rows
                                if v[cols['IT']] != groups[traslado][0][3][cols['IT']])
    shutil.copyfile(SOURCE, OUT / '01_original.xlsx')
    assert hashlib.sha256(SOURCE.read_bytes()).digest() == hashlib.sha256((OUT / '01_original.xlsx').read_bytes()).digest()
    expected_changes = []
    for kind, pid, month in [('cambio_jornada', jornada, 6), ('baja', baja, 8),
                             ('alta', 999001, 7), ('cambio_cargo', cargo, 9), ('cambio_it', traslado, 10)]:
        it = 131 if kind == 'alta' else target_it if kind == 'cambio_it' else groups[pid][0][3][cols['IT']]
        expected_changes.append(dict(tipo=kind, persona_id=pid, it=it, mes_vigencia=month))

    # Contraste completo de valores tras guardar/reabrir; mantiene filas vacías y encabezados.
    expected_sheet = [tuple(c.value for c in row) for row in ws]
    deleted = []
    for rowno, pid, month, values in rows:
        changes = {}
        if pid == jornada and month >= 6:
            changes['Horas Semanales'] = 44
        if pid == cargo and month >= 9:
            changes['Cargo'] = alternate_cargo
        if pid == traslado and month >= 10:
            changes.update(IT=target_it, Instituto=target_name)
        for key, value in changes.items():
            ws.cell(rowno, cols[key] + 1, value)
            vals = list(expected_sheet[rowno - 1]); vals[cols[key]] = value
            expected_sheet[rowno - 1] = tuple(vals)
        if pid == baja and month >= 8:
            deleted.append(rowno)
    # Agregar alta antes de eliminar para no desplazar las filas del donante.
    for rowno, _, month, values in groups[donor]:
        if month < 7:
            continue
        vals = list(values)
        vals[cols['PersonaId']] = 999001
        vals[cols[ingreso]] = datetime(2026, 7, 1)
        vals[cols[termino]] = None
        ws.append(vals)
        expected_sheet.append(tuple(vals))
        for source, dest in zip(ws[rowno], ws[ws.max_row]):
            dest._style = copy(source._style)
    for rowno in sorted(deleted, reverse=True):
        ws.delete_rows(rowno)
        del expected_sheet[rowno - 1]
    wb.save(OUT / '02_cambios.xlsx')
    wb.close()
    with_check = openpyxl.load_workbook(OUT / '02_cambios.xlsx')
    assert matriz(with_check[SHEET]) == normalizar(expected_sheet)
    actual = records(with_check[SHEET], cols)
    for pid, cutoff, column, value in [(jornada, 6, 'Horas Semanales', 44), (cargo, 9, 'Cargo', alternate_cargo),
                                        (traslado, 10, 'IT', target_it), (traslado, 10, 'Instituto', target_name)]:
        for _, _, month, values in (r for r in actual if r[1] == pid):
            original = next(r[3] for r in groups[pid] if r[2] == month)
            assert values[cols[column]] == (value if month >= cutoff else original[cols[column]])
    assert {r[2] for r in actual if r[1] == baja} == set(range(1, 8))
    assert {r[2] for r in actual if r[1] == 999001} == set(range(7, 13))
    with_check.close()

    # Abrir también la copia original y contrastar cabecera y primera fila vacía.
    for name in ['01_original.xlsx', '02_cambios.xlsx', '03_errores.xlsx']:
        check = openpyxl.load_workbook(OUT / name, read_only=True)
        assert all(c.value is None for c in next(check[SHEET].iter_rows()))
        assert [c.value for c in check[SHEET][2]] == [c.value for c in ws[2]]
        check.close()
    write_csv('esperado_cambios.csv', ['tipo', 'persona_id', 'it', 'mes_vigencia'], expected_changes)
    print('Personas elegidas (12 meses):', dict(jornada=jornada, baja=baja, donante_alta=donor, cargo=cargo, traslado=traslado))
    print('Alta: 999001')
    print('Verificado: copia idéntica, cortes mensuales, valores completos reabiertos y CSV (5 cambios / 5 errores).')
    print('cambio_it publica IT destino; confirmar convención y textos de motivos con Andrés/Lucas en integración.')


if __name__ == '__main__':
    main()
