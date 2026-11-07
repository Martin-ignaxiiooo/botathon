"""Contrastes de capas y de fidelidad de insumos contra el cuerpo de la tabla Excel."""
import unittest

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


if __name__ == '__main__':
    unittest.main()
