# PostgreSQL — NutriAnimales

Esta guía permite iniciar la base de datos y conectar los componentes de NutriAnimales (n8n, bot de Telegram, monitoreo y otros servicios). **Los comandos se ejecutan en PowerShell desde la carpeta principal del repositorio**, donde está `docker-compose.yml`.

## 1. Requisitos

- Docker Desktop encendido, con contenedores Linux.
- PowerShell 7.2 o superior (`pwsh`).
- Git para obtener el proyecto.

Si vas a modificar código, se recomienda trabajar en una rama propia (`git switch -c feature/mi-funcionalidad`). **No necesitas cambiar a una rama específica para utilizar el sistema.**

## 2. Primera instalación (una sola vez por equipo)

Si ya configuraste la base y tienes los servicios funcionando, pasa directamente al **paso 3**.

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

Este comando crea las 12 tablas, carga datos de ejemplo, instala los triggers de auditoría y configura usuarios y permisos. **No lo ejecutes para actualizar una base que ya tiene datos**. Los volúmenes conservan la información entre reinicios.

## 3. Iniciar NutriAnimales en días posteriores

Una vez realizada la instalación inicial, basta con:

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml')
docker compose @compose up -d
docker compose @compose ps
```

No hace falta volver a crear certificados, usuarios o tablas.

## 4. ¿Qué usuario de PostgreSQL debe usar cada componente?

Las cuentas ya existen después de inicializar la base. **Los nombres de usuario son fijos; las contraseñas son privadas y distintas para cada instalación.** El responsable del entorno facilita la credencial correspondiente mediante un canal seguro o configura el secreto directamente en cada servicio.

| Cuenta PostgreSQL | Para qué se usa | Permisos principales |
|---|---|---|
| `agente_ia` | **n8n / componente de IA que consulta información** | Lectura (`SELECT`) de las ocho tablas de negocio; no modifica datos |
| `ti_db` | Tareas administrativas de aplicación, registro de respaldos y alertas | Lectura de tablas; inserción de registros en `backups` y `alertas_auditoria` |
| `auditor_db` | Consultas de auditoría | Lectura de `auditoria_datos`, `backups` y `alertas_auditoria` |
| `gerente_db` | Consultas gerenciales | Lectura de un reporte agregado de ventas |
| `postgres` | Instalación y mantenimiento de la base | Administrador; **no utilizar en n8n ni en servicios comunes** |

Los roles `rol_gerente`, `rol_ti` y `rol_auditor` agrupan permisos; **no son usuarios para iniciar sesión**. Las cuentas de PostgreSQL tampoco crean por sí solas usuarios o permisos en la interfaz web de n8n.

### Para quien desarrolla n8n y Telegram

- Configura una credencial **PostgreSQL** de n8n usando `agente_ia` cuando el flujo necesite consultar `clientes`, `ventas`, `productos` u otras tablas de negocio.
- `agente_ia` es **solo lectura**. Un flujo que necesite escribir no debe reutilizar esa cuenta ni obtener permisos administrativos: solicita una cuenta específica con los permisos mínimos requeridos.
- Si un flujo debe **registrar** una alerta o metadatos de respaldo, corresponde revisar el uso controlado de `ti_db` o una cuenta de servicio dedicada.
- Para consultar `auditoria_datos`, emplea una cuenta autorizada como `auditor_db`, según el diseño del flujo.
- Las consultas de monitoreo sobre vistas estadísticas de PostgreSQL, los logs y las alertas R1–R5/H1–H5/D1–D7 pueden requerir permisos o integraciones adicionales. **No se presupone que `agente_ia` tenga acceso a esas fuentes.** Coordinar ese acceso antes de activar los flujos.
- Las credenciales de Telegram y de proveedores de IA se configuran por separado en el servicio correspondiente; no son contraseñas de PostgreSQL.

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
| La base ya tiene tablas | Omitir la inicialización; no borrar volúmenes |

Para consultar el estado y los errores de arranque:

```powershell
docker compose -f docker-compose.yml -f docker-compose.postgres.yml ps -a
docker compose -f docker-compose.yml -f docker-compose.postgres.yml logs --tail=30 postgres
```

---

**Alcance:** esta guía prepara PostgreSQL y explica cómo conectarlo. La instalación de n8n, Telegram, Loki y otros servicios se documenta junto con los componentes de sus respectivos responsables.
