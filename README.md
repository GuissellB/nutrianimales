> PostgreSQL (Persona 2): [guía de instalación y conexión para el equipo](postgres/README.md). Consulte esa guía para la integración actual de PostgreSQL; el documento siguiente conserva la entrega de infraestructura de Persona 1.

\# NutriAnimales — Infraestructura y seguridad



\## 1. Descripción



Este proyecto forma parte de una iniciativa de seguridad para NutriAnimales. Esta entrega corresponde a la \*\*Persona 1: Susana Herrera\*\*, responsable de la infraestructura Docker, Nginx, SSL/TLS y medidas de hardening.



La configuración actual permite probar Nginx mediante HTTP y HTTPS en un entorno local. La integración completa con PostgreSQL y los demás componentes se realizará posteriormente con el equipo.



\## 2. Tecnologías utilizadas



\- Docker Desktop y Docker Compose

\- Nginx `1.28-alpine`

\- PostgreSQL `16-alpine` (declarado en Compose; pendiente de integración)

\- Certificados TLS autofirmados para pruebas locales

\- Git y GitHub

\- PowerShell en Windows



\## 3. Estructura del proyecto



```text

nutrianimales/

├── docker-compose.yml

├── .env.example

├── .gitignore

├── README.md

├── evidencias/

├── nginx/

│   └── default.conf

├── ssl/

├── postgres/

└── logs/

```



Los directorios `postgres/` y `logs/` están reservados para la integración posterior. El contenido puede variar conforme avance el proyecto.



\## 4. Requisitos previos



Instalar y comprobar:



\- Docker Desktop con el motor de contenedores iniciado.

\- Git.

\- PowerShell en Windows.



Los comandos siguientes se ejecutan desde la carpeta del proyecto.



\## 5. Configuración inicial



\### 5.1 Variables de entorno



Crear el archivo local `.env` a partir de `.env.example`:



```powershell

Copy-Item .env.example .env

notepad .env

```



Configurar valores locales adecuados antes de utilizar PostgreSQL. No subir `.env` a GitHub ni compartir contraseñas reales.



\### 5.2 Certificado TLS local



La clave privada y el certificado local no se incluyen en el repositorio. Cada integrante debe generarlos en su computadora.



Desde PowerShell, ejecutar:



```powershell

New-Item -ItemType Directory -Force .\\ssl

```



```powershell

docker run --rm -v "${PWD}/ssl:/certs" alpine:3.22 sh -c "apk add --no-cache openssl \&\& openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /certs/localhost.key -out /certs/localhost.crt -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'"

```



Este certificado es autofirmado y está destinado exclusivamente a pruebas locales. No utilizarlo como certificado de producción.



\## 6. Iniciar Nginx



Para iniciar únicamente el servicio de Nginx:



```powershell

docker compose up -d nginx

```



Comprobar el estado:



```powershell

docker compose ps

```



Validar la configuración:



```powershell

docker compose exec nginx nginx -t

```



Si se modifica `nginx/default.conf`, validar primero los cambios y recargar Nginx:



```powershell

docker compose exec nginx nginx -s reload

```



\## 7. Pruebas de funcionamiento



\### HTTP



Abrir en el navegador:



http://localhost:8080



O ejecutar:



```powershell

curl.exe -i http://localhost:8080

```



\### HTTPS



Abrir en el navegador:



https://localhost:8443



Como el certificado es autofirmado, las herramientas de prueba pueden advertir que no es confiable. Para comprobar la respuesta local mediante curl:



```powershell

curl.exe -k -I https://localhost:8443

```



La opción `-k` desactiva la validación del certificado en esa prueba. No debe utilizarse como solución para conexiones de producción.



\### Encabezados de seguridad



La configuración incluye:



\- `X-Frame-Options: DENY`

\- `X-Content-Type-Options: nosniff`

\- `Referrer-Policy: strict-origin-when-cross-origin`

\- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none';`

\- `Strict-Transport-Security: max-age=31536000` en el bloque HTTPS



HSTS indica al navegador que utilice HTTPS durante el periodo configurado. Su utilidad depende de que el certificado y el dominio sean confiables; la configuración local no equivale a una implementación de producción.



\## 8. Medidas de seguridad configuradas



\- Red Docker propia: `nutrianimales-net`.

\- PostgreSQL sin puertos publicados directamente en el host.

\- Montajes de configuración de Nginx y certificados como solo lectura.

\- Restricción de capacidades de Nginx mediante `cap\_drop` y `cap\_add`.

\- `no-new-privileges` para los servicios configurados.

\- Variables de entorno locales excluidas de Git.

\- Clave privada excluida de Git.

\- Permisos NTFS restringidos para el archivo `.env` local.



La red está configurada como `bridge`, no como red `internal`. La conectividad y el aislamiento deberán revisarse según las necesidades de la integración final.



\## 9. Estado de la integración



\### Configurado y probado en el entorno local



\- Nginx por HTTP y HTTPS.

\- Certificado autofirmado para Nginx.

\- Encabezados de seguridad, incluido HSTS.

\- Configuración Docker Compose válida.

\- PostgreSQL sin publicación de puertos en el archivo Compose.

\- Exclusión de archivos sensibles mediante `.gitignore`.



\### Pendiente de integración o verificación



\- Servicios N8N y pgAdmin y sus usuarios no-root.

\- Configuración y prueba de autenticación SCRAM en PostgreSQL.

\- SSL/TLS propio de PostgreSQL.

\- Usuario de solo lectura `agente\_ia`, en coordinación con la Persona 2.

\- Verificación de permisos del volumen de datos una vez creado.

\- Integración completa y pruebas conjuntas de los servicios.



Los puntos pendientes no deben considerarse completados hasta que se implementen y se documenten sus pruebas.



\## 10. Evidencias



Las capturas de las pruebas se almacenan en `evidencias/`, organizadas por categoría:



\- `01\_entorno/`: entorno de ejecución.

\- `02\_docker/`: servicios, puertos y red.

\- `03\_nginx/`: configuración y pruebas HTTP.

\- `04\_ssl/`: certificado y pruebas HTTPS.

\- `05\_hardening/`: encabezados, permisos y controles de seguridad.



Antes de compartir evidencias, verificar que no muestren contraseñas, archivos `.env` ni claves privadas.



\## 11. Buenas prácticas para Git



No incorporar al repositorio:



\- `.env`

\- Claves privadas (`\*.key`)

\- Certificados locales excluidos por `.gitignore`

\- Archivos de respaldo de configuración (`\*.bak`)



Cada integrante debe crear sus archivos de entorno y certificados locales. Antes de hacer `commit` o `push`, revisar el estado de Git y confirmar que no haya secretos incluidos.



\## 12. Responsabilidades



\- \*\*Persona 1:\*\* Docker, Nginx, SSL/TLS y hardening de infraestructura.

\- \*\*Persona 2:\*\* PostgreSQL, esquema, datos, triggers, RBAC y baseline.

\- \*\*Persona 3:\*\* N8N, Telegram y sus flujos.

\- \*\*Persona 4:\*\* Filebeat/Loki y flujos de auditoría.

\- \*\*Persona 5:\*\* pruebas de ataques, gestión de secretos, informe, README e integración final.



