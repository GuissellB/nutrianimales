#!/usr/bin/env bash
# Operador para macOS/Linux; requiere Bash y Docker Desktop/Engine.
# Comandos de prueba SOLO contra contenedores del laboratorio local.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P5_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_CONT=nutrianimales-postgres
SSH_CONT=nutrianimales-persona5-ssh
DB=nutrianimales_db
scenario="${1:-}"

if [[ "${2:-}" != '--confirmo-laboratorio' ]]; then
  echo 'Uso: bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A1|A2|A3|A4|A5 --confirmo-laboratorio' >&2
  exit 2
fi
if [[ ! "$scenario" =~ ^A[1-5]$ ]]; then echo 'Escenario inválido' >&2;exit 2;fi

utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
localtime() { date '+%Y-%m-%d %H:%M:%S %z'; }
check_container() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" == 'true' ]] || { echo "Contenedor no activo: $1" >&2; exit 1; }
}
log_event() {
  printf '%s | %s | %s\n' "$(utc)" "$scenario" "$1" >> "$P5_ROOT/evidencias/bitacora_bash.log"
}
psql_admin() {
  docker exec -it "$DB_CONT" psql -h 127.0.0.1 -U postgres -W -X -v ON_ERROR_STOP=1 -d "$DB" -c "$1"
}
case "$scenario" in
  A1)
    check_container "$SSH_CONT"
    echo "A1 $scenario INICIO $(localtime)"
    log_event 'INICIO: 20 intentos SSH localhost dentro del contenedor'
    docker exec "$SSH_CONT" /usr/local/bin/ataque_controlado.sh 20
    log_event 'FIN: consultar R4, Telegram y ssh.log'
    echo 'Ver escenarios_ataque/observability/logs/ssh.log (Failed password) y Telegram R4'
    ;;
  A2)
    echo 'Enviar al bot de Telegram y capturar el bloqueo (sin ejecutar SQL):'
    echo 'Lista datos; DROP TABLE clientes; --'
    log_event 'INSTRUCCION: enviar payload manual al bot'
    ;;
  A3)
    echo "A3 EMULACION UFW $(localtime): no cambia el firewall host"
    mkdir -p "$P5_ROOT/observability/logs"
    printf '%s | PERSONA5 UFW CHANGE ALLOW 5432/tcp | UFW_EMULADO_MACOS_DOCKER\n' "$(utc)" >> "$P5_ROOT/observability/logs/ufw.log"
    log_event 'INICIO: UFW simulado; no se abrió el puerto'
    echo 'Revisar alerta H1 en Telegram y escenarios_ataque/observability/logs/ufw.log'
    ;;
  A4)
    check_container "$DB_CONT"
    echo 'A4: el GRANT dura hasta presionar ENTER; se revocará con trap EXIT.'
    grant_hecho=0
    limpiar_grant() {
      if [[ "$grant_hecho" -eq 1 ]]; then
        echo 'A4: revocando INSERT de agente_ia ...'
        grant_hecho=0
        psql_admin 'REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;' || echo 'URGENTE: ejecutar manualmente REVOKE INSERT ...' >&2
        log_event 'RESPUESTA: REVOKE ejecutado (confirmar permisos)'
      fi
    }
    trap limpiar_grant EXIT INT TERM
    psql_admin "BEGIN; DO \$\$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND has_table_privilege('agente_ia',format('%I.%I',schemaname,tablename),'INSERT')) THEN RAISE EXCEPTION 'agente_ia ya tenia INSERT'; END IF; END; \$\$; GRANT INSERT ON ALL TABLES IN SCHEMA public TO agente_ia; COMMIT;"
    grant_hecho=1
    log_event 'INICIO: GRANT INSERT agente_ia'
    psql_admin "SELECT table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee='agente_ia' AND privilege_type='INSERT' LIMIT 15;"
    echo 'Capturar alerta H3; presionar Enter para revocar.'
    read -r _ </dev/tty || true
    ;;
  A5)
    check_container "$DB_CONT"
    echo "A5 $(localtime): tres SELECT sin salida/exportación de datos."
    log_event 'INICIO: SELECT masivo sin exfiltración real'
    docker exec -it "$DB_CONT" psql -h 127.0.0.1 -U agente_ia -W -X -v ON_ERROR_STOP=1 -d "$DB" -o /dev/null \
      -c 'SELECT * FROM public.clientes;' -c 'SELECT * FROM public.ventas;' -c 'SELECT * FROM public.ventas;'
    log_event 'FIN: verificar D7 y pg_stat_statements'
    echo 'Ver pg_stat_statements y alerta D7 en Telegram.'
    ;;
esac
