$ErrorActionPreference = "Stop"

$certs = Join-Path (Get-Location).Path "postgres\certs"

New-Item -ItemType Directory -Path $certs -Force | Out-Null

if ((Test-Path "$certs\server.key") -or
    (Test-Path "$certs\server.crt")) {
    Write-Host "Ya existen certificados. No se reemplazaran."
    exit 1
}

docker run --rm `
    -v "${certs}:/certs" `
    alpine:3.20 `
    sh -c "apk add --no-cache openssl > /dev/null && openssl req -x509 -nodes -newkey rsa:2048 -keyout /certs/server.key -out /certs/server.crt -days 365 -subj '/CN=postgres' -addext 'subjectAltName=DNS:postgres'"

if ($LASTEXITCODE -ne 0) {
    throw "Error al generar certificados."
}

Write-Host "Certificados TLS generados correctamente."