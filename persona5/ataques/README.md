# Scripts A1–A5

**Guía completa:** [`../README.md`](../README.md). Ejecutar desde la raíz del repositorio NutriAnimales, nunca desde esta carpeta si se usan rutas relativas de Docker Compose.

Los scripts PowerShell 7 son `A1_fuerza_bruta.ps1`, `A2_sql_injection.ps1`, `A3_apertura_puerto.ps1`, `A4_escalada_privilegios.ps1` y `A5_exfiltracion.ps1`. Para macOS/Linux sin PowerShell, utilizar `ejecutar-macos-linux.sh`.

Antes de ejecutarlos: iniciar el stack PostgreSQL del equipo, levantar el overlay `persona5/docker-compose.persona5.yml`, importar y activar en n8n R4/H1/H3/D7 y añadir el filtro A2 al bot Telegram del equipo. No ejecutar pruebas contra infraestructuras de terceros.

A3 es una emulación en macOS/Windows por defecto; A4 tiene reversión automática y comando de recuperación en la guía; A5 ejecuta SELECT con salida descartada. Guardar las capturas reales en `persona5/evidencias/A1` a `A5` y completar el informe.
