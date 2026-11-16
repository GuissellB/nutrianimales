#!/bin/sh
set -eu
# Prueba acotada SOLO contra sshd en 127.0.0.1:2222 de este contenedor.
# No acepta host, puerto ni usuario de destino externos.
attempts="${1:-20}"
case "$attempts" in ''|*[!0-9]*) echo 'Numero de intentos no valido' >&2; exit 2;; esac
if [ "$attempts" -lt 1 ] || [ "$attempts" -gt 20 ]; then
  echo 'Se permiten 1 a 20 intentos en el laboratorio.' >&2; exit 2
fi
i=1
while [ "$i" -le "$attempts" ]; do
  sshpass -p 'contrasena_incorrecta_persona5' ssh \
    -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=3 -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 \
    -o LogLevel=QUIET victima_lab@127.0.0.1 true >/dev/null 2>&1 && {
       echo 'ADVERTENCIA: inicio de sesion inesperado' >&2; exit 3;
    }
  printf 'Intento SSH fallido %s/%s\n' "$i" "$attempts"
  i=$((i+1))
  sleep 0.2
done
