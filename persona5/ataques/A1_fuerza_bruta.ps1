<#
A1 - FUERZA BRUTA SSH REAL, NO CONTRA POSTGRESQL.
Realiza hasta 20 logins fallidos contra un servidor OpenSSH de laboratorio
que escucha EXCLUSIVAMENTE en 127.0.0.1 dentro de su propio contenedor.
El servidor registra los intentos en persona5/observability/logs/ssh.log.
R4 lee el resumen de eventos de esa bitácora mediante la API interna.
#>
param([ValidateRange(1,20)][int]$Intentos = 20, [switch]$ConfirmarLaboratorio)
. "$PSScriptRoot/_comun.ps1"
Assert-Laboratorio -ConfirmarLaboratorio:$ConfirmarLaboratorio
Assert-SSH
Write-Paso "A1 inicio SSH: $(Get-Hora)"
Registrar-Evento -Escenario A1 -Fase INICIO -Detalle "Intentos SSH configurados: $Intentos"
& docker exec $script:ContenedorSSH /usr/local/bin/ataque_controlado.sh $Intentos
if ($LASTEXITCODE -ne 0) { throw 'Falló la simulación SSH controlada.' }
Registrar-Evento -Escenario A1 -Fase FIN -Detalle 'Intentos SSH finalizados; verificar alerta R4 y logs.'
Write-Paso "A1 fin: $(Get-Hora)"
Write-Host "Verificar log: Get-Content persona5/observability/logs/ssh.log -Tail 25"
Write-Host 'La detección debe ser > 5 intentos en los últimos 10 min, alerta Telegram R4 en < 5 min.'
Write-Host 'Respuesta: comprobar cuenta y origen en log; contenedor SSH solo escucha internamente.'
Write-Host 'No se esperan filas en auditoria_datos: sshd no ejecuta DML de PostgreSQL.'
