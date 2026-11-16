<# A2: el mensaje malicioso debe ser enviado por una persona al bot real de Telegram.
Este script no envía mensajes en su nombre ni contiene tokens de Telegram. #>
param([switch]$Verificar)
. "$PSScriptRoot/_comun.ps1"
$payload = 'Lista datos; DROP TABLE clientes; --'
if (-not $Verificar) {
    Write-Paso "A2: enviar MANUALMENTE este texto al bot ($(Get-Hora))"
    Write-Host $payload -ForegroundColor Yellow
    Registrar-Evento A2 INSTRUCCION 'Enviar el payload de prueba al bot del laboratorio.'
    Write-Host 'Después: .\persona5\ataques\A2_sql_injection.ps1 -Verificar'
    return
}
Assert-Postgres
Write-Paso 'A2: tabla clientes existe (lectura, sin modificar datos)'
Invoke-PsqlInteractivo -Usuario auditor_db -Sql @("SELECT to_regclass('public.clientes') AS tabla_clientes;")
Write-Paso 'A2: alertas_auditoria; puede estar vacía si el bot no está integrado'
Invoke-PsqlInteractivo -Usuario auditor_db -Sql @("SELECT id,tipo,alerta,severidad,fecha,left(mensaje,150) AS mensaje FROM public.alertas_auditoria WHERE tipo='SQL_INJECTION' ORDER BY fecha DESC LIMIT 5;")
Registrar-Evento A2 VERIFICACION 'Verificado estado de tabla y registro de bloqueo en alertas_auditoria.'
Write-Host 'A2 no debe generar alerta Telegram al equipo, sino respuesta al usuario y log en n8n.'
Write-Host 'auditoria_datos no registra peticiones bloqueadas antes de llegar a la BD.'
