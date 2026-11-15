# Utilidades comunes de Persona 5. PowerShell 7.2+. Ejecutar desde cualquier carpeta.
$ErrorActionPreference = 'Stop'
$script:PersonaRoot = Split-Path -Parent $PSScriptRoot
$script:RepoRoot = Split-Path -Parent $script:PersonaRoot
$script:Contenedor = 'nutrianimales-postgres'
$script:Db = 'nutrianimales_db'
$script:ContenedorSSH = 'nutrianimales-persona5-ssh'

function Get-Hora { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz') }
function Get-HoraUTC { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function Write-Paso([string]$Texto) { Write-Host "`n=== $Texto" -ForegroundColor Cyan }

function Assert-Laboratorio([switch]$ConfirmarLaboratorio) {
    if (-not $ConfirmarLaboratorio) {
        throw 'Ejecutar solo en el entorno propio y aislado. Añadir -ConfirmarLaboratorio para autorizar la prueba.'
    }
}
function Assert-DockerContenedor([string]$Nombre) {
    $estado = & docker inspect -f '{{.State.Running}}' $Nombre 2>$null
    if ($LASTEXITCODE -ne 0 -or $estado -ne 'true') {
        throw "No se está ejecutando el contenedor $Nombre. Consultar persona5/README.md."
    }
}
function Assert-Postgres { Assert-DockerContenedor $script:Contenedor }
function Assert-SSH { Assert-DockerContenedor $script:ContenedorSSH }

function Invoke-PsqlInteractivo {
    param(
        [Parameter(Mandatory)][string]$Usuario,
        [Parameter(Mandatory)][string[]]$Sql,
        [string]$ArchivoSalida,
        [switch]$SoloTuplas
    )
    $argsDocker = @('exec','-it',$script:Contenedor,'psql','-h','127.0.0.1','-U',$Usuario,'-d',$script:Db,'-W','-X','-v','ON_ERROR_STOP=1')
    if ($SoloTuplas) { $argsDocker += '-tA' }
    if ($ArchivoSalida) { $argsDocker += @('-o',$ArchivoSalida) }
    foreach ($sentencia in $Sql) { $argsDocker += @('-c',$sentencia) }
    & docker @argsDocker
    if ($LASTEXITCODE -ne 0) { throw "psql ($Usuario) terminó con error: $LASTEXITCODE" }
}
function Registrar-Evento {
    param([string]$Escenario, [string]$Fase, [string]$Detalle)
    $dir = Join-Path $script:PersonaRoot 'evidencias'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $ruta = Join-Path $dir 'bitacora.csv'
    $registro = [pscustomobject]@{
        escenario = $Escenario
        fase = $Fase
        hora_local = Get-Hora
        hora_utc = Get-HoraUTC
        detalle = $Detalle
    }
    $registro | Export-Csv -Path $ruta -NoTypeInformation -Append -Encoding utf8
}
