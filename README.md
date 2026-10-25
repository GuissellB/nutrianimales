# NutriAnimales

Infraestructura y seguridad para el proyecto NutriAnimales S.A., desarrollada con **Docker, Nginx y PostgreSQL 16**.

> **¿Necesitas configurar la base de datos o conectar tu servicio?**
>
> Consulta la **[guía de PostgreSQL para el equipo](postgres/README.md)**. Allí están los requisitos, la primera instalación, los secretos, los certificados, los usuarios y permisos, la conexión desde Docker y la solución de problemas.
>
> Si la base ya está instalada, ve directamente a **[Iniciar NutriAnimales en días posteriores](postgres/README.md#3-iniciar-nutrianimales-en-días-posteriores)**. La configuración de la base se mantiene en esa guía.

## Documentación y archivos de referencia

| Necesitas… | Consulta |
|---|---|
| Instalar PostgreSQL y configurar sus credenciales y certificados | [Guía de PostgreSQL](postgres/README.md#2-primera-instalación-una-sola-vez-por-equipo) |
| Elegir la cuenta de base de datos para tu componente | [Usuarios y permisos](postgres/README.md#4-qué-usuario-de-postgresql-debe-usar-cada-componente) |
| Conectar n8n u otro servicio a la base | [Conexión desde Docker](postgres/README.md#5-configurar-la-conexión-desde-docker) |
| Consultar la infraestructura de Nginx y PostgreSQL | [Compose principal](docker-compose.yml) |
| Revisar la configuración segura de PostgreSQL | [Overlay de PostgreSQL](docker-compose.postgres.yml) |
| Consultar el cliente PostgreSQL de referencia | [Compose del cliente](docker-compose.client.yml) |
| Revisar las capturas de la entrega | [Evidencias](evidencias/) · [PostgreSQL](evidencias/06_postgresql/Fotos/) |

## Componentes del entorno

| Componente | Estado y acceso |
|---|---|
| **Nginx** | HTTP en `http://localhost:8080` y HTTPS en `https://localhost:8443` |
| **PostgreSQL 16** | TLS y SCRAM-SHA-256; acceso desde la red Docker, sin publicar el puerto 5432 al host |
| **Base NutriAnimales** | Esquema, datos de ejemplo, auditoría, roles y baseline de seguridad |
| **n8n, Telegram y monitoreo** | Integración a cargo de sus respectivos responsables |

Los certificados autofirmados se utilizan para el entorno local de desarrollo.

## Estructura del repositorio

```text
nutrianimales/
├── README.md                    # Punto de entrada y enlaces para el equipo
├── docker-compose.yml           # Infraestructura principal
├── docker-compose.postgres.yml  # TLS, autenticación y configuración PostgreSQL
├── docker-compose.client.yml    # Cliente de conexión opcional
├── .env.example                 # Referencia de configuración local
├── nginx/
│   └── default.conf             # Configuración HTTP/HTTPS
├── postgres/
│   ├── README.md                # Instalación y conexión a la base de datos
│   ├── 01_schema.sql … 06_verificaciones.sql
│   ├── pg_hba.conf              # Reglas de autenticación
│   └── scripts/                # Configuración, certificados e instalación
└── evidencias/                  # Capturas por componente
```

Los secretos y certificados de cada equipo se generan localmente siguiendo la guía de PostgreSQL; no forman parte del repositorio.

## Consultar Nginx

Después de seguir la guía de instalación, estos comandos permiten comprobar el estado de los servicios y la configuración de Nginx. Ejecutarlos en PowerShell desde la raíz del proyecto:

```powershell
$compose = @('-f','docker-compose.yml','-f','docker-compose.postgres.yml')
docker compose @compose ps -a
docker compose @compose exec nginx nginx -t
curl.exe -i http://localhost:8080
```

Para comprobar HTTPS con el certificado local autofirmado:

```powershell
curl.exe -k -I https://localhost:8443
```

La opción `-k` omite la validación del certificado únicamente en esta comprobación local de Nginx. La conexión a PostgreSQL se configura con validación de certificado y nombre del servidor, según su guía.

Si se modifica `nginx/default.conf`, validar antes de recargar:

```powershell
docker compose @compose exec nginx nginx -t
if ($LASTEXITCODE -ne 0) { throw 'Revisar la configuración de Nginx antes de recargar' }
docker compose @compose exec nginx nginx -s reload
```

## Seguridad y conservación de datos

- Red Docker compartida: `nutrianimales-net`.
- PostgreSQL sin puerto publicado al host; los servicios se conectan mediante `postgres:5432` dentro de Docker.
- Configuraciones y certificados montados en solo lectura donde corresponde.
- Restricción de capacidades de Nginx y uso de `no-new-privileges`.
- Encabezados de seguridad en Nginx: CSP, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` y HSTS en HTTPS.
- Cuentas PostgreSQL con permisos según su función; las aplicaciones no deben usar el administrador.
- `.env`, `.secrets/`, claves privadas, certificados locales y respaldos excluidos de Git.

**Conservar los volúmenes existentes.** No volver a inicializar una base con datos ni ejecutar `docker compose down -v` sobre el proyecto de trabajo. Antes de publicar capturas o cambios, comprobar que no incluyan secretos.

La red principal utiliza el controlador `bridge`; la incorporación de nuevos servicios se coordina con el equipo.

## Evidencias de la entrega

| Carpeta | Contenido |
|---|---|
| [01_entorno](evidencias/01_entorno/) | Entorno de ejecución |
| [02_docker](evidencias/02_docker/) | Servicios, puertos y red |
| [03_nginx](evidencias/03_nginx/) | Configuración y pruebas HTTP |
| [04_ssl](evidencias/04_ssl/) | Certificados y pruebas HTTPS |
| [05_hardening](evidencias/05_hardening/) | Encabezados, permisos y controles de seguridad |
| [06_postgresql](evidencias/06_postgresql/Fotos/) | Esquema, datos, auditoría, RBAC, TLS y baseline |

## Responsabilidades del equipo

| Persona | Responsabilidad |
|---|---|
| **1 — Susana Herrera** | Docker, Nginx, SSL/TLS y hardening de infraestructura |
| **2 — Guissell Betancur** | PostgreSQL, esquema, datos, auditoría, RBAC y baseline |
| **3** | n8n, Telegram y sus flujos |
| **4** | Filebeat/Loki y flujos de auditoría |
| **5** | Pruebas de ataques, gestión de secretos, informe e integración final |
