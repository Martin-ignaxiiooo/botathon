"""Evita aprobar un contrato incompleto o firmas incompatibles."""
import unittest
from comprobar_catalogo import comprobar, tipos


class CatalogoTests(unittest.TestCase):
    def setUp(self):
        self.contrato = {'git_ref': 'ensayo', 'stg': {'carga': ['carga_id']},
                         'rpc': {'cargar_dotacion': {'firma_contrato': 'cargar_dotacion(carga_id bigint)'}},
                         'vistas': {'v_kpi': ['meta']}}
        self.catalogo = {'usuario': 'bot_carga',
                         'tablas_stg': [{'tabla': 'carga', 'columnas': [{'columna': 'carga_id', 'tipo': 'bigint'}], 'puede_insertar': True}],
                         'funciones_api': [{'funcion': 'cargar_dotacion', 'argumentos': 'p_carga_id bigint', 'puede_ejecutar': True}],
                         'vistas_api': [{'vista': 'v_kpi', 'columnas': ['meta'], 'lectura_web': True}]}

    def test_firma_posicional_ignora_nombre_no_tipo(self):
        self.assertEqual(tipos('p_carga_id bigint'), tipos('carga_id bigint'))
        self.assertTrue(comprobar(self.catalogo, self.contrato)['contrato_completo'])
        self.catalogo['funciones_api'][0]['argumentos'] = 'p_carga_id numeric'
        self.assertFalse(comprobar(self.catalogo, self.contrato)['contrato_completo'])

    def test_vista_ausente_no_es_aprobacion(self):
        self.catalogo['vistas_api'] = []
        r = comprobar(self.catalogo, self.contrato)
        self.assertFalse(r['contrato_completo'])
        self.assertEqual(r['vistas'][0]['faltantes'], ['meta'])

    def test_columnas_extra_o_sin_permiso_no_pasan(self):
        self.catalogo['tablas_stg'][0]['columnas'].append({'columna': 'ajena', 'tipo': 'text'})
        self.assertFalse(comprobar(self.catalogo, self.contrato)['contrato_completo'])
        self.catalogo['tablas_stg'][0]['columnas'].pop()
        self.catalogo['funciones_api'][0]['puede_ejecutar'] = False
        self.assertFalse(comprobar(self.catalogo, self.contrato)['contrato_completo'])
        self.catalogo['funciones_api'][0]['puede_ejecutar'] = True
        self.catalogo['vistas_api'][0]['lectura_web'] = False
        self.assertFalse(comprobar(self.catalogo, self.contrato)['contrato_completo'])


if __name__ == '__main__':
    unittest.main()
