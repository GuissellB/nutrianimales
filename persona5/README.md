# Persona 5 — Escenarios de ataque simulado A1–A5

Paquete diseñado para integrarse **dentro** del repositorio `GuissellB/nutrianimales` (carpeta `persona5/`). Ejecutar solo en máquinas, VMs y bots controlados por el equipo. Fecha de entrega del proyecto: 16 de noviembre de 2026.

## 1. Arquitectura de la prueba

| Escenario | Origen de evidencia | Detección n8n | Respuesta |
|---|---|---|---|
| A1 Fuerza bruta SSH | OpenSSH aislado `persona5-ssh`, `ssh.log` | R4 consulta `persona5-eventos` cada minuto (más de 5 fallos/10 min) | Bloquear/aislar origen y revisar usuario; no cambia la BD |
| A2 SQL Injection | Mensaje en bot real, filtro `Filtro A2` | Rama bloqueada y registro en `alertas_auditoria`; **sin alerta al grupo por Telegram** | Respuesta segura al usuario, no ejecutar SQL |
| A3 Apertura UFW | `ufw.log` con marca de prueba; opcional VM Linux UFW | H1 consulta `persona5-eventos` cada minuto | Revertir UFW en Linux; en Windows/macOS solo es emulación |
| A4 Escalada `agente_ia` | Catálogo `pg_class`/`has_table_privilege` | H3 revisa permisos cada minuto | REVOKE automático a los 150 segundos |
| A5 Lectura masiva | `pg_stat_statements` de `agente_ia` | D7 calcula filas nuevas por sondeo (> 1000) | Investigar, evaluar revocación/rotación |

A1 y A3 son **laboratorios acotados**: la API de eventos no es SIEM corporativo ni sustituye monitorización de un servidor real.

## 2. Preparación

Requisitos: Docker Desktop o Docker Engine con Linux containers; PostgreSQL 16 del repositorio inicializado con roles y `pg_stat_statements`; n8n/Telegram de Persona 3 en **la misma red `nutrianimales-net`**; PowerShell 7 o Bash. No usar datos reales de clientes.

1. Poner `persona5/` en la raíz del repositorio. Asegurarse de tener las dependencias del repositorio creadas (`.env` y certificados) según `postgres/README.md` de Persona 1; no copiarlas a esta carpeta.
2. Abrir terminal **desde la raíz `nutrianimales/`** y levantar PostgreSQL como indique el README original:

```powershell
$base = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml')
docker compose @base up -d
```

3. Levantar SOLO el SSH y el monitor de eventos de Persona 5 (no se requiere `docker-compose.n8n.yml`, que no estaba en el repo al preparar esta entrega):

```powershell
$files = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml','-f','persona5/docker-compose.persona5.yml')
docker compose @files config --quiet
docker compose @files up -d --build persona5-ssh persona5-eventos
docker compose @files ps
```

En macOS/Linux, comando equivalente desde la raíz:

```bash
docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
  -f persona5/docker-compose.persona5.yml up -d --build persona5-ssh persona5-eventos
```

4. Verificar la API desde **dentro de la red Docker**, sin exponer puertos:

```powershell
docker exec nutrianimales-persona5-eventos python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8765/health').read().decode())"
```

Resultado esperado: `{"estado":"ok"}`. Si falla, revisar `docker logs nutrianimales-persona5-eventos`.

## 3. Importar y conectar n8n

Ver **`docs/integracion_n8n.md`**. Los JSON de R4, H1, H3, D7 y el subflujo A2 están en `n8n/workflows`. Antes de activarlos: seleccionar las credenciales PostgreSQL y Telegram en los nodos, reemplazar `CONFIGURAR_CHAT_ID`, verificar conexión a la red Docker y activar cada flujo. **No dejar dos Telegram Trigger para el mismo bot**. H1/R4 usan la API interna; H3/D7 usan la BD del stack.

**IMPORTANTE D7:** Activar D7 al menos 1 minuto antes del ataque para establecer el baseline. Si no lo haces, la primera consulta observada podría ser tratada como parte del baseline.

## 4. Ejecución en PowerShell 7 (Windows, macOS o Linux)

Desde la raíz del repositorio:

```powershell
pwsh -File persona5/ataques/A1_fuerza_bruta.ps1 -ConfirmarLaboratorio
pwsh -File persona5/ataques/A2_sql_injection.ps1
pwsh -File persona5/ataques/A2_sql_injection.ps1 -Verificar
pwsh -File persona5/ataques/A3_apertura_puerto.ps1 -ConfirmarLaboratorio
pwsh -File persona5/ataques/A4_escalada_privilegios.ps1 -ConfirmarLaboratorio
pwsh -File persona5/ataques/A5_exfiltracion.ps1 -ConfirmarLaboratorio
```

A3 simula por defecto. Solo en VM Linux **autorizada**, con consola local y acceso a recuperación, se puede probar la regla real:

```powershell
pwsh -File persona5/ataques/A3_apertura_puerto.ps1 -ConfirmarLaboratorio -RealLinux -SegundosVentana 120
```

No ejecutar la opción de UFW real en equipos remotos ni máquinas compartidas: un error de firewall puede interrumpir el acceso. Si algo falla, comprobar/revertir manualmente: `sudo ufw delete allow 5432/tcp`.

## 5. Ejecución alternativa en Bash (macOS/Linux)

```bash
bash persona5/ataques/ejecutar-macos-linux.sh A1 --confirmo-laboratorio
bash persona5/ataques/ejecutar-macos-linux.sh A2 --confirmo-laboratorio
bash persona5/ataques/ejecutar-macos-linux.sh A3 --confirmo-laboratorio
bash persona5/ataques/ejecutar-macos-linux.sh A4 --confirmo-laboratorio
bash persona5/ataques/ejecutar-macos-linux.sh A5 --confirmo-laboratorio
```

En Bash A3 **siempre es emulado**. Para UFW real usar PowerShell 7 en VM Linux o el procedimiento del PDF con consola y reversión manual.

## 6. Capturas y resultados reales

En `persona5/evidencias/A1` ... `A5`, agregar para cada ataque:

- `01_comando.png`: consola o mensaje enviado al bot con hora de inicio.
- `02_deteccion.png`: alerta Telegram (A1/A3/A4/A5) o bloqueo del bot en A2.
- `03_registro.png`: SSH, `alertas_auditoria`, UFW, permisos PG o `pg_stat_statements` respectivamente.
- `04_respuesta.png`: recuperación, revocación o acción de seguridad realizada.

Usar el informe `docs/informe_ataques_y_secretos.md`. **No inventar alertas ni timestamps**. El tiempo de detección se obtiene de la diferencia de horas; la hora de sondeo puede retrasar ~60 segundos.

## 7. Revocación de emergencia

Si A4 se interrumpe y el `finally`/`trap` no alcanzó a ejecutarse (p. ej., cierre forzoso del proceso), revocar INMEDIATAMENTE con la cuenta administradora:

```powershell
docker exec -it nutrianimales-postgres psql -h 127.0.0.1 -U postgres -W -d nutrianimales_db -X -v ON_ERROR_STOP=1 -c "REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;"
```

Luego validar que todos los permisos de INSERT/UPDATE/DELETE de `agente_ia` son falsos. No ejecutar ese REVOKE si la cuenta ya tenía INSERT antes de la prueba; el script aborta en ese caso y debe investigarse.

## 8. Nota sobre A1 y la contradicción del PDF

En la página 11 se exige **fuerza bruta SSH**; en la página 5 la alerta R4 figura como autenticaciones fallidas de **PostgreSQL**. Esta entrega da prioridad al **tipo de ataque A1** y reproduce el umbral R4 contra logs reales de un `sshd` aislado. Se debe señalar la discrepancia al profesor, ya que no reemplaza un detector R4 de PostgreSQL para la totalidad del proyecto.

## 9. Ejecutar pruebas estáticas

```bash
python3 persona5/pruebas/test_archivos.py
node persona5/pruebas/test_n8n.js
```

Opcional: conservar `legacy-observability` para comparación con la versión anterior, pero **no** combinar sus overlays con `docker-compose.persona5.yml` sin revisar conflictos de red y volúmenes.
