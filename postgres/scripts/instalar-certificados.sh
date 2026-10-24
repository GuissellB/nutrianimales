#!/bin/sh
set -eu

DESTINO="/tls"
ORIGEN="/certs"

if [ ! -f "$ORIGEN/server.crt" ] || [ ! -f "$ORIGEN/server.key" ]; then
    echo "ERROR: Faltan certificados TLS."
    exit 1
fi

mkdir -p "$DESTINO"

install -o postgres -g postgres -m 644 \
    "$ORIGEN/server.crt" "$DESTINO/server.crt"

install -o postgres -g postgres -m 600 \
    "$ORIGEN/server.key" "$DESTINO/server.key"

echo "Certificados TLS instalados correctamente."