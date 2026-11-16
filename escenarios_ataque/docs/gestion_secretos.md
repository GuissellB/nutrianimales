# Política de secretos — Sección 9, NutriAnimales S.A.

El procedimiento del profesor (p. 12) asume secretos almacenados en `.env`, pero las credenciales de bot y base pueden estar gestionadas por n8n; **la ubicación real debe confirmarse con Persona 3 antes de la demo**.

| Secreto | Almacenamiento recomendado | Rotación | Revocación |
|---|---|---|---|
| `POSTGRES_PASSWORD` | `.env` local, ignorado por Git | Cada 6 meses o ante sospecha | ALTER ROLE como administrador y actualizar variables efectivas; actualizar servicios dependientes |
| Contraseñas `agente_ia`, `ti_db`, `auditor_db`, `gerente_db` | `.secrets/rbac-secrets.json` generado localmente; credenciales n8n | Cada 6 meses o compromiso | Cambiar contraseña en PostgreSQL, actualizar credenciales n8n y verificar conexiones |
| Groq API key | Credenciales n8n (o `.env` solo si así está desplegado) | Cada 90 días o compromiso | Revocar en consola Groq, generar otra y actualizar ubicación real |
| Telegram Bot Token | Credencial de Telegram en n8n | Ante compromiso | `@BotFather` → `/revoke` → actualizar credencial n8n |
| `N8N_ENCRYPTION_KEY` | `.env` fuera de Git | Ante compromiso, con backup planificado | Reconfigurar cuidadosamente: cambiarla puede impedir descifrar credenciales anteriores |
| Claves TLS | Directorios certificados locales, fuera de Git | Según política y vigencia | Regenerar y renovar certificados de servicio |

## Checklist

1. Comprobar que `.env`, `.secrets` y claves están excluidos por `.gitignore`.
2. Comprobar los permisos locales de `.env` (Linux/macOS: preferiblemente `chmod 600`; Windows: ACL con acceso reducido). No cambiar ACLs de compañeros sin permiso.
3. Usar las credenciales guardadas en n8n; no copiar tokens a JSON de workflows ni al repositorio.
4. Nunca subir capturas que contengan tokens ni usar una API key real para demostrar una filtración.
5. Si un secreto llegó a Git o se compartió, revocarlo incluso si el commit se elimina.

## Demo obligatoria de rotación Groq (solo clave de prueba)

1. Mostrar respuesta exitosa del bot con la clave vigente.
2. Revocar una **clave creada para la demostración** desde la consola Groq.
3. Ejecutar nuevamente una consulta al bot y capturar la falla de autenticación en n8n.
4. Crear una nueva clave de prueba y actualizar **la credencial real usada por el bot**.
5. Confirmar que el bot vuelve a responder y guardar capturas de los cuatro hitos pedidos por la rúbrica.

Si el equipo almacena la key vía `.env`, la mera instrucción `docker compose restart n8n` puede **no cargar nuevos valores de entorno** en un contenedor existente. Aplicar `docker compose up -d --force-recreate n8n` con la configuración correcta, sin eliminar PostgreSQL ni volúmenes, después de coordinar el cambio con Persona 3.

Prueba local de higiene: `pwsh -File escenarios_ataque/ataques/verificar-secretos.ps1`. El script no muestra los valores de `.env`.
