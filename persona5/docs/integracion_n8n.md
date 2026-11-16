# Integración en n8n — Persona 5

## Antes de importar

1. Levantar PostgreSQL, n8n y el overlay `persona5/docker-compose.persona5.yml`. `n8n` debe estar conectado a `nutrianimales-net`.
2. Verificar que los contenedores `nutrianimales-persona5-ssh` y `nutrianimales-persona5-eventos` estén activos.
3. En n8n crear o reutilizar credenciales **sin pegarlas en nodos JSON**:
   - Credencial PostgreSQL `agente_ia` para H3 y D7, con los permisos de lectura y monitoreo del repositorio.
   - Credencial PostgreSQL `ti_db` para INSERT en `alertas_auditoria` en A2.
   - Credencial Telegram existente para alertas R4/H1/H3/D7 y respuestas bloqueadas de A2.
4. Cambiar el campo `CONFIGURAR_CHAT_ID` de los nodos Telegram por el chat/grupo de pruebas **usando n8n UI**. No hay tokens ni IDs en el paquete.

## R4 (A1)

Importar `R4_ssh_fuerza_bruta.json`. Nodos: Schedule (1min) → HTTP `http://persona5-eventos:8765/resumen?tipo=ssh&ventana=600` → Code (total >5 y deduplicación) → IF → Telegram. Activar y ensayar. La fuente es el log real de SSH en el contenedor, no PostgreSQL.

## H1 (A3)

Importar `H1_cambio_ufw.json`. HTTP lee `/resumen?tipo=ufw&ventana=300`. Este demostrador reconoce eventos escritos por el script A3; no vigila modificaciones externas al servidor o todas las reglas UFW. En macOS/Windows es **emulación**, no apertura real de puerto.

## H3 (A4)

Importar `H3_grant_agente_ia.json`. Postgres consulta `pg_class` + `has_table_privilege` para verificar privilegios de escritura efectivos en tablas de `public`. Es recomendable usar credencial **solo lectura** `agente_ia` porque las consultas al catálogo no necesitan cuenta superusuario. El flujo alerta al detectar transición de 0 a una o más tablas editables. No activar si ya hay permisos de escritura preexistentes sin investigarlos.

## D7 (A5)

Importar `D7_select_masivo.json`. Usa `pg_stat_statements` y el usuario observado `agente_ia`. El código establece baseline en primer sondeo, guarda el acumulado por `queryid` y alerta si se leyeron **más de 1000 filas** desde el sondeo anterior. En el nodo Postgres seleccionar la credencial `agente_ia` y habilitar `Always Output Data` si el workflow se detiene por respuesta SQL vacía. Activar y esperar 1 minuto antes de ejecutar A5.

**Nota de precisión:** un delta de más de 1000 filas indica lectura masiva, **no prueba exfiltración fuera del sistema**. El script A5 descarta la salida y no envía información a terceros.

## A2: filtro en el bot de Telegram EXISTENTE

No importar el archivo como bot independiente: solo puede existir un webhook activo del mismo bot. Abrir el flujo actual de Telegram y añadir los nodos de `A2_bloqueo_sql_injection_subflujo.json`, o copiar el código desde `n8n/snippets/filtro_sql_injection.js` a un nodo Code.

Orden correcto:

```text
Telegram Trigger existente
  └─ Filtro A2 (Code; ejecutar una vez con todos los items)
     └─ ¿SQLi bloqueada? (IF)
        ├─ TRUE  → Registrar bloqueo A2 (Postgres ti_db) → Responder bloqueo A2 (Telegram)
        └─ FALSE → Agente de IA / lógica del bot YA EXISTENTE
```

El nodo `CONECTAR A AGENTE IA EXISTENTE` es un marcador; **quitarlo y conectar la rama FALSE** a la lógica original. El filtro devuelve el mensaje original con `validacion_sqli` agregado, evitando perder `message.chat.id`.

SQL parametrizado del nodo Postgres:

```sql
INSERT INTO public.alertas_auditoria (tipo, alerta, mensaje, severidad)
VALUES ('SQL_INJECTION','A2 - SQL Injection bloqueada', $1,'CRITICA')
RETURNING id, fecha;
```

Campo Options → Query Parameters:

```text
={{ $json.validacion_sqli.detalle }}
```

El valor se trata como parámetro SQL; **no** concatenar o interpolar `texto_original` dentro del SQL. La rama bloqueada responde al usuario con un texto fijo; no ejecuta consultas sobre datos del negocio. Capturar el historial del workflow y el registro `alertas_auditoria`.

Un filtro de patrones no sustituye un diseño seguro de consultas: mantener `agente_ia` en solo lectura, usar sentencias parametrizadas y no permitir al agente construir SQL ejecutable arbitrario.

## Diagnóstico habitual

| Síntoma | Qué revisar |
|---|---|
| R4/H1 sin eventos | Red Docker de n8n; nombres de contenedores; logs en `persona5/observability/logs`; hora UTC de los archivos |
| R4 no avisa | Más de 5 registros `Failed password` dentro de 10 minutos; activar workflow; credencial Telegram y chat ID |
| H1 no avisa | Ejecutar A3 desde raíz, comprobar `ufw.log`; el Code deduplica el último timestamp, repetir tras intervalo |
| H3 no avisa | Comprobar que A4 conserva permiso durante 150s, que `has_table_privilege` reporta tablas, credencial de lectura |
| D7 no avisa | Extensión `pg_stat_statements`; activación previa para baseline; permiso `agente_ia` a extensión; `Always Output Data` |
| A2 no registra | Ver permisos de `ti_db` en `alertas_auditoria` y valor `queryReplacement` del nodo |
| Sin Telegram | Reconfigurar chat ID y credencial en cada workflow; evitar IDs de la ZIP anterior |

**Responsabilidades del equipo:** quien administra n8n debe importar/activar flujos y credenciales; Persona 5 proporciona los tests y evidencias. No reemplazar workflows existentes sin revisión.
