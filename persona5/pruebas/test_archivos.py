"""Validaciones estáticas de Persona 5 (sin Docker ni red)."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
from datetime import datetime, timezone, timedelta

ROOT = Path(__file__).resolve().parent.parent


class TestFlujos(unittest.TestCase):
    def test_workflows(self):
        files = sorted((ROOT / 'n8n/workflows').glob('*.json'))
        self.assertEqual(len(files), 2)
        for f in files:
            with self.subTest(workflow=f.name):
                data = json.loads(f.read_text('utf-8'))
                nodes = data['nodes']
                names = {n['name'] for n in nodes}
                self.assertEqual(len(names), len(nodes))
                self.assertFalse(data['active'])
                self.assertTrue(nodes)
                for src, outputs in data['connections'].items():
                    self.assertIn(src, names)
                    for idx, edges in enumerate(outputs['main']):
                        for edge in edges:
                            self.assertIn(edge['node'], names)
                            self.assertEqual(edge['type'], 'main')
                for n in nodes:
                    self.assertNotIn('credentials', n)
                    if n['type'].endswith('.telegram'):
                        self.assertEqual(n['parameters']['chatId'], 'CONFIGURAR_CHAT_ID')

    def test_no_secret_literals(self):
        for p in (ROOT / 'n8n').rglob('*'):
            if p.is_file() and p.suffix in ('.json', '.js'):
                text = p.read_text('utf-8')
                import re
                self.assertIsNone(re.search(r'"chatId"\s*:\s*"-\d{6,}"', text))
                self.assertNotIn('\"credentials\": {', text)

    def test_flujos_oficiales(self):
        for n in ('H3_escalada_privilegios.json', 'D7_exfiltracion_masiva.json'):
            f = ROOT.parent / 'n8n' / 'workflows' / n
            self.assertTrue(f.is_file(), str(f))
            data = json.loads(f.read_text('utf-8'))
            self.assertTrue(any(x['type'].endswith('.postgres') for x in data['nodes']))
        self.assertFalse((ROOT / 'n8n/workflows/H3_grant_agente_ia.json').exists())
        self.assertFalse((ROOT / 'n8n/workflows/D7_select_masivo.json').exists())
        self.assertTrue((ROOT / 'n8n/snippets/filtro_sql_injection.js').exists())

    def test_required_files(self):
        for path in (
            'ataques/A1_fuerza_bruta.ps1', 'ataques/A2_sql_injection.ps1',
            'ataques/A3_apertura_puerto.ps1', 'ataques/A4_escalada_privilegios.ps1',
            'ataques/A5_exfiltracion.ps1', 'ataques/ejecutar-macos-linux.sh',
            'docker-compose.persona5.yml', 'lab/ssh/Dockerfile',
            'lab/eventos/servidor_eventos.py', 'docs/integracion_n8n.md'):
            self.assertTrue((ROOT / path).is_file(), path)


class TestMonitor(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = ROOT / 'lab/eventos/servidor_eventos.py'
        spec = importlib.util.spec_from_file_location('p5_events', path)
        cls.monitor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.monitor)

    def test_ssh_filtros_ventana(self):
        now = datetime.now(timezone.utc).replace(microsecond=0)
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'ssh.log'
            nuevo = now.strftime('%Y-%m-%dT%H:%M:%SZ')
            viejo = (now - timedelta(minutes=12)).strftime('%Y-%m-%dT%H:%M:%SZ')
            log.write_text(''.join(f'{nuevo} | Failed password for victima_lab\n' for _ in range(7)) +
                           f'{viejo} | Failed password for victima_lab\n' +
                           f'{nuevo} | Other event\n')
            original = self.monitor.RUTAS['ssh']
            try:
                self.monitor.RUTAS['ssh'] = (log, 'Failed password')
                obj = self.monitor.contar('ssh', 600, now)
                self.assertEqual(obj['total'], 7)
                self.assertEqual(obj['tipo'], 'ssh')
            finally:
                self.monitor.RUTAS['ssh'] = original

    def test_ufw_y_parametros(self):
        now = datetime.now(timezone.utc).replace(microsecond=0)
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / 'ufw.log'
            log.write_text(f'{now.strftime("%Y-%m-%dT%H:%M:%SZ")} | PERSONA5 UFW CHANGE ALLOW 5432/tcp | UFW_EMULADO\n')
            original = self.monitor.RUTAS['ufw']
            try:
                self.monitor.RUTAS['ufw'] = (log, 'PERSONA5 UFW CHANGE ALLOW 5432/tcp')
                self.assertEqual(self.monitor.contar('ufw', 300, now)['total'], 1)
            finally:
                self.monitor.RUTAS['ufw'] = original
        with self.assertRaises(ValueError):
            self.monitor.contar('desconocido', 300)
        with self.assertRaises(ValueError):
            self.monitor.contar('ssh', 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
