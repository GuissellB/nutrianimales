#requires -Version 7.2
[CmdletBinding()]
param()
. "$PSScriptRoot/common.ps1"
$envPath = Join-Path $script:RepoRoot '.env'
$secretDir = Join-Path $script:RepoRoot '.secrets'
$rbacPath = Join-Path $secretDir 'rbac-secrets.json'
if ((Test-Path -LiteralPath $envPath) -or (Test-Path -LiteralPath $rbacPath)) {
    throw 'Ya existe .env o .secrets/rbac-secrets.json. No se reemplazara ningun secreto.'
}
$null = New-Item -ItemType Directory -Path $secretDir -Force
Protect-SecretDirectory $secretDir
function New-Password {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    [Convert]::ToHexString($bytes)
}
$values = @{}
foreach ($role in @('gerente_db','ti_db','auditor_db','agente_ia')) { $values[$role] = New-Password }
$admin = New-Password
# CreateNew evita sobrescritura incluso ante dos invocaciones concurrentes.
function Write-NewFile([string]$Path, [string]$Content) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $writer.Write($Content) } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}
Write-NewFile $rbacPath ($values | ConvertTo-Json)
# El archivo de entorno hereda la ACL del directorio privado antes de ubicarse en la raiz.
$privateEnv = Join-Path $secretDir 'bootstrap.env'
Write-NewFile $privateEnv "POSTGRES_DB=nutrianimales_db`nPOSTGRES_USER=postgres`nPOSTGRES_PASSWORD=$admin`n"
if ($IsWindows) {
    $acl = Get-Acl -LiteralPath $privateEnv
    $acl.SetAccessRuleProtection($true, $true)
    Set-Acl -LiteralPath $privateEnv -AclObject $acl
} else {
    & chmod 600 -- $privateEnv
    if ($LASTEXITCODE) { throw 'No se pudieron restringir permisos del archivo de entorno' }
}
[IO.File]::Move($privateEnv, $envPath)
$values.Clear()
$admin = $null
Write-Host 'Secretos aleatorios creados en .env y .secrets/rbac-secrets.json sin mostrarlos. Guardelos en su gestor de secretos.'
