# Estado de verificación del proyecto — 15 de noviembre de 2026

| Elemento | Evidencia entregada | Estado |
|---|---|---|
| A1/R4-SSH | Terminal, n8n, Telegram | Detectado |
| A2 | Webhook HTTP n8n y bloqueo JSON | Parcial: falta entrada Telegram |
| A3/H1 | No se agrega evidencia ficticia | Pendiente Linux / UFW real |
| A4/H3 | GRANT, REVOKE, Telegram | Detectado y revertido |
| A5/D7 | Terminal, Telegram (2.200 filas acumuladas) | Detectado; no hubo salida de datos |
| 6.1 Groq | Clave válida, 401, nueva clave | Verificado con Header Auth en n8n |
| 6.2 | ls -l de .env y RBAC | chmod 600 verificado |
| 6.3 | check-ignore y git ls-files | Excluidos y no rastreados |
| 12 medidas hardening | Implementación visible en repo; capturas de otros integrantes no todas disponibles | Por consolidar |
| 17 flujos | Catálogo y ramas del equipo, no todas las ejecuciones disponibles | Por consolidar |

**Trazabilidad:** capturas de A1/A2/A4/A5 extraídas del Word suministrado por Persona 5; capturas Groq suministradas directamente. **El repositorio `main` no contiene necesariamente todas las ramas integradas.**

**Seguridad:** nunca subir `.env`, `.secrets/`, claves privadas, tokens o credenciales exportadas. Los JSON de Persona 5 se distribuyen sin credenciales. Un `docker compose restart` sin recreación no carga automáticamente variables de entorno cambiadas en Compose.
