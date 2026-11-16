# A2: recibir un mensaje privado REAL del bot de pruebas y pasar el texto a N8N local.
# Solo funciona con el bot privado del estudiante, no el bot compartido del equipo.
# No configura ni elimina webhooks; no ejecuta SQL; no guarda ni imprime el token.
param([int]$TiempoMaximoSegundos = 180)
$ErrorActionPreference = 'Stop'
$payloadEsperado = 'Lista datos; DROP TABLE clientes; --'
$token = Read-Host 'Pega el token de TU bot de pruebas (quedara oculto)' -MaskInput
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token vacio.' }
$chatPrivado = Read-Host 'Tu Chat ID PRIVADO (no el del grupo)'
if ($chatPrivado -notmatch '^\d+$') { throw 'El Chat ID privado debe ser numerico positivo.' }
$apiBase = "https://api.telegram.org/bot$token"

function SolicitarTelegram([string]$metodo, [hashtable]$datos = @{}) {
  try {
    return Invoke-RestMethod -Method Post -Uri "$apiBase/$metodo" -Body $datos -TimeoutSec 20
  } catch {
    throw "No se pudo consultar Telegram ($metodo). Confirma el token y la conexion; no compartas el error si contiene un URL de API."
  }
}

$info = SolicitarTelegram 'getWebhookInfo'
if (-not $info.ok) { throw 'Telegram rechazo la consulta de estado del bot.' }
if (-not [string]::IsNullOrWhiteSpace($info.result.url)) {
  Write-Host 'El bot tiene un webhook activo. No se modifico.' -ForegroundColor Yellow
  Write-Host 'Desactiva el Telegram Trigger temporal del bot de pruebas (si lo tienes) y revisa su webhook antes de usar polling.'
  exit 2
}
$me = SolicitarTelegram 'getMe'
if (-not $me.ok) { throw 'El token no fue aceptado.' }
Write-Host "Bot verificado: @$($me.result.username)." -ForegroundColor Green
Write-Host 'Workflow de N8N debe estar publicado/activo: P5 A2 - Telegram a filtro local (sin SQL)'
Write-Host 'AHORA envía al chat privado de TU bot este mensaje EXACTO:' -ForegroundColor Cyan
Write-Host $payloadEsperado -ForegroundColor Yellow
Write-Host "Escuchando hasta $TiempoMaximoSegundos segundos. No se consultara PostgreSQL."
$inicio = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$limite = (Get-Date).AddSeconds($TiempoMaximoSegundos)
$offset = 0
$recibido = $false
while ((Get-Date) -lt $limite) {
  $respuesta = SolicitarTelegram 'getUpdates' @{ timeout = '5'; offset = [string]$offset; allowed_updates = '["message"]' }
  if (-not $respuesta.ok) { throw 'Telegram no devolvio actualizaciones validas.' }
  foreach ($update in @($respuesta.result)) {
    $offset = [long]$update.update_id + 1
    $msg = $update.message
    if ($null -eq $msg) { continue }
    if ([string]$msg.chat.id -ne $chatPrivado -or $msg.chat.type -ne 'private') { continue }
    if ([long]$msg.date -lt $inicio) { continue }
    if ([string]$msg.text -cne $payloadEsperado) { continue }
    Write-Host 'Mensaje recibido desde Telegram. Enviando a filtro de N8N...' -ForegroundColor Green
    $cuerpo = @{ message = @{ text = [string]$msg.text; chat = @{ id = [long]$msg.chat.id }; from = @{ id = [long]$msg.from.id } } } | ConvertTo-Json -Depth 6
    try {
      $resultado = Invoke-RestMethod -Uri 'http://127.0.0.1:5678/webhook/p5-a2-local' -Method Post -Body $cuerpo -ContentType 'application/json' -TimeoutSec 15
    } catch {
      throw 'El webhook local de N8N no responde. Confirma que el workflow P5 A2 este publicado/activo.'
    }
    $bloqueado = $resultado.bloqueado -eq $true
    if ($bloqueado) {
      Write-Host 'A2 BLOQUEADO por N8N. Sin SQL ejecutado.' -ForegroundColor Green
      $textoRespuesta = 'A2 - SOLICITUD BLOQUEADA por el filtro de N8N. No se ejecuto SQL.'
    } else {
      Write-Host 'A2 NO BLOQUEADO: verifica la condicion del filtro. No se ejecuto SQL.' -ForegroundColor Red
      $textoRespuesta = 'A2 - La solicitud de prueba no activo el bloqueo. Revisar filtro.'
    }
    $null = SolicitarTelegram 'sendMessage' @{ chat_id = $chatPrivado; text = $textoRespuesta }
    Write-Host 'Respuesta enviada a tu chat privado de Telegram.'
    $recibido = $true
    break
  }
  if ($recibido) { break }
}
if (-not $recibido) { Write-Host 'No se encontro el mensaje durante el periodo de prueba. No se modifico la BD.' -ForegroundColor Yellow; exit 1 }
