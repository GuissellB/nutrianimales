#!/bin/sh
set -eu
# Servidor SSH aislado: escucha solo 127.0.0.1 DENTRO del contenedor.
# No se publica el puerto. La clave del usuario de laboratorio se genera al inicio.
ssh-keygen -A >/dev/null 2>&1
if ! id victima_lab >/dev/null 2>&1; then
  adduser -D -s /bin/sh victima_lab
fi
password="$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
printf 'victima_lab:%s\n' "$password" | chpasswd
unset password
mkdir -p /var/log/persona5
: >> /var/log/persona5/ssh.log
chmod 644 /var/log/persona5/ssh.log
# Anteponer fecha UTC a los mensajes reales de sshd para que el monitor pueda
# filtrar por ventana de 10 minutos sin depender del reloj del host.
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config 2>&1 | while IFS= read -r line; do
  printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$line" >> /var/log/persona5/ssh.log
  printf '%s\n' "$line"
done
