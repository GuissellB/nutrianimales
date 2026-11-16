# Informe técnico para entregar — Escenarios de ataque simulado (Persona 5)

**NutriAnimales S.A. — BCD 9220 Seguridad de Sistemas Digitales, III Cuatrimestre 2026**

> Documento listo para completar con **evidencia real**. Los campos entre `[ ]` se rellenan después de ejecutar los escenarios en el laboratorio. No fabricar capturas, tiempos ni alertas. La entrega final del proyecto es el 16/11/2026.

## 8. Escenarios de ataque simulado

### 8.1 Metodología

Se implementaron cinco escenarios en un laboratorio Docker aislado, utilizando PostgreSQL 16, n8n y alertas de Telegram. Para A1 se instaló un OpenSSH de pruebas que escucha solo dentro de su contenedor. Para A3 se ofrece un modo de emulación cuando se utiliza Docker Desktop, y una alternativa de UFW real únicamente en una VM Linux autorizada. Las pruebas documentadas utilizan los flujos H3, D7 y R4-SSH del laboratorio personal de n8n, mediante sondeos aproximados cada 60 segundos. H1-P5 permanece como adaptador para A3. Estas pruebas no implican modificaciones ni nuevas validaciones de los workflows oficiales del equipo. Se registran hora del inicio, hora de la detección, tiempo transcurrido y acción de respuesta.

**Advertencia metodológica:** La alerta R4 se describe como fallos de PostgreSQL en la sección de alertas del PDF (p. 5), pero A1 pide SSH (p. 11). Este laboratorio verifica el ataque SSH y lo identifica explícitamente como R4-SSH. H1 detecta eventos del ejecutor A3, no cualquier cambio independiente del firewall. D7 detecta lectura masiva, no salida efectiva de información.

### 8.2 Resumen de resultados (rellenar)

| Escenario | Alerta | Hora de ataque | Hora de alerta/bloqueo | Latencia | Resultado |
|---|---|---|---|---|---|
| A1 — Fuerza bruta SSH | R4-SSH | [ ] | [ ] | [ ] | [ ] |
| A2 — SQL Injection Telegram | IF / bloqueo A2 | [ ] | [ ] | [ ] | [ ] |
| A3 — Apertura 5432 UFW | H1 | [ ] | [ ] | [ ] | [ ] |
| A4 — Escalada `agente_ia` | H3 | [ ] | [ ] | [ ] | [ ] |
| A5 — Lectura masiva | D7 | [ ] | [ ] | [ ] | [ ] |

Meta del documento: A2 inmediato; A1, A3, A4 y A5 < 5 minutos. Calcular latencia a partir de timestamps efectivos, preferiblemente con segundos y zona horaria UTC-6.

### 8.3 A1 — Fuerza bruta SSH

- **Objetivo:** provocar 20 fallos de autenticación reales contra un `sshd` aislado, superar 5 fallos en 10 minutos.
- **Ejecución:** `pwsh -File escenarios_ataque/ataques/A1_fuerza_bruta.ps1 -ConfirmarLaboratorio` (o Bash A1).
- **Fuente:** `escenarios_ataque/observability/logs/ssh.log` con líneas `Failed password`.
- **Alerta:** R4-SSH en n8n y Telegram. Hora del aviso: [ ].
- **Resultado:** [ ]. **Acción:** revisar IP/usuario; aislamiento del laboratorio / control de acceso: [ ].
- **Capturas:** `evidencias/A1/01_comando.png`, `02_deteccion.png`, `03_registro.png`, `04_respuesta.png`.

### 8.4 A2 — SQL Injection vía Telegram

- **Objetivo:** bloquear el texto `Lista datos; DROP TABLE clientes; --` antes de que llegue al agente SQL.
- **Ejecución:** envío manual al bot; el filtro Code detecta la secuencia y un IF la dirige a la rama de bloqueo.
- **Registro:** `public.alertas_auditoria` con `tipo='SQL_INJECTION'`, más captura de ejecución de n8n.
- **Resultado:** [bloqueada/no bloqueada]; verificar `to_regclass('public.clientes')`: [ ].
- **Respuesta:** mensaje fijo de solicitud bloqueada; según el PDF, no generar alerta de Telegram al grupo.
- **Capturas:** `evidencias/A2/01_comando.png`, `02_deteccion.png`, `03_registro.png`, `04_respuesta.png`.

### 8.5 A3 — Apertura del puerto 5432

- **Objetivo:** verificar la alerta H1 cuando se permite el puerto de PostgreSQL en una política UFW.
- **Modo empleado:** [emulación Docker Desktop / UFW real en VM Linux].
- **Ejecución:** `pwsh -File escenarios_ataque/ataques/A3_apertura_puerto.ps1 -ConfirmarLaboratorio` (añadir `-RealLinux` solo si aplica).
- **Fuente:** `escenarios_ataque/observability/logs/ufw.log` (evento de cambio de prueba).
- **Resultado:** [ ]. **Respuesta:** [revertir regla real / cerrar emulación, no se abrió el puerto].
- **Capturas:** `evidencias/A3/01_comando.png`, `02_deteccion.png`, `03_registro.png`, `04_respuesta.png`.

### 8.6 A4 — Escalada de privilegios

- **Objetivo:** simular un GRANT administrativo de INSERT a `agente_ia`, que debe ser de solo lectura.
- **Ejecución:** `pwsh -File escenarios_ataque/ataques/A4_escalada_privilegios.ps1 -ConfirmarLaboratorio`.
- **Fuente:** `pg_class` + `has_table_privilege`, o `information_schema.role_table_grants`.
- **Resultado:** H3 [ ]. **Respuesta:** `REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;`; verificación final: [ ].
- **Capturas:** `evidencias/A4/01_comando.png`, `02_deteccion.png`, `03_registro.png`, `04_respuesta.png`.

### 8.7 A5 — Lectura masiva de datos

- **Objetivo:** detectar más de 1000 filas seleccionadas en tablas sensibles por `agente_ia`.
- **Ejecución:** `pwsh -File escenarios_ataque/ataques/A5_exfiltracion.ps1 -ConfirmarLaboratorio` después del baseline.
- **Fuente:** `public.pg_stat_statements` con `rolname='agente_ia'`, `rows` y `calls`.
- **Resultado:** D7 [ ]. **Respuesta:** investigar legitimidad y revisar credenciales si corresponde: [ ].
- **Limitación:** los resultados SQL se descartan en `/dev/null`; es una emulación de lectura masiva, no una exfiltración fuera del entorno.
- **Capturas:** `evidencias/A5/01_comando.png`, `02_deteccion.png`, `03_registro.png`, `04_respuesta.png`.

### 8.8 Evidencia de auditoría

La tabla `auditoria_datos` fue diseñada con triggers para INSERT/UPDATE/DELETE sobre tablas de negocio. Por tanto, un login SSH, una solicitud bloqueada, un cambio UFW, un GRANT y un SELECT no originan necesariamente registros en esta tabla. Para estos casos, la trazabilidad válida se obtiene de logs de SSH, `alertas_auditoria`, bitácora UFW, catálogo de roles y `pg_stat_statements`. Esta diferencia frente a la instrucción general de la página 11 debe explicarse con transparencia en la exposición.

### 8.9 Conclusión y mejoras

Los cinco escenarios permiten evaluar controles preventivos y detectivos: validación previa a N8N, alertas de eventos de autenticación, cambios de política de red, mínimos privilegios y lecturas masivas. La capacidad real del sistema solo puede afirmarse al completar las pruebas en vivo y adjuntar sus capturas. La prueba A2 por webhook HTTP no valida recepción directa por Telegram; A3 emulada no valida UFW real. Se recomienda en un entorno productivo: correlación en un SIEM, monitoreo independiente del firewall y acceso SSH, reglas de detección persistentes, pruebas periódicas y restricción de uso de cuentas administrativas.

## 9. Gestión de secretos

Adjuntar la política disponible en `docs/gestion_secretos.md`, y las capturas de revocación/creación de API key de laboratorio según lo requiera el profesor. No incluir tokens o contraseñas reales en el informe.
