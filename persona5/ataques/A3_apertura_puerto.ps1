<#
A3 - UFW 5432. Docker Desktop (Windows/macOS): MODO EMULADO, no toca firewall.
En una VM Linux de laboratorio: -RealLinux -ConfirmarLaboratorio ejecuta
sudo ufw allow 5432/tcp y lo revierte automáticamente al finalizar la ventana.
La marca de evento permite que H1 vea el cambio en el demostrador de n8n.
No monitoriza reglas ajenas a este script: limitación declarada.
#>
param(
    [switch]$RealLinux,
    [switch]$ConfirmarLaboratorio,
    [ValidateRange(30,300)][int]$SegundosVentana = 120
)
. "$PSScriptRoot/_comun.ps1"
Assert-Laboratorio -ConfirmarLaboratorio:$ConfirmarLaboratorio
$log = Join-Path $script:PersonaRoot 'observability/logs/ufw.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$creada = $false
try {
    if ($RealLinux) {
        if (-not $IsLinux) { throw 'El modo UFW real solo está permitido desde Linux.' }
        if (-not (Get-Command ufw -ErrorAction SilentlyContinue)) { throw 'ufw no está instalado.' }
        & sudo ufw status | Out-Host
        if (& sudo ufw status | Select-String -Pattern '^5432/tcp\s+ALLOW' -Quiet) {
            throw 'La regla 5432/tcp ya existía: no se modificará ni eliminará una regla ajena.'
        }
        Write-Paso "A3: abrir regla UFW REAL para laboratorio $(Get-Hora)"
        & sudo ufw allow 5432/tcp
        if ($LASTEXITCODE -ne 0) { throw 'Falló ufw allow.' }
        $creada = $true
    } else {
        Write-Paso "A3: registrar apertura UFW EMULADA; sin modificar firewall $(Get-Hora)"
    }
    $origen = if ($RealLinux) { 'UFW_REAL_LINUX' } else { 'UFW_EMULADO_WINDOWS_DOCKER' }
    $linea = "$(Get-HoraUTC) | PERSONA5 UFW CHANGE ALLOW 5432/tcp | $origen"
    [System.IO.File]::AppendAllText($log, "$linea`n", [System.Text.UTF8Encoding]::new($false))
    Registrar-Evento A3 INICIO $linea
    Write-Host $linea
    Write-Host "Capturar alerta H1 y bitácora durante $SegundosVentana segundos."
    Start-Sleep -Seconds $SegundosVentana
} finally {
    if ($creada) {
        Write-Paso "A3: REVERTIR regla UFW $(Get-Hora)"
        & sudo ufw delete allow 5432/tcp
        if ($LASTEXITCODE -ne 0) { Write-Warning 'No se pudo revertir la regla UFW; ejecutar manualmente: sudo ufw delete allow 5432/tcp' }
    } else {
        Write-Paso 'A3: emulación finalizada; nunca se abrió el puerto del host'
    }
    Registrar-Evento A3 RESPUESTA 'Cierre automático si modo LinuxReal; no hubo cambio de firewall en modo emulado.'
}
Write-Host 'Verificar: Get-Content persona5/observability/logs/ufw.log -Tail 5'
Write-Host 'No se esperan filas en auditoria_datos: UFW es configuración del host.'
