# n8n y alertas de Telegram — NutriAnimales S.A.

Esta guía explica la implementación del monitoreo con **n8n y Telegram** en Windows, PowerShell y Docker Desktop. **Punto de partida:** PostgreSQL ya está funcionando, las tablas y los perfiles (incluido `agente_ia`) ya existen, los permisos de monitoreo están aplicados y el equipo dispone de sus credenciales. No se reinicializa la base ni se recrean sus tablas. Para los preparativos de PostgreSQL, consultar [postgres/README.md](../postgres/README.md).

> **Actualización del ZIP recibido:** hay **ocho** workflows JSON exportados: D1, D2, D3, D4, D5, R1, R3 y R5. Existen capturas de comando, ejecución de n8n y Telegram para D2 y R3, que antes faltaban. R2 y R4 todavía no tienen exportación JSON y sus carpetas de evidencias están vacías. **D2 figura como `active: true` en su archivo JSON**, pero ese dato no confirma que esté activo después de importarlo en otra instalación; los demás exportados muestran `active: false`. Las evidencias son de la instalación de origen y deben repetirse en el entorno destino.

## 1. Punto de partida (PostgreSQL ya preparado)

Antes de comenzar, el equipo debe tener el repositorio `nutrianimales`, Docker Desktop operativo, la base `nutrianimales_db` con sus tablas y perfiles, un usuario `agente_ia` con permisos de lectura/monitoreo y la contraseña de conexión. **No ejecutar scripts de creación de tablas, seed ni reinicialización** en este procedimiento. La base existente y sus registros se conservan.

Desde **PowerShell**, abrir la carpeta raíz del repositorio (donde están los `docker-compose*.yml`) y comprobar los archivos:

```powershell
docker compose version
docker ps
Test-Path ./docker-compose.n8n.yml
Get-ChildItem ./n8n/workflows/*.json | Select-Object Name
```

Si todavía no se descargó el repositorio, usar `git clone https://github.com/GuissellB/nutrianimales.git` y entrar a su carpeta. Si se está trabajando en una rama de equipo, verificar que contiene los ocho archivos JSON. **No ejecutar `docker compose down -v`**.

## 4. Preparar el Compose de n8n

El archivo **ya está incluido**: [`docker-compose.n8n.yml`](../docker-compose.n8n.yml). Si se parte de una copia que todavía no lo contiene, crearlo en la **raíz del proyecto**, junto a `docker-compose.yml`, con este contenido:

```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:stable
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      GENERIC_TIMEZONE: America/Costa_Rica
      TZ: America/Costa_Rica
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY:?Configure N8N_ENCRYPTION_KEY en .env}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./n8n/certificates:/opt/custom-certificates
    networks:
      - nutrianimales-net
    security_opt:
      - no-new-privileges:true
volumes:
  n8n_data:
```

**Importante:** este es un *overlay*, no un Compose independiente. Hereda la red `nutrianimales-net` del archivo principal. Nunca lo levantes solo con `docker compose -f docker-compose.n8n.yml up -d`.

### 4.1 Generar la clave de cifrado de n8n

Abrir `.env` y **añadir** `N8N_ENCRYPTION_KEY` sin borrar las variables de PostgreSQL:

```powershell
# Ejecutar una sola vez en el equipo; copiar su resultado a .env.
$bytes = [byte[]]::new(32)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
[Convert]::ToHexString($bytes)
```

En `.env` (valor de ejemplo, **no usar literalmente**):

```dotenv
N8N_ENCRYPTION_KEY=PEGAR_AQUI_LA_CLAVE_ALEATORIA_GENERADA
```

Mantener esa clave **estable** a lo largo de los reinicios y respaldarla de forma segura. Si se pierde o cambia, las credenciales cifradas existentes de n8n pueden dejar de descifrarse. `.env` está excluido por `.gitignore`; verificarlo antes de publicar cambios. No subir tokens de Telegram ni contraseñas al repositorio.

### 4.2 Preparar el certificado del servidor PostgreSQL

La conexión está protegida por TLS. La carpeta local `n8n/certificates/` debe contener el certificado público del servidor, normalmente copiado desde `postgres/certs/server.crt`:

```powershell
New-Item -ItemType Directory -Force ./n8n/certificates | Out-Null
Copy-Item ./postgres/certs/server.crt ./n8n/certificates/postgres.crt
Get-ChildItem ./n8n/certificates
```

Los archivos de certificado que se encuentren en el ZIP o en una instalación ajena **no reemplazan** al certificado del servidor local. No copiar `server.key` a n8n. La carpeta de certificados está excluida de Git.

> La ubicación `/opt/custom-certificates/postgres.crt` queda disponible en el contenedor; el hecho de montarla **no habilita automáticamente** la confianza TLS del nodo PostgreSQL. Configurar el certificado CA/servidor y la validación del nombre de host en las opciones de la credencial que ofrezca la versión instalada. Si la versión del nodo no permite proporcionar el CA necesario, no desactivar la validación silenciosamente: consultar la documentación de n8n para su mecanismo de certificados de confianza y verificar la conexión. El hostname debe ser `postgres` y coincidir con el certificado generado.

## 5. Levantar todos los servicios

Usar **siempre** la misma combinación de archivos desde la raíz del repositorio:

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml','-f','docker-compose.n8n.yml')
docker compose @compose config --quiet
docker compose @compose up -d --wait --wait-timeout 120
docker compose @compose ps -a
```

Comprobar `nginx`, `postgres` y `n8n`. El servicio `postgres-tls-init` puede aparecer finalizado con código 0; es normal. Para revisar errores:

```powershell
docker compose @compose logs --tail=80 n8n
docker compose @compose logs --tail=80 postgres
```

Para reiniciar solo n8n:

```powershell
docker compose @compose restart n8n
```

Para detener servicios sin eliminar volúmenes:

```powershell
docker compose @compose stop
```

**No ejecutar `docker compose down -v`: borra los volúmenes y puede eliminar datos y la configuración de n8n.** El volumen `n8n_data` conserva cuentas, workflows, credenciales y configuraciones internas de n8n.

## 6. Entrar a n8n y crear la cuenta web

1. Abrir **http://localhost:5678** en el navegador del mismo equipo. El puerto está publicado solo en `127.0.0.1`; otros dispositivos no pueden entrar directamente.
2. En el primer acceso, completar el registro del propietario (*owner*): correo, nombre y contraseña robusta. Esa es una cuenta **web de n8n**, distinta de PostgreSQL y Telegram.
3. En visitas siguientes, iniciar sesión con la cuenta creada. Si ya existe `n8n_data`, normalmente aparece directamente el inicio de sesión.
4. Entrar al área de **Workflows**. Los nombres exactos de los menús pueden variar según la versión.

El HTTP local se limita a pruebas en el equipo. No publicar `5678` en Internet sin autenticación, TLS y controles de acceso adecuados.

## 7. Crear la credencial PostgreSQL para las alertas

En n8n ir a **Credentials → New credential → Postgres** (o crearla desde un nodo PostgreSQL). Usar estos valores:

| Campo | Valor |
|---|---|
| Host | `postgres` (**no** `localhost`) |
| Port | `5432` |
| Database | El valor `POSTGRES_DB` de `.env`, normalmente `nutrianimales_db` |
| User | `agente_ia` |
| Password | Contraseña local de `agente_ia`, facilitada de modo seguro |
| SSL/TLS | Activado, validando certificado y hostname, según las opciones disponibles |
| Nombre de credencial (sugerido) | `PostgreSQL - agente_ia - NutriAnimales` |

Presionar **Test connection** / **Retry** y guardar. La cuenta `agente_ia` permite consultar las tablas y vistas necesarias, pero no modificar datos. Para ejecutar pruebas de escritura se usa por separado una cuenta autorizada en un cliente `psql`, **no se cambian los permisos del agente**.

Si da error de autenticación, verificar la contraseña y la base. Si da *connection refused*, comprobar que n8n y PostgreSQL están levantados en la misma red Docker. Si el error es TLS, revisar el certificado y que se valida el hostname `postgres`.

### Verificación independiente por consola

El repositorio ofrece un contenedor cliente que solicita la contraseña de la cuenta correspondiente:

```powershell
$cliente = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml','-f','docker-compose.client.yml')
docker compose @cliente --profile tools run --rm pg-client
```

Una vez conectado como `agente_ia`:

```sql
SELECT session_user, current_database();
SELECT COUNT(*) FROM public.auditoria_datos;
SELECT name, valor_esperado FROM public.pg_settings_baseline ORDER BY name;
SELECT pid, usename, state FROM pg_stat_activity;
```

## 8. Crear el bot de Telegram y obtener el chat ID

1. Abrir Telegram y buscar el bot oficial **@BotFather** (verificar su identidad). Enviar `/newbot`.
2. Elegir nombre y nombre de usuario del bot. BotFather entrega un **token secreto**. Tratarlo como una contraseña y **no subirlo a GitHub ni pegarlo en capturas**.
3. Abrir una conversación con el bot y presionar **Start**, o agregar el bot al grupo de alertas con los permisos necesarios para publicar mensajes.
4. Enviar un mensaje de prueba al bot o al grupo (por ejemplo, `/start`).
5. Para identificar el chat, consultar temporalmente desde **PowerShell local** el endpoint oficial de Telegram (sin incluir el token en el historial compartido):

```powershell
$token = Read-Host 'Pega el token privado del bot'
$updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/getUpdates"
$updates.result | ForEach-Object { $_.message.chat; $_.channel_post.chat } |
  Where-Object { $_ } | Select-Object id, title, type -Unique
Remove-Variable token
```

El `id` devuelto es el **chat ID**. Los grupos suelen tener IDs negativos. Si no aparece, enviar un mensaje nuevo al bot/grupo y repetir; verificar que el bot está presente y que recibe los eventos necesarios. Alternativamente, consultar el chat ID por otro método autorizado de Telegram. No hay que crear un canal de Telegram obligatoriamente: **puede ser chat privado, grupo o canal**, siempre que el bot pueda escribir allí.

### Crear la credencial de Telegram en n8n

En n8n: **Credentials → New credential → Telegram API**, pegar el token del bot y guardar. Nombre sugerido: `Telegram - Alertas NutriAnimales`. En un workflow de prueba agregar un nodo **Telegram → Send Message**, seleccionar la credencial, introducir el chat ID y un texto no sensible como `Prueba de conexión NutriAnimales`. Ejecutarlo manualmente y confirmar que llegó el mensaje.

> Los JSON del proyecto contienen un chat ID del entorno original. **Reemplazar el campo Chat ID en cada nodo Telegram** por el chat ID del nuevo equipo. El chat ID no sustituye al token: ambos son necesarios, pero solo el token es secreto.

## 9. Importar los workflows JSON

Los JSON están en [`n8n/workflows/`](workflows/). En n8n crear un workflow y usar **Import from File** desde su menú (el texto puede variar por versión). Seleccionar **cada archivo** de la carpeta, revisar sus credenciales y guardar.

| Alerta | Archivo exportado | Frecuencia registrada en el JSON | Qué observa |
|---|---|---|---|
| **D1** | `D1 - DELETE masivo sin WHERE.json` | 1 minuto | Patrones de DELETE vía `pg_stat_statements` |
| **D2** | `D2 - Crecimiento anormal de tablas.json` | **30 minutos** | Estimaciones de filas y crecimiento frente a mediciones anteriores |
| **D3** | `D3 - Monitoreo de respaldos.json` | Diario, **08:00** | Ausencia u obsolescencia de backup exitoso |
| **D4** | JSON de duplicados en tablas críticas | 1 minuto | Repeticiones en varias tablas de negocio |
| **D5** | JSON de transacciones bloqueadas | 1 minuto | Esperas por bloqueo superiores al umbral |
| **R1** | JSON de consultas lentas | 1 minuto | Estadísticas de ejecución lenta |
| **R3** | `R3 – Conexiones fuera de horario.json` | 1 minuto | Sesiones visibles iniciadas entre **23:00 y 05:59** (Costa Rica) |
| **R5** | JSON de cambios de parámetros | 1 minuto | Diferencias con `pg_settings_baseline` |
| **R2 / R4** | **No están exportados** | Pendiente | No se deben presentar como implementados |

**Configuración obligatoria después de importar cada JSON:**

1. En **Schedule Trigger**, comprobar la frecuencia anterior y definir el timezone del workflow como `America/Costa_Rica`.
2. En **Postgres**, seleccionar la credencial que usa `agente_ia` (host Docker `postgres`, base `nutrianimales_db`, TLS configurado). Probar la conexión.
3. En **Telegram → Send Message**, seleccionar la credencial del bot propio del equipo y **reemplazar el chat ID que viene en el JSON**. Verificar texto, severidad, campos de salida y que el bot pueda publicar.
4. Revisar el recorrido completo **Schedule Trigger → consulta SQL → Code → If → Telegram**. Los JSON pueden mostrar otro orden visual de nodos; lo relevante son los conectores y la rama verdadera de `If`.
5. Guardar, ejecutar pruebas de la consulta y de Telegram por separado; revisar **Executions** y no confundir un workflow verde con un mensaje efectivamente entregado.
6. **Activar/Publicar** el workflow cuando la prueba sea correcta. No asumir que `active: true` en el JSON de D2 garantiza la activación en la nueva instancia.

### 9.1 Particularidades de D2 — ingesta y crecimiento

D2 consulta estadísticas de tablas (`pg_stat_user_tables`) y utiliza **memoria del workflow** para comparar los valores estimados con mediciones anteriores. Por tanto, **una ingesta de 600 filas no garantiza un aviso inmediato**: el primer ciclo puede fijar la línea base, las estadísticas pueden tener retraso y el siguiente ciclo programado ocurre hasta 30 minutos después. Para pruebas en laboratorio, tomar una medición antes de insertar, producir el crecimiento con una cuenta autorizada (no `agente_ia`) y volver a ejecutar un ciclo posterior. Verificar los umbrales exactos en el nodo `Code` del JSON y restablecer los datos únicamente después de respaldarlos.

### 9.2 Particularidades de R3 — conexiones fuera de horario

R3 consulta **`pg_stat_activity`** y excluye `agente_ia` para que la propia conexión de monitoreo no genere alertas. Considera sesiones cuyo `backend_start`, convertido a `America/Costa_Rica`, esté dentro de **23:00–06:00**. Esto incluye a los demás usuarios con LOGIN visibles para el monitor, **no** significa que exista un registro permanente de cada acceso. Se observa solo la base actual y las sesiones que todavía estén abiertas cuando se ejecuta el Schedule Trigger. Una conexión corta puede no detectarse y una sesión iniciada fuera del horario puede seguir listada más tarde mientras continúe abierta.

Para probarla después de las 23:00, en PowerShell (con el contenedor existente):

```powershell
docker exec -it nutrianimales-postgres psql -h 127.0.0.1 -U ti_db -d nutrianimales_db
```

Dentro de `psql`, mantener la sesión abierta mientras n8n ejecuta su siguiente ciclo:

```sql
SELECT current_user, inet_client_addr(), backend_start
FROM pg_stat_activity WHERE pid = pg_backend_pid();
```

Para salir escribir `\q`. También puede probarse con otro perfil de LOGIN distinto de `agente_ia`, siempre que esté autorizado. **No es necesario modificar el horario del equipo.** Si la sesión no aparece, revisar permisos de estadísticas, `current_database()`, horario, zona horaria y el filtro del SQL. Si el requisito exige capturar *todas* las conexiones, incluidas las cerradas, la consulta a `pg_stat_activity` es insuficiente: se necesita un flujo de ingestión de logs.

### Notificación única y limitaciones actuales

El proyecto utiliza `$getWorkflowStaticData('global')` en algunos nodos **Code** para recordar eventos avisados. Su funcionamiento se debe verificar con el workflow **activado y ejecutado por el disparador**, pues las ejecuciones manuales de prueba pueden no guardar ese estado como se espera. Este mecanismo no equivale a una base histórica de alertas y puede perder/reiniciar estado en determinadas condiciones; para producción se recomienda una tabla de eventos con clave única y ciclo de vida (nuevo/resuelto/reabierto).

**Puntos de revisión detectados en los JSON exportados:**

- **D1:** su consulta SQL produce un **resumen agregado**, mientras el código posterior intenta leer `query`, `rows` y `calls` directamente. Revisar ese desajuste; la clave de deduplicación no representa correctamente cada DELETE del resumen. Asimismo, `rows` y `calls` en `pg_stat_statements` son acumulados, no un DELETE individual ni una garantía semántica de “sin WHERE”.
- **D2:** el crecimiento utiliza estimaciones y estado histórico; la frecuencia real es 30 minutos, no 1 minuto.
- **R3:** deduplicar por combinación `pid` y `backend_start`; el mismo `pid` puede reutilizarse y las conexiones breves pueden desaparecer antes del sondeo.
- **D5:** la consulta agrega los PIDs bloqueados; el filtro recuerda el conjunto de procesos. Comprobar la recuperación cuando el bloqueo desaparece y vuelve a aparecer (la memoria podría impedir un nuevo aviso para la misma firma).
- **D4:** la memoria se basa en `tabla`, `campo`, cantidad y valores. Si el conjunto de duplicados cambia, se produce otra alerta; si se mantiene idéntico, no debería repetirse. Confirmar que se desea ese comportamiento.
- **R1:** mide máximos históricos de consultas normalizadas. Una consulta nueva puede servir primero para establecer el estado base y no notificarse hasta registrar una nueva ejecución más lenta; comprobarlo.
- **D3/R5:** utilizan memoria de estado para evitar repeticiones; revisar que una condición resuelta pueda volver a notificarse si reaparece.

Estas observaciones documentan límites técnicos **sin afirmar que un flujo todavía pendiente de corregir está validado para producción**.

## 10. Pruebas y evidencias

Todas las pruebas de modificación se realizan **solo en una base de laboratorio** o con autorización del equipo, y utilizando un usuario con los permisos mínimos apropiados. Antes de modificar registros, guardar respaldo y plan de restauración. No usar la cuenta `agente_ia` para generar eventos. La evidencia ideal incluye: comando, resultado SQL, ejecución de n8n y mensaje en Telegram; repetir la ejecución sin cambiar el evento para comprobar que no se envían alertas duplicadas.

Para abrir `psql` directamente en el contenedor con el administrador de la instalación local (solo para laboratorio y con autorización):

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml','-f','docker-compose.n8n.yml')
docker compose @compose exec postgres sh
# Dentro del contenedor: conectarse con las credenciales locales autorizadas;
# por ejemplo psql -U postgres -d nutrianimales_db, que puede pedir contraseña.
```

Para salir de `psql`, ejecutar `\q`; para salir del shell del contenedor, `exit`.

### Evidencias aportadas por el proyecto

Se verificó la presencia de las capturas siguientes dentro del ZIP actualizado. Para R2 y R4 las carpetas existen, pero todavía no contienen evidencias.

| Prueba | Capturas disponibles | Observación |
|---|---|---|
| D1 | [Comando](../evidencias/07_n8n_alerts/07_D1_prueba/comando_d1.png), [workflow](../evidencias/07_n8n_alerts/07_D1_prueba/workflow_ejecutado_d1.png), [Telegram](../evidencias/07_n8n_alerts/07_D1_prueba/alerta_d1.jpeg) | Revisar el desajuste del agregado y su deduplicación |
| D2 | [Comando](../evidencias/07_n8n_alerts/07_D2_prueba/comando_d2.png), [workflow](../evidencias/07_n8n_alerts/07_D2_prueba/workflow_ejecutado_d2.png), [Telegram](../evidencias/07_n8n_alerts/07_D2_prueba/alerta_d2.jpeg) | JSON y evidencias disponibles; repetir mediciones en el destino |
| D3 | [Workflow](../evidencias/07_n8n_alerts/07_D3_prueba/workflow_ejecutado_d3.png), [Telegram](../evidencias/07_n8n_alerts/07_D3_prueba/alerta_d3.jpeg) | Prueba de detección de respaldo obsoleto |
| D4 | [Comando 1](../evidencias/07_n8n_alerts/07_D4_prueba/comando_d4.1.png), [comando 2](../evidencias/07_n8n_alerts/07_D4_prueba/comando_d4.2.png), [workflow](../evidencias/07_n8n_alerts/07_D4_prueba/workflow_ejecutado_d4.png), [Telegram](../evidencias/07_n8n_alerts/07_D4_prueba/alerta_d4.jpeg) | Datos duplicados en tablas de negocio |
| D5 | [Terminal 1](../evidencias/07_n8n_alerts/07_D5_prueba/comando_d5_terminal1.png), [terminal 2](../evidencias/07_n8n_alerts/07_D5_prueba/comando_d5_terminal2.png), [workflow](../evidencias/07_n8n_alerts/07_D5_prueba/workflow_ejecutado_d5.png) | Prueba con sesiones paralelas; captura de Telegram pendiente en carpeta |
| R1 | [Comando](../evidencias/07_n8n_alerts/07_R1_prueba/comando_r1.png), [workflow](../evidencias/07_n8n_alerts/07_R1_prueba/workflow_ejecutado_r1.png), [Telegram](../evidencias/07_n8n_alerts/07_R1_prueba/alerta_r1.jpeg) | Consulta lenta |
| R3 | [Comando](../evidencias/07_n8n_alerts/07_R3_prueba/comando_r3.png), [workflow](../evidencias/07_n8n_alerts/07_R3_prueba/workflow_ejecutado_r3.png), [Telegram](../evidencias/07_n8n_alerts/07_R3_prueba/alerta_r3.jpeg) | Conexión TCP de prueba fuera de horario, conservada abierta durante el sondeo |
| R5 | [Comando](../evidencias/07_n8n_alerts/07_R5_prueba/comando_r5.png), [workflow](../evidencias/07_n8n_alerts/07_R5_prueba/workflow_ejecutado_r5.png), [Telegram](../evidencias/07_n8n_alerts/07_R5_prueba/alerta_r5.jpeg) | Cambio de configuración frente a baseline |

Para pruebas **no destructivas** antes de reproducir cambios, pueden consultarse las fuentes directamente:

```sql
-- D3: resumen del último backup registrado
SELECT MAX(fecha) AS ultimo_backup_registrado FROM public.backups;
-- D4: ver los códigos repetidos existentes (la tabla productos tiene UNIQUE en codigo)
SELECT codigo, COUNT(*) AS repeticiones
FROM public.productos GROUP BY codigo HAVING COUNT(*) > 1;
-- D5: procesos actualmente esperando un bloqueo
SELECT a.pid, a.usename, a.wait_event_type, a.wait_event,
       pg_blocking_pids(a.pid) AS bloqueadores
FROM pg_stat_activity a WHERE cardinality(pg_blocking_pids(a.pid)) > 0;
-- R1: consultas con máximo histórico superior a 1 segundo
SELECT LEFT(query,120), calls, max_exec_time
FROM public.pg_stat_statements WHERE max_exec_time > 1000 LIMIT 10;
-- R5: cambios respecto a baseline
SELECT b.name, b.valor_esperado, s.setting AS actual
FROM public.pg_settings_baseline b JOIN pg_settings s ON s.name=b.name
WHERE s.setting IS DISTINCT FROM b.valor_esperado;
```

**Nota sobre D4:** `productos.codigo` tiene una restricción `UNIQUE`, por lo que no se pueden generar duplicados ahí de forma normal. Para las pruebas se debe utilizar una tabla/campo que permita realmente datos repetidos, siempre con respaldo y limpieza posteriores. **Nota sobre D1:** jamás ejecutar un `DELETE` masivo sobre datos reales únicamente para probar la notificación; usar una base de prueba con datos desechables y una estrategia segura de limpieza/restauración.

### Cómo comprobar “notificar una sola vez”

1. Activar un workflow en una base de pruebas y registrar el estado inicial.
2. Generar **un** evento que cumpla su umbral y esperar al siguiente ciclo programado (en D3, ajustar temporalmente el horario en laboratorio).
3. Confirmar **una** ejecución con mensaje Telegram y guardar su captura.
4. Sin modificar la condición, observar dos o más ciclos adicionales: **no** debe volver a notificarse el mismo evento.
5. Resolver el evento, esperar un ciclo y volver a generarlo: definir si debe notificarse como incidente nuevo y verificar esa lógica.
6. Guardar capturas con nombres consistentes `comando_*.png`, `workflow_ejecutado_*.png`, `alerta_*.jpeg`, sin contraseñas/tokens.

## 11. Problemas frecuentes

| Síntoma | Revisión |
|---|---|
| No abre `localhost:5678` | Docker Desktop, `docker compose @compose ps -a`, `logs n8n`, puerto 5678 disponible |
| `N8N_ENCRYPTION_KEY` requerido | Añadir la clave aleatoria al `.env` local; conservarla |
| n8n no conecta con PostgreSQL | Host `postgres`, red Docker, base correcta, usuario `agente_ia`, contraseña y TLS |
| Error de certificado | CA público correcto, validación TLS habilitada y hostname coincidente con certificado |
| Workflow importado pero inactivo | Guardar, habilitar/activar, comprobar trigger y ejecuciones |
| Workflow verde pero sin Telegram | Revisar datos SQL, rama **If**, deduplicación en **Code**, chat ID, credencial, permiso del bot y nodo Telegram |
| Mensajes repetidos | Revisión de claves/eventos, estado estático, activación, reinicios y transiciones resuelto/reabierto |
| Telegram devuelve `chat not found` | Chat ID del destino, bot agregado al grupo y permiso de enviar mensajes |
| Telegram devuelve `401 Unauthorized` | Token de BotFather incorrecto/revocado; crear credencial nueva |
| D2 no aparece para importar | Comprobar que se descargó la versión actualizada del repositorio: **D2 ya tiene JSON** en `n8n/workflows/` |
| Un workflow no detecta datos recientes | Revisar umbral, frecuencia, timestamps, permisos de `agente_ia` y la consulta original del JSON |

## 12. Guardar cambios y completar las alertas faltantes

Cuando una alerta nueva esté terminada, exportarla desde n8n a un archivo JSON **sin credenciales ni tokens incorporados** y guardarla en `n8n/workflows/` con un nombre descriptivo, por ejemplo `R2 - [nombre de la alerta].json`. Añadir las evidencias de terminal, ejecución y Telegram a su carpeta de `evidencias/07_n8n_alerts/`; actualizar la tabla del apartado 9 y registrar si la alerta fue probada o sigue pendiente. Confirmar que los JSON exportados no contienen direcciones de chat privadas innecesarias ni otros valores sensibles.

Para subir **solo la documentación, JSON y evidencias permitidas**, revisar antes:

```powershell
git status
git diff --stat
git check-ignore -v .env .secrets/rbac-secrets.json n8n/certificates/postgres.crt
```

No forzar la inclusión de secretos con `git add -f`. Coordinar el `git add`, commit y push con la rama y responsable del proyecto.

## 13. Referencias

- [Guía interna de instalación PostgreSQL](../postgres/README.md)
- [n8n: Docker](https://docs.n8n.io/hosting/installation/docker/)
- [n8n: importar y exportar workflows](https://docs.n8n.io/workflows/export-import/)
- [n8n: datos estáticos de workflows](https://docs.n8n.io/code/cookbook/builtin/get-workflow-static-data/)
- [Telegram BotFather](https://core.telegram.org/bots/features#botfather)
- [Telegram Bot API: getUpdates](https://core.telegram.org/bots/api#getupdates)
