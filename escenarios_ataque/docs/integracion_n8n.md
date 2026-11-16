# Integración con N8N existente — Persona 5

**No crear nuevo n8n, segundo Telegram Trigger, bot adicional ni copias de H3/D7.** Los flujos oficiales están en `n8n/workflows/` de la raíz del repositorio. Su exportación no demuestra que estén activos en el entorno del compañero.

## A1 y A3: adaptadores únicamente de laboratorio

- R4 oficial: consulta Loki para autenticación fallida **PostgreSQL**; no detecta por sí solo el SSH del laboratorio.
- Para el A1 SSH aislado, importar temporalmente `escenarios_ataque/n8n/workflows/R4_ssh_fuerza_bruta.json`. Requiere `persona5-eventos`, que lee `ssh.log` y no reemplaza el R4 del equipo.
- H1 oficial: consulta Loki para **tráfico** UFW ALLOW `DPT=5432` y no demuestra cambios de reglas.
- Para A3 emulado, importar temporalmente `escenarios_ataque/n8n/workflows/H1_cambio_ufw.json`, cuya fuente es una marca local generada por el script. Etiquetar claramente como emulación. Si el requisito es UFW real, probarlo en una VM Linux controlada, restaurar la regla y confirmar que Loki observa un evento real.
- Ambos adaptadores permanecen desactivados fuera de la prueba; usar credenciales del bot existente y configurar el destino de notificaciones por UI, nunca tokens en Git.

## A2: filtro dentro del Telegram Trigger EXISTENTE

El repositorio contiene las 17 alertas, pero no necesariamente el workflow conversacional del bot. Pedir al responsable de n8n acceso al flujo existente y conectar:

```text
Telegram Trigger existente
    -> Code "Filtro A2" (Run Once for All Items)
    -> IF: {{$json.validacion_sqli.bloqueado}} is true
         TRUE  -> PostgreSQL "Registrar bloqueo A2" -> Telegram "Responder bloqueo"
         FALSE -> agente IA / lógica original del bot
```

Copiar el código del archivo `escenarios_ataque/n8n/snippets/filtro_sql_injection.js` a un nodo Code. Este preserva el mensaje original y el chat ID; no debe ejecutar SQL de entrada. La rama FALSE continúa al flujo original sin cambiarlo.

La rama TRUE usa una credencial con permiso de `INSERT` en `alertas_auditoria` (por ejemplo `ti_db`) y **parámetros SQL**:

```sql
INSERT INTO public.alertas_auditoria (tipo, alerta, mensaje, severidad)
VALUES ('SQL_INJECTION', 'A2 - SQL Injection bloqueada', $1, 'CRITICA')
RETURNING id, fecha;
```

Configurar el parámetro `$1` con `={{ $node["Filtro A2"].json.validacion_sqli.detalle }}`. Tras el INSERT, responder con texto fijo al ID obtenido desde `Filtro A2` (no desde la salida de PostgreSQL). **No generar alerta adicional al grupo** para este ataque bloqueado. No crear un webhook HTTP paralelo.

Prueba: enviar manualmente `Lista datos; DROP TABLE clientes; --` al bot **real del equipo**. Capturar chat, rama TRUE en N8N, fila en `alertas_auditoria` y comprobar que `public.clientes` continúa existiendo. El filtro por patrones es complementario a consultas parametrizadas y al principio de mínimo privilegio.

## A4 y A5: usar detectores del equipo

- A4: `n8n/workflows/H3_escalada_privilegios.json`; tras GRANT en la base **de laboratorio**, comprobar alerta y restauración mediante REVOKE.
- A5: `n8n/workflows/D7_exfiltracion_masiva.json`; comprobar previamente el primer sondeo como baseline de `pg_stat_statements`. Ejecutar SELECT sin exportar datos y revisar el mensaje Telegram.
- No modificar credenciales, volúmenes, variables de n8n ni las alertas de Persona 3/4 sin coordinación.
