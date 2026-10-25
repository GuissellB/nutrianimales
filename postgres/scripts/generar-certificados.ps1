#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../certs'),
    [ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$DnsName = 'postgres',
    [ValidateSet('server', 'localhost')][string]$CertificateName = 'server',
    [ValidateRange(2, 825)][int]$Days = 365
)
. "$PSScriptRoot/common.ps1"
$certs = [IO.Path]::GetFullPath($OutputDirectory)
$null = New-Item -ItemType Directory -Path $certs -Force
foreach ($suffix in @('key', 'crt')) {
    if (Test-Path -LiteralPath "$certs/$CertificateName.$suffix") { throw 'Ya existen certificados. No se reemplazaran.' }
}
Protect-SecretDirectory $certs
$command = @'
set -eu
apk add --no-cache openssl >/dev/null
umask 077
stage=$(mktemp -d /certs/.generacion-XXXXXX)
trap 'rm -f "$stage/key" "$stage/crt"; rmdir "$stage"' EXIT
openssl req -x509 -nodes -newkey rsa:3072 -sha256 -keyout "$stage/key" -out "$stage/crt" -days "$1" -subj "/CN=$2" -addext "subjectAltName=DNS:$2" -addext 'basicConstraints=critical,CA:TRUE' 2>/dev/null
openssl x509 -in "$stage/crt" -checkend 86400 -noout >/dev/null
# No reemplazar archivos preexistentes, incluso si otra ejecucion se adelanto.
set -C
cat "$stage/key" > "/certs/$3.key"
cat "$stage/crt" > "/certs/$3.crt"
'@
$null = Invoke-Docker -Arguments @('run', '--rm', '--mount', "type=bind,source=$certs,target=/certs", 'alpine:3.22', 'sh', '-c', $command, '--', "$Days", $DnsName, $CertificateName)
Write-Host "Certificado autofirmado generado para DNS:$DnsName en $certs. Proteja la clave privada con ACL locales."
