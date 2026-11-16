# Registro de correcciones — Persona 5

| Área | Corrección incluida | Estado |
|---|---|---|
| A1 | Fuerza bruta contra **SSH verdadero**, no PostgreSQL, acotado a `127.0.0.1:2222` dentro de un contenedor | Script + imagen + R4, pendiente prueba en Docker |
| A2 | Código de filtro conserva el mensaje original; IF conectado a rama de bloqueo, Postgres parametrizado y mensaje fijo; no nuevo trigger de bot | Subflujo importable, **debe insertarse en bot del equipo** |
| A3 | Emulación honesta para macOS/Windows, opción UFW real Linux con restauración; H1 detecta el evento generado | Script + monitor + flujo, pendiente prueba |
| A4 | GRANT válido `IN SCHEMA public`, verificación de baseline y REVOKE en finally/trap | Scripts + H3, pendiente prueba |
| A5 | SELECT sin extraer datos; sondeo de deltas por usuario en `pg_stat_statements` (baseline) | Scripts + D7, pendiente prueba |
| Integración | `docker-compose.persona5.yml` aislado, sin depender del inexistente `docker-compose.n8n.yml` | Overlay preparado; coordinar con Persona 3 |
| N8N | Nuevos R4-SSH, H1, H3, D7; sin IDs ni credenciales reales en JSON | Archivos de importación, pendiente credenciales |
| Evidencias | Estructura 4 evidencias/escenario y reporte con campos vacíos | Listo para capturas reales |
| Compatibilidad | Se preservaron R2/H4 y los antiguos overlays Loki/Filebeat en carpetas auxiliares | Referencias, no desplegar por defecto |
| Multiplataforma | PowerShell 7 y Bash macOS/Linux para A1–A5 | Revisión estática, pendiente prueba en máquina local |

**Depende de compañeros:** el bot Telegram y la instancia n8n no estaban en el repositorio público consultado. La carpeta no cambia sus workflows ni credenciales automáticamente.

**Limitación de monitoreo:** la API de eventos de Persona 5 es un demostrador con sondeo de archivos; no observa cambios ajenos al ejecutor A3, ni sustituye Filebeat/Loki/servicios de auditoría de producción.
