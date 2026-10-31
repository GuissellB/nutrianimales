#requires -Version 7.2
[CmdletBinding()]
param(
    [string[]]$ComposeFiles = @('docker-compose.yml', 'docker-compose.postgres.yml'),
    [string]$ProjectName,
    [string]$EnvFile
)
. "$PSScriptRoot/common.ps1"
$compose = @(Get-ComposeArguments $ComposeFiles $ProjectName $EnvFile)
$container = (Invoke-Docker -Arguments ($compose + @('ps', '-q', 'postgres'))).Out
if (-not $container -or $container.Contains("`n")) { throw 'La actualizacion requiere un servicio postgres existente e iniciado.' }

# Validar antes de recrear. Nunca mostrar config: contiene secretos de env_file.
$config = (Invoke-Docker -Arguments ($compose + @('config', '--format', 'json'))).Out | ConvertFrom-Json -AsHashtable
$service = $config.services.postgres
if ($service.image -notmatch '^postgres:16(?:[.-]|$)') { throw 'Este procedimiento admite la imagen PostgreSQL 16 del proyecto.' }
if ($service.ContainsKey('ports') -and $service.ports.Count) { throw 'PostgreSQL no debe publicar puertos al host.' }

function Assert-DataVolumes([string]$ContainerId) {
    $mounts = (Invoke-Docker -Arguments @('inspect','--format','{{json .Mounts}}',$ContainerId)).Out | ConvertFrom-Json
    foreach ($destination in @('/var/lib/postgresql/data','/tls')) {
        $actual = @($mounts | Where-Object Destination -eq $destination)
        $planned = @($service.volumes | Where-Object { $_.target -eq $destination })
        if ($actual.Count -ne 1 -or $planned.Count -ne 1 -or $actual[0].Type -ne 'volume' -or $planned[0].type -ne 'volume') {
            throw "Se requiere conservar un volumen nombrado en $destination. Revisar Compose."
        }
        $declaredName = $config.volumes[$planned[0].source].name
        if ($actual[0].Name -cne $declaredName) {
            throw "El proyecto o volumen de $destination no coincide con el contenedor existente. No continuar."
        }
    }
}
Assert-DataVolumes $container

# Una edicion previa de .env no debe cambiar el bootstrap durante esta migracion.
$currentEnvironment = @{}
$entries = (Invoke-Docker -Arguments @('inspect','--format','{{json .Config.Env}}',$container)).Out | ConvertFrom-Json
foreach ($entry in $entries) { $pair = $entry -split '=',2; $currentEnvironment[$pair[0]] = $pair[1] }
foreach ($key in @('POSTGRES_USER','POSTGRES_DB','POSTGRES_PASSWORD','POSTGRES_PASSWORD_FILE')) {
    if ($service.environment[$key] -cne $currentEnvironment[$key]) {
        throw "La configuracion de $key difiere del contenedor. Esta actualizacion no rota credenciales ni cambia la base."
    }
}
$currentEnvironment.Clear()
$null = Invoke-AdminSql $container 'SELECT name FROM public.pg_settings_baseline LIMIT 1;'
$currentLibraries = (Invoke-AdminSql $container "SELECT current_setting('shared_preload_libraries');").Out
$plannedLibraries = @($service.command | Where-Object { $_ -like 'shared_preload_libraries=*' })
if ($plannedLibraries.Count -ne 1 -or $service.command -notcontains 'compute_query_id=on') {
    throw 'Aplicar docker-compose.postgres.yml actualizado antes de ejecutar esta migracion.'
}
$plannedNames = @($plannedLibraries[0].Substring('shared_preload_libraries='.Length) -split ',' | ForEach-Object { $_.Trim(' ', '"') })
if ($plannedNames -notcontains 'pg_stat_statements') { throw 'La lista de bibliotecas debe incluir pg_stat_statements.' }
foreach ($library in @($currentLibraries -split ',' | ForEach-Object { $_.Trim(' ', '"') } | Where-Object { $_ })) {
    if ($plannedNames -notcontains $library) {
        throw "Conservar la biblioteca $library en POSTGRES_SHARED_PRELOAD_LIBRARIES del .env antes de continuar."
    }
}

Write-Host 'Recreando solamente PostgreSQL para cargar estadisticas; se conservan los volumenes de datos y TLS. Habra una interrupcion breve.'
$null = Invoke-Docker -Arguments ($compose + @('up','-d','--no-deps','--force-recreate','--wait','--wait-timeout','120','--pull','never','--no-build','postgres'))
$container = (Invoke-Docker -Arguments ($compose + @('ps','-q','postgres'))).Out
Assert-DataVolumes $container
$directory = '/tmp/nutrianimales-monitor-' + [guid]::NewGuid().ToString('N')
$null = Invoke-Docker -Arguments @('exec',$container,'mkdir','-m','700',$directory)
$files = @('07_monitoreo_n8n.sql','06_verificaciones.sql')
try {
    foreach ($file in $files) {
        $null = Invoke-Docker -Arguments @('cp',(Join-Path $script:RepoRoot "postgres/$file"),"${container}:$directory/$file")
    }
    $result = Invoke-AdminSql $container "BEGIN;`n\i $directory/07_monitoreo_n8n.sql`n\i $directory/06_verificaciones.sql`nCOMMIT;"
    Write-Host $result.Out
    Write-Host 'Actualizacion completada: misma base y secretos; agente_ia tiene lectura de monitoreo y no puede reiniciar estadisticas.'
} finally {
    $paths = @($files | ForEach-Object { "$directory/$_" })
    $null = Invoke-Docker -Arguments (@('exec',$container,'rm','-f','--') + $paths) -AllowFailure
    $null = Invoke-Docker -Arguments @('exec',$container,'rmdir','--',$directory) -AllowFailure
}
