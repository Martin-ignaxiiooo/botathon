"""Regresión del esperado confirmado: impactos exactos, sin ignorar otras diferencias."""
import contextlib
import csv
from decimal import Decimal
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

RAIZ = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('comparar_e2e', RAIZ/'tools/vm/comparar_e2e.py')
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)


class ImpactoAnual(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.ruta = Path(self.tmp.name)
        self.antes, self.despues = {}, {}
        with (RAIZ/'tests/e2e/esperado_impacto_anual.csv').open(newline='', encoding='utf-8') as f:
            for r in csv.DictReader(f):
                k = (int(r['persona_id']), int(r['it']), int(r['mes']))
                self.antes.setdefault(k, {})[r['campo']] = Decimal(r['antes'])
                self.despues.setdefault(k, {})[r['campo']] = Decimal(r['despues'])
        self.persona, self.it, _ = next(iter(self.antes))
        for mes in (1, 2):
            self.antes[(self.persona,self.it,mes)] = {'ate_dir': 100}
            self.despues[(self.persona,self.it,mes)] = {'ate_dir': 100}
        self.esperados = self.ruta/'csv'; self.esperados.mkdir()
        (self.esperados/'esperado_cambios.csv').write_text(
            f'tipo,persona_id,it,mes_vigencia\ncambio_jornada,{self.persona},{self.it},5\n')
        (self.esperados/'esperado_errores.csv').write_text('persona_id,campo,motivo\n')
        self.guardar('cambios.json',[dict(tipo='cambio_jornada',persona_id=self.persona,it=self.it,mes_vigencia=5)])
        self.guardar('errores.json',[])
        self.guardar('02/resumen.json',dict(mes_minimo=3))
        for caso, n, v, e in [('01',3123,3123,0),('03',3124,3119,5)]:
            self.guardar(caso+'/resumen.json',dict(conteos=dict(leidas=n,validas=v,con_error=e)))
        self.guardar('duplicado/resumen.json',dict(duplicado=True,estado='archivo repetido'))
        self.guardar('sin_cambios/resumen.json',dict(duplicado=False,mes_minimo=None))

    def guardar(self, nombre, valor):
        p = self.ruta/nombre; p.parent.mkdir(parents=True,exist_ok=True)
        p.write_text(json.dumps(valor),encoding='utf-8')

    def ejecutar(self):
        # Serializar números Decimal sin convertirlos a float ni perder precisión.
        for archivo, datos in [('antes.json',self.antes),('despues.json',self.despues),('reinicio_01.json',self.antes)]:
            registros=[]
            for (persona,it,mes),fila in datos.items():
                campos=','.join(json.dumps(k)+':'+str(v) for k,v in fila.items())
                registros.append(f'{{"persona_id":{persona},"it":{it},"mes":{mes},"fila":{{{campos}}}}}')
            (self.ruta/archivo).write_text('['+','.join(registros)+']',encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()):
            ok = modulo.comparar(self.ruta,self.esperados)
        self.resultados={r['caso']:r['estado'] for r in json.loads((self.ruta/'resultados.json').read_text(encoding='utf-8'))}
        return ok

    def test_impactos_confirmados_son_exactos(self):
        self.assertTrue(self.ejecutar())

    def test_no_exime_otros_valores_de_la_misma_persona(self):
        self.despues[(self.persona,self.it,3)]['ate_dir'] += 1
        self.assertFalse(self.ejecutar())
        self.assertEqual(self.resultados['02_impacto_anual'],'FALLA')

    def test_exige_cada_impacto_esperado(self):
        k=(self.persona,self.it,4)
        self.despues[k]['ate_dir']=self.antes[k]['ate_dir']
        self.assertFalse(self.ejecutar())
        self.assertEqual(self.resultados['02_impacto_anual'],'FALLA')

    def test_nunca_permite_cambiar_antes_del_corte_global(self):
        self.despues[(self.persona,self.it,1)]['ate_dir'] += 1
        self.assertFalse(self.ejecutar())
        self.assertEqual(self.resultados['02_corte_global'],'FALLA')


if __name__ == '__main__':
    unittest.main()
