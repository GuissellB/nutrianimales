# Correcciones de integración — Persona 5

- Un solo `.env.example` y `.gitignore` en la raíz; sin secretos nuevos.
- Eliminadas las copias de H3 y D7: usar `n8n/workflows/H3_escalada_privilegios.json` y `n8n/workflows/D7_exfiltracion_masiva.json`.
- Eliminadas las copias auxiliares R2/H4 y el stack `legacy-observability`: utilizar la observabilidad del equipo.
- Eliminado el webhook A2 alternativo: integrar el snippet Code en el **Telegram Trigger existente**.
- Conservado el laboratorio SSH de A1 y su detector R4-SSH, que no equivale al R4 oficial de PostgreSQL.
- Conservado el laboratorio UFW de A3 y su detector H1-P5: en Mac solo emulación; H1 oficial vigila logs de tráfico, no cambios de reglas.
- Conservados scripts A1–A5, capturas originales, gestión de secretos e informe.

**Pendiente:** validar A2 con el bot real, A3 en una VM Linux si se exige evidencia real y A4/A5 con detectores centrales activos. No usar `docker compose down -v`.
