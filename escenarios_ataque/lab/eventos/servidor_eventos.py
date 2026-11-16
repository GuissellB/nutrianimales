"""API interna de solo lectura para dos fuentes de eventos de laboratorio.

Sin dependencias de terceros. No expone puerto al host: Docker bridge únicamente.
No evalúa comandos ni acepta rutas por parámetro.
"""
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
import json

RUTAS = {
    "ssh": (Path('/data/logs/ssh.log'), 'Failed password'),
    "ufw": (Path('/data/logs/ufw.log'), 'PERSONA5 UFW CHANGE ALLOW 5432/tcp'),
}


def contar(tipo: str, ventana: int, now=None) -> dict:
    if tipo not in RUTAS:
        raise ValueError('tipo invalido')
    if not 1 <= ventana <= 3600:
        raise ValueError('ventana debe estar entre 1 y 3600 segundos')
    now = now or datetime.now(timezone.utc)
    ruta, patron = RUTAS[tipo]
    cantidad = 0
    ultima = None
    if ruta.is_file():
        # Último MB: limita consumo y evita cargar logs grandes en memoria.
        with ruta.open('rb') as archivo:
            archivo.seek(0, 2)
            size = archivo.tell()
            archivo.seek(max(0, size - 1048576))
            chunk = archivo.read().decode('utf-8', errors='replace')
        if size > 1048576:
            chunk = '\n'.join(chunk.splitlines()[1:])
        for linea in chunk.splitlines():
            if patron not in linea:
                continue
            try:
                instante = datetime.strptime(linea[:20], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            if now - timedelta(seconds=ventana) <= instante <= now + timedelta(seconds=5):
                cantidad += 1
                if ultima is None or instante > ultima:
                    ultima = instante
    return {
        'tipo': tipo, 'total': cantidad, 'ventana_segundos': ventana,
        'ultimo_evento_utc': ultima.isoformat().replace('+00:00', 'Z') if ultima else None,
        'fuente': 'sshd real en contenedor aislado' if tipo == 'ssh' else 'evento UFW de prueba (emulado salvo modo LinuxReal)',
        'consulta_utc': now.isoformat().replace('+00:00', 'Z'),
    }


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = urlsplit(self.path)
        if parts.path == '/health':
            self.responder(200, {'estado': 'ok'})
            return
        if parts.path != '/resumen':
            self.responder(404, {'error': 'no encontrado'})
            return
        query = parse_qs(parts.query)
        try:
            tipo = query.get('tipo', [''])[0]
            ventana = int(query.get('ventana', ['600'])[0])
            self.responder(200, contar(tipo, ventana))
        except (ValueError, TypeError) as exc:
            self.responder(400, {'error': str(exc)})

    def responder(self, status, obj):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0', 8765), Handler).serve_forever()
