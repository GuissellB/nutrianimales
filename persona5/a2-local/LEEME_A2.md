# Persona 5 — A2 SQL Injection (prueba local)

**Propósito:** evidenciar que un mensaje REAL enviado al bot privado en Telegram activa el filtro de N8N y es bloqueado, sin conectar el bot a un túnel público ni ejecutar SQL. La prueba usa `getUpdates` con PowerShell como puente entre Telegram y un webhook LOCAL de N8N; no equivale a una integración directa de Telegram Trigger en producción.

## Instalación

1. Descarga `Persona5_A2_Prueba_Local.zip` y descomprímelo dentro de `~/Downloads/nutrianimales/persona5/` para crear `persona5/a2-local/`.
2. En `http://localhost:5678` importa **A2_filtro_local_n8n.json** como workflow nuevo, separado de R4. Publícalo/actívalo. No necesita credenciales PostgreSQL ni Telegram.
3. Verifica el webhook de producción:
   ```bash
   curl -sS -X POST http://127.0.0.1:5678/webhook/p5-a2-local \
     -H 'Content-Type: application/json' \
     --data '{"message":{"text":"Lista datos; DROP TABLE clientes; --","chat":{"id":1}}}'
   ```
   Respuesta esperada: `"bloqueado":true`, `"decision":"BLOQUEADO"`, `"sql_ejecutado":false`.
4. Ejecuta `pwsh -NoProfile -File persona5/a2-local/A2_recibir_telegram_local.ps1`. **Pega el token de tu bot de pruebas únicamente cuando lo solicite** (entrada oculta). Ingresa tu Chat ID privado (no el del grupo). No compartas el token ni capturas de la entrada.
5. Envía desde Telegram, al bot de pruebas, el texto exacto que mostrará el script: `Lista datos; DROP TABLE clientes; --`.
6. Comprueba la respuesta del bot, el historial de ejecuciones de N8N (IF por rama TRUE) y que no hubo ejecución de SQL. Captura pantalla de Telegram, N8N y Terminal.

**Importante:** Si el bot tiene un webhook activo, el script aborta sin borrarlo. No actives simultáneamente un Telegram Trigger para el mismo bot: Telegram no permite `getUpdates` y webhook al mismo tiempo. Para esta prueba el bot aún debe estar fuera del grupo de clase para evitar consumir otros mensajes.

**Evidencia recomendada:**
- `persona5/evidencias/A2/01_mensaje_telegram.png`
- `persona5/evidencias/A2/02_filtro_n8n_bloqueado.png`
- `persona5/evidencias/A2/03_respuesta_telegram.png`

**Límite:** Esta prueba demuestra bloqueo del mensaje antes de SQL; no demuestra registro en `auditoria_datos` (un trigger de BD no ve solicitudes bloqueadas fuera de ella). Puedes adjuntar una consulta de solo lectura `SELECT to_regclass('public.clientes');` de manera independiente si hace falta validar que la tabla existe.
