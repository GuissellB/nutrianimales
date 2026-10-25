#!/bin/sh
set -eu

DESTINO=/tls
ORIGEN=/certs
# El cliente comprueba fechas, confianza y hostname con verify-full.
if [ ! -s "$ORIGEN/server.crt" ] || [ ! -s "$ORIGEN/server.key" ]; then
    echo 'ERROR: Faltan certificados TLS o estan vacios.' >&2
    exit 1
fi
# PostgreSQL valida la carga y correspondencia del par al iniciar.
install -d -o postgres -g postgres -m 700 "$DESTINO"
cert_tmp=$(mktemp "$DESTINO/.crt-XXXXXX")
key_tmp=$(mktemp "$DESTINO/.key-XXXXXX")
trap 'rm -f "$cert_tmp" "$key_tmp"' EXIT
install -o postgres -g postgres -m 644 "$ORIGEN/server.crt" "$cert_tmp"
install -o postgres -g postgres -m 600 "$ORIGEN/server.key" "$key_tmp"
mv -f "$cert_tmp" "$DESTINO/server.crt"
mv -f "$key_tmp" "$DESTINO/server.key"
echo 'Certificados TLS instalados correctamente.'
