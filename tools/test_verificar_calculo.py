"""Pruebas del verificador offline: python -m unittest discover -s tools -p test_*.py"""
import math
import tempfile
import unittest
from pathlib import Path

import pandas as pd
import verificar_calculo as v


class VerificadorTests(unittest.TestCase):
    def test_ejemplo_documentado_y_redondeo(self):
        p = dict(colacion_h_dia=.25, minutos_hora=60)
        regla = dict(pct_dir=.65, pct_ind=.15, pct_nas=.20, min_directa=40)
        pct, atenciones, _, _ = v.semanal(40, 40, regla, p, asignaciones=2)
        self.assertEqual(pct, .609375)
        self.assertEqual(atenciones, 36)
        self.assertEqual(v.abajo(36 * 4.2), 151)
        self.assertEqual(v.abajo(5 - 1e-10), 5)
        self.assertEqual(v.abajo(4.9), 4)

    def test_nas_imposible_no_se_convierte_a_cero(self):
        p = dict(colacion_h_dia=.25, minutos_hora=60)
        regla = dict(pct_dir=.65, pct_ind=.15, pct_nas=.20, min_directa=40)
        pct, _, _, _ = v.semanal(10, 100, regla, p)
        self.assertTrue(math.isnan(pct))

    def test_denominador_no_oculta_ausentes_ni_extras(self):
        ref = pd.DataFrame([dict(persona_id=1, it=11, campo='plan_ate_dir', mes=m, referencia=10) for m in [5, 6]])
        calc = pd.DataFrame([dict(persona_id=1, it=11, campo='plan_ate_dir', mes=m, calculado=10) for m in [5, 7]])
        resumen = v.resumir(v.comparar(ref, calc, 'ensayo')).iloc[0]
        self.assertEqual(resumen['esperados'], 2)
        self.assertEqual(resumen['comparables'], 1)
        self.assertEqual(resumen['extras_candidato'], 1)
        self.assertEqual(resumen['pct_coincidencia_comparables'], 100)
        self.assertEqual(resumen['pct_coincidencia_total'], 50)

    def test_conflicto_esperado_no_elije_un_resultado(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'esperado.csv'
            path.write_text('persona_id,it,campo,mes,valor\n1,11,pct_dir_final,,0.5\n1,11,pct_dir_final,,0.6\n', encoding='utf-8')
            datos, duplicadas, conflictos = v.leer_esperado(path)
            self.assertEqual((duplicadas, conflictos), (1, 1))
            self.assertTrue(pd.isna(datos.iloc[0]['valor']))

    def test_plan_alias_y_duplicados(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'plan.csv'
            path.write_text('persona_id,it,mes,atenciones_dir\n1,11,5,20\n', encoding='utf-8')
            self.assertEqual(v.leer_plan(path).iloc[0]['campo'], 'plan_ate_dir')
            path.write_text('persona_id,it,mes,plan_ate_dir\n1,11,5,20\n1,11,5,21\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'duplicadas'):
                v.leer_plan(path)

    def test_continuidad_no_rellena_estricto_ni_ignora_termino(self):
        params, reglas, cal, grupos, _ = v.parametros(v.ROOT / 'data/csv', Path(v.__file__).with_name('param_general_verificacion.csv'))
        buk = pd.DataFrame([dict(persona_id=1, it=11, mes=7, anio=2026, horas=40,
                                 periodo=pd.Timestamp('2026-07-01'), termino=pd.Timestamp('2026-08-15'),
                                 cargo='KINESIOLOGO', cod_esp='KI', ndias=5)])
        calc = v.calcular(buk, params, reglas, cal, grupos)
        estricto = calc[calc.modelo.eq('estricto')].set_index('mes')
        continuidad = calc[calc.modelo.eq('continuidad')].set_index('mes')
        self.assertTrue(pd.isna(estricto.loc[8, 'plan_ate_dir']))
        self.assertTrue(pd.notna(continuidad.loc[8, 'plan_ate_dir']))
        self.assertTrue(pd.isna(continuidad.loc[9, 'plan_ate_dir']))
        self.assertEqual(continuidad.loc[8, 'origen'], 'proyectado')

    def test_factor_grupal_es_hipotesis_separada(self):
        p, _, _, g, _ = v.parametros(v.ROOT / 'data/csv', Path(v.__file__).with_name('param_general_verificacion.csv'))
        self.assertEqual(v.factor_grupal('UEDA', 131, g, p), 3.75)
        self.assertEqual(v.factor_grupal('KI', 131, g, p), 1)


if __name__ == '__main__':
    unittest.main()
