# NutriAnimales - Instalacion inicial PostgreSQL
# Ejecutar una sola vez, sobre una base NUEVA.

$ErrorActionPreference = "Stop"

$compose = @(
    "-f", "docker-compose.yml",
    "-f", "docker-compose.postgres.yml"
)

$contenedor = docker compose @compose ps -q postgres

if (-not $contenedor) {
    throw "PostgreSQL no esta iniciado."
}

Write-Host "ATENCION: Solo usar con una base nueva y vacia."
$confirmacion = Read-Host "Escribe INSTALAR para continuar"

if ($confirmacion -cne "INSTALAR") {
    Write-Host "Instalacion cancelada."
    exit
}

$archivos = @(
    "01_schema.sql",
    "02_seed.sql",
    "03_auditoria.sql",
    "04_rbac.sql",
    "05_baseline.sql"
)

foreach ($archivo in $archivos) {
    Write-Host "Ejecutando $archivo ..."

    docker cp "postgres/$archivo" "${contenedor}:/tmp/$archivo"

    if ($LASTEXITCODE -ne 0) {
        throw "Error al copiar $archivo"
    }

    docker compose @compose exec -it postgres `
        psql -h 127.0.0.1 `
        -U postgres `
        -d nutrianimales_db `
        -W `
        -v ON_ERROR_STOP=1 `
        -f "/tmp/$archivo"

    if ($LASTEXITCODE -ne 0) {
        throw "Error durante la ejecucion de $archivo"
    }
}

Write-Host "Scripts SQL ejecutados correctamente."
Write-Host "PENDIENTE: asignar contrasenas a usuarios RBAC y ejecutar verificaciones."