"""Contrastes de capas y de fidelidad de insumos contra el cuerpo de la tabla Excel."""
import unittest
import datetime
import math

import pandas as pd
import verificar_calculo as v


class CapasTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.df = v.leer_asistencial(v.ROOT / 'data/excel/Nac - Planificacion Asistencial x mes.xlsx')
        cls.params, cls.reglas, *_ = v.parametros(v.ROOT / 'data/csv', v.ROOT / 'tools/param_general_verificacion.csv')
        cls.resumen, cls.detalle = v.capas_asistencial(cls.df, cls.params, cls.reglas)

    def test_tabla_acotada_con_fila_fisica_sin_totales(self):
        self.assertEqual(len(self.df), 471)
        self.assertEqual((self.df.fila_excel.min(), self.df.fila_excel.max()), (5, 475))
        self.assertEqual(len(self.df[['persona_id', 'it']].drop_duplicates()), 469)

    def test_porcentaje_final_condicionado_y_plan_aislado(self):
        x = self.resumen.set_index(['capa', 'campo'])
        self.assertEqual(x.loc[('b_pct_nas_excel', 'pct_dir_final'), 'coinciden'], 456)
        self.assertEqual(x.loc[('c_aislada_semanal_grupal_excel', 'plan_ate_dir'), 'coinciden'], 471*8)
        self.assertEqual(x.loc[('c_aislada_semanal_grupal_excel', 'meta'), 'coinciden'], 3763)

    def test_separar_poblacion_activa_de_semanal_historico(self):
        x = self.resumen.set_index(['capa', 'campo'])
        self.assertEqual(x.loc[('b_pct_nas_excel_activas', 'ate_dir_semana'), 'referencias'], 447)
        self.assertEqual(x.loc[('b_pct_nas_excel_activas', 'ate_dir_semana'), 'coinciden'], 441)
        self.assertEqual(x.loc[('b_pct_nas_excel_todas', 'ate_dir_semana'), 'referencias'], 471)

    def test_claves_repetidas_no_se_colapsan(self):
        e = self.detalle[(self.detalle.capa == 'b_pct_nas_excel_todas') &
                         (self.detalle.campo == 'ate_dir_semana') & self.detalle.persona_id.eq(137356)]
        self.assertEqual(set(e.fila_excel), {59, 60})

    def test_insumos_csv_fiel_a_lectura_independiente(self):
        x = pd.read_csv(v.ROOT / 'data/csv/insumos.csv')
        fields = ['persona_id', 'it', 'cargo', 'area', 'horas_semana_dic', 'prom_pond_horas',
                  'dias_semana', 'colacion_contrato', 'horas_nas_total', 'horas_asignacion',
                  'asignacion_1', 'horas_asig_1', 'asignacion_2', 'horas_asig_2',
                  'pct_dir_base', 'pct_ind_base', 'pct_nas_base', 'min_directa', 'min_indirecta'] + [f'semhab_{m}' for m in range(1, 13)]
        self.assertEqual(list(x.columns), fields)
        self.assertEqual(x.shape, (471, 31))
        esperado = self.df[fields].reset_index(drop=True).copy()
        for campo in ['cargo', 'area', 'asignacion_1', 'asignacion_2']:
            esperado[campo] = esperado[campo].str.strip()
        pd.testing.assert_frame_equal(x, esperado, check_dtype=False, atol=1e-12, rtol=0)

    def test_directas_ax_es_diagnostico_sin_regresiones(self):
        detalle = self.detalle[self.detalle.campo.eq('ate_dir_semana')]
        base = detalle[detalle.capa.eq('b_pct_nas_excel_activas')].set_index('fila_excel')
        ax = detalle[detalle.capa.eq('b_diagnostico_disponible_ate_excel_activas')].set_index('fila_excel')
        self.assertEqual(len(base), 447)
        self.assertEqual(int(ax.coincide.sum()), 446)
        self.assertTrue(ax.loc[base[base.coincide].index, 'coincide'].all())
        self.assertEqual(int((ax.coincide & ~base.coincide).sum()), 5)
        # El diagnóstico no reemplaza el resultado normativo original.
        self.assertEqual(int(base.coincide.sum()), 441)

    def test_seis_residuos_trazables_sin_cruce_por_persona(self):
        x = v.discrepancias_directas_activas(self.df, self.detalle, self.params)
        self.assertEqual(list(x.fila_excel), [18, 115, 219, 383, 384, 464])
        self.assertEqual(list(x.referencia), [15, 16, 29, 30, 31, 33])
        self.assertEqual(list(x.calculado), [14, 17, 30, 29, 29, 32])
        self.assertEqual(list(x.diagnostico_ax), [14, 16, 29, 30, 31, 33])
        self.assertFalse(x.par_repetido.any())
        self.assertTrue(x.iloc[0].causa_demostrada.startswith('El objetivo semanal'))
        self.assertTrue(x.iloc[1:].causa_demostrada.str.startswith('Disponibilidades distintas').all())
        self.assertAlmostEqual(x.iloc[0].sin_floor_ax, 14.558823529411764)

    def test_repetidos_son_tramos_distintos_y_no_se_deduplican(self):
        for persona, corte in [(137356, '2026-07-01'), (72190, '2026-04-01')]:
            x = self.df[self.df.persona_id.eq(persona)].sort_values('vigencia_desde')
            self.assertEqual(len(x), 2)
            self.assertEqual(x.iloc[1].vigencia_desde, pd.Timestamp(corte))
            self.assertEqual(x.iloc[0].vigencia_hasta + pd.Timedelta(days=1), pd.Timestamp(corte))
        repetida = pd.concat([self.df, self.df.iloc[[0]]], ignore_index=True)
        with self.assertRaisesRegex(ValueError, 'identidad de fila'):
            v.capas_asistencial(repetida, self.params, self.reglas)


class DuracionExcelTests(unittest.TestCase):
    def test_conserva_horas_mayores_a_un_dia(self):
        self.assertEqual(v.horas_duracion_excel(datetime.timedelta(hours=25, minutes=30)), 25.5)
        self.assertEqual(v.horas_duracion_excel(datetime.time(16, 30)), 16.5)
        self.assertEqual(v.horas_duracion_excel(0.6875), 16.5)

    def test_no_inventa_cero_ni_acepta_formato_ambiguo(self):
        self.assertTrue(math.isnan(v.horas_duracion_excel(None)))
        with self.assertRaises(ValueError):
            v.horas_duracion_excel('16:30')
        with self.assertRaises(ValueError):
            v.horas_duracion_excel(float('inf'))


if __name__ == '__main__':
    unittest.main()
