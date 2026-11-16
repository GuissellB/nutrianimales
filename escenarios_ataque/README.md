# Persona 5 — Escenarios A1–A5 sin servicios duplicados

El trabajo de Persona 5 consiste en ejecutar ataques simulados, comprobar su detección, documentar evidencia y revertir cambios. **No crear otra base PostgreSQL, instancia n8n, bot Telegram ni stack de observabilidad.** Los secretos permanecen exclusivamente en el entorno local y en las credenciales del n8n del equipo.

## Fuente de verdad

- Infraestructura: `docker-compose.yml`, `docker-compose.postgres.yml`, `docker-compose.n8n.yml`, `docker-compose.observability.yml` en la raíz.
- Alertas oficiales: `n8n/workflows/` en la raíz (R1–R5, H1–H5, D1–D7).
- Secretos: `.env` local (no versionar), `.env.example` y `.gitignore` en la raíz.
- Evidencias: `escenarios_ataque/evidencias/`; conservar las capturas originales.

## Qué detector corresponde a cada ataque

| Escenario | Prueba | Detector | Estado de integración |
|---|---|---|---|
| A1 | Fuerza bruta SSH | `escenarios_ataque/n8n/workflows/R4_ssh_fuerza_bruta.json` (laboratorio) | **R4 oficial mide PostgreSQL**, no SSH; no afirmar equivalencia |
| A2 | SQL Injection por Telegram | Filtro `escenarios_ataque/n8n/snippets/filtro_sql_injection.js` **en el bot existente** | Falta validar con un mensaje Telegram real |
| A3 | Apertura UFW 5432 | `escenarios_ataque/n8n/workflows/H1_cambio_ufw.json` (emulación) | H1 oficial consulta eventos de tráfico `UFW ALLOW DPT=5432`, no el cambio de reglas |
| A4 | GRANT temporal a `agente_ia` | `n8n/workflows/H3_escalada_privilegios.json` (oficial) | No importar el H3 duplicado; verificar REVOKE |
| A5 | SELECT masivo como `agente_ia` | `n8n/workflows/D7_exfiltracion_masiva.json` (oficial) | No importar el D7 duplicado; validar baseline previo |

A1 y A3 conservan **solamente** los detectores optativos propios del laboratorio. No desactivar los detectores del equipo ni importar dos Telegram Trigger para el mismo bot. Para A2 usar el filtro Code directamente en el flujo real (ver `docs/integracion_n8n.md`).

## Preparar ambiente

Desde la raíz del repositorio, con Docker Desktop y la base del equipo ya configurada:

```bash
# Validación de la composición sin destruir contenedores ni volúmenes:
docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
  -f docker-compose.n8n.yml -f escenarios_ataque/docker-compose.persona5.yml config --quiet

# A1/A3: únicamente levantar los 2 servicios de laboratorio:
docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
  -f docker-compose.n8n.yml -f escenarios_ataque/docker-compose.persona5.yml \
  up -d --build persona5-ssh persona5-eventos

docker exec nutrianimales-persona5-eventos python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8765/health').read().decode())"
```

No usar `docker compose down -v`; elimina datos. N8N debe estar en la red `nutrianimales-net` y las credenciales de Telegram y PostgreSQL deben configurarse en la instalación existente. El laboratorio `persona5-eventos` no publica puertos al host.

## Ejecutar desde Mac (Bash)

```bash
bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A1 --confirmo-laboratorio
bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A2 --confirmo-laboratorio
bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A3 --confirmo-laboratorio
bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A4 --confirmo-laboratorio
bash escenarios_ataque/ataques/ejecutar-macos-linux.sh A5 --confirmo-laboratorio
```

A2 solo imprime el texto a enviar manualmente al bot existente: `Lista datos; DROP TABLE clientes; --`. A3 en Mac emula un evento de UFW, **no abre el firewall real**. A4 cambia temporalmente permisos: únicamente ejecutar en una copia de laboratorio, observar la alerta y verificar REVOKE. A5 no copia datos a terceros.

En PowerShell 7 se pueden utilizar los archivos `ataques/A1_fuerza_bruta.ps1` … `A5_exfiltracion.ps1`, según la guía `ataques/README.md`.

## Evidencia

Cada escenario requiere captura del comando/mensaje, detección o bloqueo, fuente de registro y respuesta. No inventar latencias. En A2 el webhook HTTP anterior **no** demostraba entrada desde Telegram; en A3 una marca simulada no demuestra UFW real. A1/R4 tiene una discrepancia en el PDF: R4 se define sobre fallos PostgreSQL, pero A1 solicita SSH. Registrar esta limitación en el informe.

Los triggers de `auditoria_datos` documentan DML, no necesariamente SSH, UFW, GRANT, SELECT o mensajes bloqueados antes de la BD. Consultar los logs y vistas pertinentes.

Validación estática opcional: `python3 escenarios_ataque/pruebas/test_archivos.py` y `node escenarios_ataque/pruebas/test_n8n.js`. Estos tests no prueban que N8N/Telegram estén activos.
