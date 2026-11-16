# Estado de verificación — 16 de noviembre de 2026

Estado basado en evidencias históricas y pruebas locales del 16/11/2026. A1 y A2 se comprobaron nuevamente; A4 y A5 conservan sus validaciones anteriores. No se atribuyen estas pruebas a los workflows oficiales del equipo.

| Escenario | Evidencias preservadas | Limitaciones / siguiente acción |
|---|---|---|
| A1 / R4-SSH | 20 intentos SSH, logs y Telegram | VALIDADO el 16/11/2026 con detector R4-SSH personal. El R4 oficial de PostgreSQL es independiente. |
| A2 | Webhook HTTP local y respuesta JSON | FILTRO VALIDADO el 16/11/2026: decision BLOQUEADO. Integracion directa desde Telegram pendiente. |
| A3 / H1 | `evidencias/A3/PENDIENTE.md` | Pendiente prueba UFW real; en Mac solo emulación. |
| A4 / H3 | GRANT, REVOKE, Telegram | VALIDADO ANTERIORMENTE: alerta H3 recibida y privilegio INSERT revocado. Evidencia preservada. |
| A5 / D7 | SELECT masivo, Telegram | VALIDADO ANTERIORMENTE: D7 detecto 2.200 filas el 15/11/2026. Sin exfiltracion externa demostrada. |
| Rotación de Groq | Clave válida, revocada y nueva | Revisar capturas para excluir secretos antes de publicarlas. |

## Cambios de estructura

Se eliminaron duplicados de `.env.example`, `.gitignore`, H3/D7, antiguos overlays de Filebeat/Logstash, copias de R2/H4 y el sistema A2 con webhook HTTP paralelo. Permanecen los 5 scripts, las evidencias, los documentos y los adaptadores de laboratorio R4-SSH/H1-P5 porque todavía no existe una fuente equivalente para esas pruebas en los flujos oficiales. **No se modificaron** `main`, los workflows oficiales de `n8n/workflows/`, los certificados, la base ni los secretos.

No inventar resultados nuevos ni presentar la emulación A3 como cambio real del firewall.
