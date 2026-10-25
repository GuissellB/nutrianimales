#requires -Version 7.2
[CmdletBinding()]
param(
    [string[]]$ComposeFiles = @('docker-compose.yml', 'docker-compose.postgres.yml'),
    [string]$ProjectName,
    [string]$EnvFile,
    [string]$RbacSecretsFile
)
. "$PSScriptRoot/common.ps1"
$compose = @(Get-ComposeArguments $ComposeFiles $ProjectName $EnvFile)
$container = (Invoke-Docker -Arguments ($compose + @('ps', '-q', 'postgres'))).Out
if (-not $container -or $container.Contains("`n")) { throw 'Se requiere exactamente un servicio postgres iniciado.' }

# Rechazo previo sin leer secretos ni modificar datos. Se repite bajo bloqueo transaccional.
$guard = @'
SELECT pg_advisory_xact_lock(726841921);
DO $guard$
BEGIN
 IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = session_user) THEN
   RAISE EXCEPTION 'La instalacion requiere la cuenta administrativa de bootstrap';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname NOT IN ('public', 'information_schema') AND nspname NOT LIKE 'pg_%')
 OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public')
 OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public')
 OR EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public') THEN
   RAISE EXCEPTION 'Instalacion rechazada: la base no esta vacia. No se modifico su contenido';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('rol_propietario_auditoria','rol_gerente','rol_ti','rol_auditor','gerente_db','ti_db','auditor_db','agente_ia')) THEN
   RAISE EXCEPTION 'Instalacion rechazada: ya existen roles NutriAnimales en el cluster';
 END IF;
END $guard$;
'@
$null = Invoke-AdminSql $container "BEGIN;`n$guard`nROLLBACK;"
$roles = @('gerente_db', 'ti_db', 'auditor_db', 'agente_ia')
$secrets = @{}
if ($RbacSecretsFile) {
    try { $secrets = Get-Content -LiteralPath $RbacSecretsFile -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
    catch { throw 'No se pudo leer un JSON RBAC valido. Revise el archivo local sin publicar su contenido.' }
    if ($secrets -isnot [Collections.IDictionary]) { throw 'El archivo RBAC debe contener un objeto JSON con las cuatro cuentas.' }
}
$passwordSql = @()
try {
    foreach ($role in $roles) {
        $secure = if ($RbacSecretsFile) {
            if (-not $secrets.ContainsKey($role) -or $secrets[$role] -isnot [string]) { throw "Falta secreto para $role" }
            ConvertTo-SecureString $secrets[$role] -AsPlainText -Force
        } else { Read-Host "Secreto para $role (minimo 20 caracteres)" -AsSecureString }
        try { $verifier = ConvertTo-ScramVerifier $secure } finally { $secure.Dispose() }
        $passwordSql += "ALTER ROLE $role PASSWORD '$verifier';"
    }
} finally { $secrets.Clear() }

$directory = '/tmp/nutrianimales-init-' + [guid]::NewGuid().ToString('N')
$null = Invoke-Docker -Arguments @('exec', $container, 'mkdir', '-m', '700', $directory)
try {
    $files = @('01_schema.sql', '03_auditoria.sql', '02_seed.sql', '04_rbac.sql', '05_baseline.sql', '06_verificaciones.sql')
    foreach ($file in $files) {
        $null = Invoke-Docker -Arguments @('cp', (Join-Path $script:RepoRoot "postgres/$file"), "${container}:$directory/$file")
    }
    $includes = ($files | Where-Object { $_ -notin @('05_baseline.sql','06_verificaciones.sql') } | ForEach-Object { "\i $directory/$_" }) -join "`n"
    # Desactivar logs SQL de esta sesion antes de enviar verificadores de contrasena.
    $sql = "SET log_statement='none'; SET log_min_duration_statement=-1; SET log_min_error_statement='panic';`nBEGIN;`n$guard`n$includes`n$($passwordSql -join "`n")`nSET log_min_duration_statement=1000;`n\i $directory/05_baseline.sql`n\i $directory/06_verificaciones.sql`nCOMMIT;"
    $result = Invoke-AdminSql $container $sql
    Write-Host $result.Out
    Write-Host 'Instalacion atomica completada: esquema, auditoria, seed, RBAC, baseline y secretos SCRAM.'
} finally {
    $passwordSql = $null
    $sql = $null
    # Solo archivos temporales de esta invocacion; nunca PGDATA/volumenes.
    $paths = @($files | ForEach-Object { "$directory/$_" })
    $null = Invoke-Docker -Arguments (@('exec', $container, 'rm', '-f', '--') + $paths) -AllowFailure
    $null = Invoke-Docker -Arguments @('exec', $container, 'rmdir', '--', $directory) -AllowFailure
}
