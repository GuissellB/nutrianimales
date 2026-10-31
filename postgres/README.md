# PostgreSQL — NutriAnimales

Esta guía permite iniciar la base de datos y conectar los componentes de NutriAnimales (n8n, bot de Telegram, monitoreo y otros servicios). **Los comandos se ejecutan en PowerShell desde la carpeta principal del repositorio**, donde está `docker-compose.yml`.

## 1. Requisitos

- Docker Desktop encendido, con contenedores Linux.
- PowerShell 7.2 o superior (`pwsh`).
- Git para obtener el proyecto.

Si vas a modificar código, se recomienda trabajar en una rama propia (`git switch -c feature/mi-funcionalidad`). **No necesitas cambiar a una rama específica para utilizar el sistema.**

## 2. Primera instalación (una sola vez por equipo)

Si ya configuraste la base, **no repitas la primera instalación**. Para incorporar los permisos de monitoreo y `pg_stat_statements` a una instalación anterior, sigue el **[paso 3.1](#31-actualizar-una-base-ya-instalada-para-las-alertas-de-n8n)**. Para el uso diario, sigue el paso 3.

### 2.1 Crear configuración y certificados locales

```powershell
pwsh -NoProfile -File postgres/scripts/configurar-secretos.ps1
pwsh -NoProfile -File postgres/scripts/generar-certificados.ps1
pwsh -NoProfile -File postgres/scripts/generar-certificados.ps1 -OutputDirectory ./ssl -DnsName localhost -CertificateName localhost
```

El primer comando prepara `.env` y las credenciales de las cuentas de PostgreSQL. Los otros generan los certificados para PostgreSQL y Nginx. **No subas ni compartas `.env`, `.secrets/` o archivos `.key`.** Los generadores no deben ejecutarse de nuevo para reemplazar configuraciones ya existentes.

### 2.2 Iniciar Docker

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml')
docker compose @compose config --quiet
docker compose @compose up -d --wait --wait-timeout 120
docker compose @compose ps
```

Deberían aparecer `postgres` y `nginx` activos. Es normal que `postgres-tls-init` termine con `Exited (0)`: solo instala los certificados.

Nginx responde localmente en **https://localhost:8443**. El navegador puede mostrar una advertencia por el certificado autofirmado del entorno de desarrollo.

### 2.3 Crear la base y los usuarios

**Solo si es la primera vez y la base está vacía:**

```powershell
pwsh -NoProfile -File postgres/scripts/inicializar-postgres.ps1 -RbacSecretsFile .secrets/rbac-secrets.json
```

Este comando crea las 12 tablas, carga datos de ejemplo, instala los triggers de auditoría y configura usuarios, permisos de lectura de monitoreo y la extensión `pg_stat_statements`. El SQL `07_monitoreo_n8n.sql` se incorpora automáticamente a la instalación; no hay que ejecutarlo aparte. **No lo ejecutes para actualizar una base que ya tiene datos**. Los volúmenes conservan la información entre reinicios.

## 3. Iniciar NutriAnimales en días posteriores

Una vez realizada la instalación inicial, basta con:

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml')
docker compose @compose up -d
docker compose @compose ps
```

No hace falta volver a crear certificados, usuarios o tablas.

### 3.1 Actualizar una base ya instalada para las alertas de n8n

Este procedimiento es para quien ya tenía NutriAnimales instalado antes de agregar `pg_stat_statements`. **Conserva las tablas, filas, contraseñas, certificados y volúmenes existentes.** No ejecutar otra vez `inicializar-postgres.ps1` ni borrar volúmenes.

1. Obtener la versión actualizada del repositorio desde la rama que esté utilizando el equipo. Deben estar presentes el overlay actualizado, `07_monitoreo_n8n.sql` y `scripts/actualizar-monitoreo.ps1`.
2. Con Docker Desktop y el PostgreSQL existente en ejecución, reservar una interrupción breve de conexiones. Conservar un respaldo según el procedimiento del equipo; este script no genera respaldos.
3. Ejecutar desde la raíz:

```powershell
pwsh -NoProfile -File postgres/scripts/actualizar-monitoreo.ps1
if ($LASTEXITCODE -ne 0) { throw 'La actualización falló; revisar el error antes de continuar' }
```

El script comprueba que el proyecto use los mismos volúmenes de datos/TLS y las mismas credenciales. Recrea **solo PostgreSQL**, sin reiniciar Nginx ni eliminar volúmenes, para cargar `pg_stat_statements`. Después aplica el SQL 07 y las verificaciones SQL 06 dentro de una transacción. No carga otra vez el seed ni cambia contraseñas. También retira los permisos de creación y tablas temporales heredados de `PUBLIC` en instalaciones antiguas, de acuerdo con el RBAC actual; conserva el acceso de conexión existente. Si el SQL falla, se revierten sus cambios y se informa el error; la nueva configuración del contenedor permanece aplicada para poder corregir y reintentar.

Si PostgreSQL ya carga otras bibliotecas, el script se detiene antes de recrearlo cuando la nueva configuración las omitiría. Revisar `SHOW shared_preload_libraries;` y conservar sus nombres en el `.env` local, por ejemplo:

```dotenv
POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements,auto_explain
```

El ejemplo supone que ya utilizabas `auto_explain`; no es necesario agregarlo si no existe. Sin esta variable se carga únicamente `pg_stat_statements`. Tras corregir la lista se puede ejecutar de nuevo el actualizador. También se puede repetir una actualización completada: no duplica tablas ni datos. El procedimiento usa la imagen PostgreSQL 16 local y no descarga una versión nueva.

En otro proyecto Compose, invocar el script desde `pwsh` indicando los mismos archivos, proyecto y archivo de entorno usados para ese entorno:

```powershell
./postgres/scripts/actualizar-monitoreo.ps1 -ComposeFiles @('docker-compose.yml','docker-compose.postgres.yml') -ProjectName nombre-del-proyecto -EnvFile .env
```

El nombre de proyecto y los volúmenes deben corresponder a la instalación existente. El Compose principal tiene nombres de contenedor fijos; no se usa para levantar copias paralelas. `-EnvFile` controla la interpolación de Compose; el servicio principal conserva su `env_file: .env`.

## 4. ¿Qué usuario de PostgreSQL debe usar cada componente?

Las cuentas ya existen después de inicializar la base. **Los nombres de usuario son fijos; las contraseñas son privadas y distintas para cada instalación.** El responsable del entorno facilita la credencial correspondiente mediante un canal seguro o configura el secreto directamente en cada servicio.

| Cuenta PostgreSQL | Para qué se usa | Permisos principales |
|---|---|---|
| `agente_ia` | **Consultas y alertas de n8n** | Lectura de las ocho tablas de negocio, auditoría, backups, alertas, baseline y estadísticas; sin escritura ni administración |
| `ti_db` | Tareas administrativas de aplicación, registro de respaldos y alertas | Lectura de tablas; inserción de registros en `backups` y `alertas_auditoria` |
| `auditor_db` | Consultas de auditoría | Lectura de `auditoria_datos`, `backups` y `alertas_auditoria` |
| `gerente_db` | Consultas gerenciales | Lectura de un reporte agregado de ventas |
| `postgres` | Instalación y mantenimiento de la base | Administrador; **no utilizar en n8n ni en servicios comunes** |

Los roles `rol_gerente`, `rol_ti` y `rol_auditor` agrupan permisos; **no son usuarios para iniciar sesión**. Las cuentas de PostgreSQL tampoco crean por sí solas usuarios o permisos en la interfaz web de n8n.

### Para quien desarrolla n8n y Telegram

- Configura una credencial **PostgreSQL** de n8n usando `agente_ia` tanto para consultar datos de negocio como para los nodos de monitoreo. No se necesita un usuario adicional para esas consultas.
- `agente_ia` es **solo lectura**. Un flujo que necesite escribir no debe reutilizar esa cuenta ni obtener permisos administrativos: solicita una cuenta específica con los permisos mínimos requeridos.
- Si un flujo debe **registrar** una alerta o metadatos de respaldo, corresponde revisar el uso controlado de `ti_db` o una cuenta de servicio dedicada.
- Para consultar `auditoria_datos` desde estos flujos se puede usar `agente_ia`; `auditor_db` conserva su función de auditoría.
- La instalación incluye `pg_read_all_stats` para observar actividad de otras sesiones, además de permisos explícitos de lectura sobre `pg_stat_statements` y sus funciones de consulta. Los logs de autenticación, archivos de configuración y firewall requieren integración externa: no se concede acceso a archivos del servidor.
- Las credenciales de Telegram y de proveedores de IA se configuran por separado en el servicio correspondiente; no son contraseñas de PostgreSQL.

### Qué habilita esta lectura para las alertas

| Alertas o consulta | Fuente disponible para `agente_ia` |
|---|---|
| R1, D1, D6 y D7: consultas lentas y actividad masiva | `public.pg_stat_statements` |
| R2, R3, H4 y parte de D5: conexiones, horario y bloqueos | `pg_stat_activity`, `pg_locks` y estadísticas del servidor |
| R5 y H5: configuración y desviaciones | Parámetros visibles de `pg_settings` y `public.pg_settings_baseline` |
| H3: cambios de roles y permisos | Catálogos como `pg_roles`, `pg_auth_members` y ACL; el flujo debe comparar con el estado autorizado |
| D2 y D4: crecimiento y duplicados | `pg_stat_user_tables` y consultas a tablas de negocio; el crecimiento requiere comparar mediciones |
| D3: antigüedad del respaldo registrado | `public.backups`; esta tabla registra metadatos, no crea respaldos |
| Contexto de cambios y alertas | `public.auditoria_datos` y `public.alertas_auditoria` |
| R4, H1 y H2: autenticaciones fallidas, firewall y hashes de archivos | **Integración externa pendiente:** logs, Filebeat/Loki o un recolector autorizado |

Estos permisos habilitan las fuentes SQL; **no crean automáticamente los flujos ni demuestran las 17 alertas de extremo a extremo**. Las emulaciones que modifican datos o privilegios se ejecutan aparte con una cuenta autorizada; no se amplía escritura al agente para realizarlas.

Consideraciones para implementar los flujos:

- Usar consultas fijas y parámetros en los nodos PostgreSQL. `pg_read_all_stats` permite observar estadísticas de todo el clúster, incluso texto de consultas de otros usuarios; no equivale a limitar la visibilidad a una sola base. Filtrar por la base NutriAnimales al consultar la extensión y no enviar datos sensibles automáticamente a Telegram o a proveedores de IA.
- `rows`, `calls` y tiempos totales de `pg_stat_statements` son acumulativos por sentencia normalizada. Para alertar sobre un intervalo hay que guardar mediciones anteriores y comparar incrementos, considerando reinicios y entradas eliminadas. No interpretar `rows > 1000` como prueba de una única consulta que devolvió más de 1000 filas. La normalización tampoco prueba por sí sola la ausencia de `WHERE`.
- Un reinicio por sí solo no representa una alerta de ataque. La ampliación autorizada de permisos y las nuevas expectativas deben quedar registradas en la configuración que compare H3/H5.
- Se concede `SELECT` sobre las 12 tablas de aplicación y las vistas de la extensión, y `EXECUTE` únicamente sobre sus funciones de consulta. No se conceden escritura, creación de objetos, superusuario, lectura de archivos, cancelación de sesiones ni ejecución de `pg_stat_statements_reset`.
- Las contraseñas y sus verificadores no deben aparecer en logs ni estadísticas. El inicializador desactiva el seguimiento de su sesión durante la asignación de secretos.
- Esta credencial sirve para **consultar desde los flujos**. La base interna de n8n, el almacenamiento de memoria del chat o el registro de alertas que necesite escritura tienen una configuración y cuenta apropiadas para ese propósito.

### Comprobar la lectura desde la credencial del agente

Una vez instalado o actualizado, usar el cliente del apartado 5, que solicita la contraseña de `agente_ia`, y ejecutar en psql:

```sql
SELECT session_user, current_database();
SELECT count(*) FROM public.auditoria_datos;
SELECT name, valor_esperado FROM public.pg_settings_baseline ORDER BY name;
SELECT pid, usename, datname, state FROM pg_stat_activity;
SELECT queryid, calls, rows, mean_exec_time
FROM public.pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname=current_database())
ORDER BY mean_exec_time DESC LIMIT 5;
SELECT has_table_privilege(current_user,'public.productos','UPDATE') AS puede_modificar,
       has_table_privilege(current_user,'public.auditoria_datos','DELETE') AS puede_borrar,
       has_function_privilege(current_user,'public.pg_stat_statements_reset(oid,oid,bigint)','EXECUTE') AS puede_resetear;
```

Las dos primeras consultas de monitoreo deben ser accesibles; la última debe devolver **false / false / false**. Que la vista de estadísticas esté vacía al principio no significa un error: necesita actividad registrada. Las validaciones administrativas completas se ejecutan automáticamente al instalar y actualizar; probar además las consultas con la credencial real de n8n y tomar sus evidencias de Telegram cuando estén implementados los flujos.

## 5. Configurar la conexión desde Docker

Para un servicio en la red Docker de NutriAnimales:

| Campo | Valor |
|---|---|
| Host | `postgres` |
| Puerto | `5432` |
| Base de datos | Valor `POSTGRES_DB` del `.env` local (normalmente `nutrianimales_db`) |
| Usuario | La cuenta apropiada de la tabla anterior, por ejemplo `agente_ia` |
| Contraseña | Secreto de esa cuenta, configurado de forma privada |
| SSL/TLS | Activado, con validación del certificado y nombre del servidor (`verify-full` o equivalente) |

**Importante:** `postgres` es el nombre del host **dentro de Docker**. No uses `localhost` desde un contenedor para conectarte a la base, ni publiques el puerto `5432` al equipo anfitrión. El servicio cliente necesita acceso a la red `nutrianimales-net` y al **certificado público** de PostgreSQL para validar TLS; nunca a la clave privada del servidor.

El proyecto incluye un cliente de referencia para comprobar manualmente una conexión autorizada:

```powershell
$cliente = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml','-f','docker-compose.client.yml')
docker compose @cliente --profile tools run --rm pg-client
```

El cliente solicita las credenciales correspondientes. Para incorporar n8n u otro contenedor, utiliza la misma red Docker y configura las credenciales mediante los mecanismos de secretos que admita ese servicio. **No pegues contraseñas directamente en archivos versionados.**

## 6. Problemas frecuentes

| Problema | Qué revisar |
|---|---|
| Docker no inicia | Docker Desktop abierto y en modo contenedores Linux |
| Nginx no encuentra `localhost.crt` | Generar los certificados locales de Nginx del paso 2.1 |
| `password authentication failed` | Cuenta, contraseña de **esta instalación** y base de datos |
| Error de certificado o nombre del servidor | Host `postgres` y certificado público correcto; mantener validación TLS |
| `permission denied` al ejecutar SQL | Consultar la tabla de usuarios y solicitar una cuenta con los permisos apropiados |
| La base ya tiene tablas | Omitir la inicialización; para incorporar monitoreo usar el paso 3.1 |
| `relation pg_stat_statements does not exist` | Aplicar la actualización en la base correcta; habilitar la biblioteca no crea por sí sola la extensión |
| `pg_stat_statements must be loaded via shared_preload_libraries` | Aplicar el overlay actualizado y recrear PostgreSQL con el procedimiento del paso 3.1 |
| `permission denied` sobre una función de estadísticas | Ejecutar el actualizador, que concede únicamente las funciones de lectura necesarias |
| La lista de bibliotecas o las credenciales difieren | Revisar `.env` y el proyecto seleccionado antes de continuar; no borrar datos para resolverlo |

Para consultar el estado y los errores de arranque:

```powershell
docker compose -f docker-compose.yml -f docker-compose.postgres.yml ps -a
docker compose -f docker-compose.yml -f docker-compose.postgres.yml logs --tail=30 postgres
```

---

**Alcance:** esta guía prepara PostgreSQL y explica cómo conectarlo. La instalación de n8n, Telegram, Loki y otros servicios se documenta junto con los componentes de sus respectivos responsables.

### Validación de esta actualización

El 31 de octubre de 2026 se verificaron PostgreSQL 16.15, la extensión 1.10 y Compose 2.34.0. Se realizaron pruebas en dos proyectos aislados que se eliminaron al terminar, conservando el entorno original:

| Prueba ejecutada | Resultado |
|---|---|
| Instalación limpia con el inicializador actualizado | Aprobada: 12 tablas, extensión activa y seis parámetros de baseline |
| Actualización desde la versión anterior, incluido TEMP heredado de PUBLIC | Aprobada, sin cambios de filas ni contraseñas |
| Segunda ejecución del actualizador | Aprobada, sin duplicar datos |
| Conservación de otra biblioteca precargada (`auto_explain`) | Aprobada; rechazo previo si la configuración intentaba quitarla |
| Conexión real de `agente_ia` desde un contenedor cliente | Aprobada con SCRAM, TLS `verify-full` y channel binding |
| Lectura de negocio, auditoría, baseline, actividad, bloqueos, roles y estadísticas | Aprobada |
| Consulta lenta ejecutada por otro usuario y visible al agente | Aprobada en instalación nueva y actualizada |
| 13 intentos de escritura, creación de objetos/roles, escalada y reset de estadísticas por escenario | Rechazados como se esperaba |
| Contraseña incorrecta y conexión sin TLS | Rechazadas como se esperaba |
| Verificadores SCRAM en estadísticas y secretos en logs de las pruebas | No encontrados |

Después se aplicó el actualizador a la base local: se conservaron las filas y el contenido de las 11 tablas de datos/auditoría, las cuatro contraseñas RBAC y los volúmenes de datos/TLS. El baseline se actualizó a seis parámetros. Se generó antes un respaldo local con `pg_dump` y se comprobó su listado con `pg_restore --list`; esto no sustituye una prueba completa de restauración. Nginx no se reinició y respondió HTTP 200 / HTTPS 200; la prueba HTTPS local omitió la validación del certificado autofirmado de Nginx, mientras las conexiones PostgreSQL sí verificaron certificado y hostname.

La primera aplicación local se detuvo y revirtió su SQL al detectar TEMP heredado de PUBLIC; se incorporó ese caso a la migración, se volvió a probar en aislamiento y la aplicación final terminó correctamente. Las pruebas descritas validan **PostgreSQL y sus permisos**, no la ejecución de los 17 flujos ni el envío real de Telegram, que requieren la integración de n8n del equipo.

### Referencias técnicas

- [PostgreSQL 16: pg_stat_statements](https://www.postgresql.org/docs/16/pgstatstatements.html).
- [PostgreSQL 16: roles predefinidos y alcance de pg_read_all_stats](https://www.postgresql.org/docs/16/predefined-roles.html).
