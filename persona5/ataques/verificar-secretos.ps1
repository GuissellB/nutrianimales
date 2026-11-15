<# Auditoría de higiene de secretos: comprobaciones de solo lectura.
Ejecutar desde cualquier directorio con PowerShell 7. No imprime el contenido de .env.
#>
. "$PSScriptRoot/_comun.ps1"
Set-Location $script:RepoRoot
Write-Paso '[1] .env ignorado por Git'
& git check-ignore -v .env
Write-Paso '[2] Archivos sensibles rastreados (resultado esperado: vacío)'
& git ls-files -- .env .secrets ':(glob)**/*.key'
Write-Paso '[3] Permisos de .env según SO'
if (Test-Path .env) {
  if ($IsWindows) { & icacls.exe .env }
  else { & ls -l .env }
} else { Write-Warning '.env no se encuentra en esta máquina; no se verificaron permisos.' }
Write-Paso '[4] Patrones de tokens de Groq/Telegram y llaves privadas en archivos Git'
& git grep -nIE 'gsk_[A-Za-z0-9]{10,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -- . ":!persona5/ataques/verificar-secretos.ps1"
Write-Paso '[5] Revisar historial por posibles filtraciones (NO compartir el parche de Git)'
& git log --all --format='%h %s' -G'gsk_[A-Za-z0-9]{10,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}' -- .
Write-Host 'Si hubo filtración, revocar el secreto aunque se haya eliminado de Git.'
