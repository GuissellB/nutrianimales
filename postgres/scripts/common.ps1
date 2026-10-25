#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

function Invoke-Docker {
    param([string[]]$Arguments, [string]$InputText, [switch]$AllowFailure)
    $info = [Diagnostics.ProcessStartInfo]::new('docker')
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if ($InputText) { $process.StandardInput.Write($InputText) }
    $process.StandardInput.Close()
    $process.WaitForExit()
    $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Out = $stdout.Result.Trim(); Err = $stderr.Result.Trim() }
    $process.Dispose()
    if ($result.ExitCode -ne 0 -and -not $AllowFailure) {
        throw "Docker fallo (codigo $($result.ExitCode)): $($result.Err)`n$($result.Out)"
    }
    return $result
}

function Get-ComposeArguments {
    param([string[]]$ComposeFiles, [string]$ProjectName, [string]$EnvFile)
    $arguments = @('compose', '--project-directory', $script:RepoRoot)
    if ($ProjectName) { $arguments += @('-p', $ProjectName) }
    if ($EnvFile) { $arguments += @('--env-file', [IO.Path]::GetFullPath($EnvFile)) }
    foreach ($file in $ComposeFiles) {
        $path = if ([IO.Path]::IsPathRooted($file)) { $file } else { Join-Path $script:RepoRoot $file }
        $arguments += @('-f', $path)
    }
    return $arguments
}

function Invoke-AdminSql {
    param([string]$Container, [string]$Sql, [switch]$AllowFailure)
    # El secreto administrativo se obtiene dentro del contenedor, nunca en argv del host.
    $command = @'
set -eu
if [ -n "${POSTGRES_PASSWORD_FILE:-}" ]; then
  PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"
else
  PGPASSWORD="${POSTGRES_PASSWORD:?Falta secreto administrativo}"
fi
export PGPASSWORD
export PGHOST=postgres PGSSLMODE=verify-full PGSSLROOTCERT=/tls/server.crt
export PGUSER="${POSTGRES_USER:-postgres}" PGDATABASE="${POSTGRES_DB:-$POSTGRES_USER}"
exec psql -X -w -q -v ON_ERROR_STOP=1 -A -t
'@
    Invoke-Docker -Arguments @('exec', '-i', $Container, 'sh', '-c', $command) -InputText $Sql -AllowFailure:$AllowFailure
}

function ConvertTo-ScramVerifier {
    param([Security.SecureString]$Secret)
    $salted = $null
    $clientKey = $null
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    try {
        # ASCII imprimible: evita ambiguedades de normalizacion SASLprep entre clientes.
        if ($plain.Length -lt 20 -or $plain -cnotmatch '^[\x21-\x7e]+$') {
            throw 'Cada secreto RBAC requiere al menos 20 caracteres ASCII imprimibles sin espacios.'
        }
        $salt = [byte[]]::new(16)
        [Security.Cryptography.RandomNumberGenerator]::Fill($salt)
        $derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($plain, $salt, 4096, [Security.Cryptography.HashAlgorithmName]::SHA256)
        try { $salted = $derive.GetBytes(32) } finally { $derive.Dispose() }
        $hmac = [Security.Cryptography.HMACSHA256]::new($salted)
        try {
            $clientKey = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes('Client Key'))
            $serverKey = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes('Server Key'))
        } finally { $hmac.Dispose() }
        $storedKey = [Security.Cryptography.SHA256]::HashData($clientKey)
        return 'SCRAM-SHA-256$4096:' + [Convert]::ToBase64String($salt) + '$' + [Convert]::ToBase64String($storedKey) + ':' + [Convert]::ToBase64String($serverKey)
    } finally {
        $plain = $null
        if ($salted) { [Array]::Clear($salted, 0, $salted.Length) }
        if ($clientKey) { [Array]::Clear($clientKey, 0, $clientKey.Length) }
    }
}

function Protect-SecretDirectory {
    param([string]$Path)
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl = [Security.AccessControl.DirectorySecurity]::new()
        $acl.SetOwner($identity)
        $acl.SetAccessRuleProtection($true, $false)
        $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
        $propagate = [Security.AccessControl.PropagationFlags]::None
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', $inherit, $propagate, 'Allow'))
        $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($system, 'FullControl', $inherit, $propagate, 'Allow'))
        Set-Acl -LiteralPath $Path -AclObject $acl
    } else {
        & chmod 700 -- $Path
        if ($LASTEXITCODE) { throw 'No se pudo restringir el directorio de secretos' }
    }
}
