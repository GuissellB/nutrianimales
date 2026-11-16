<# A4: GRANT acotado en tiempo; REVOKE en finally.
Requiere base de laboratorio y contraseña administrativa interactiva.
No revoca permisos preexistentes: el GRANT aborta si agente_ia ya tenía INSERT.
En caso de cierre forzoso de PowerShell, ejecutar la recuperación del README.
#>
param([switch]$ConfirmarLaboratorio, [ValidateRange(30,300)][int]$SegundosVentana = 150)
. "$PSScriptRoot/_comun.ps1"
Assert-Laboratorio -ConfirmarLaboratorio:$ConfirmarLaboratorio
Assert-Postgres
$grantHecho = $false
$grantSql = @'
BEGIN;
DO $test$
BEGIN
 IF EXISTS (
   SELECT 1 FROM pg_tables
   WHERE schemaname='public'
     AND has_table_privilege('agente_ia', format('%I.%I',schemaname,tablename),'INSERT')
 ) THEN
   RAISE EXCEPTION 'agente_ia ya tiene INSERT: no se ejecuta la simulacion';
 END IF;
END;
$test$;
GRANT INSERT ON ALL TABLES IN SCHEMA public TO agente_ia;
COMMIT;
'@
try {
    Write-Paso "A4: otorgar INSERT temporalmente $(Get-Hora)"
    Invoke-PsqlInteractivo -Usuario postgres -Sql @($grantSql)
    $grantHecho = $true
    Registrar-Evento A4 INICIO 'GRANT INSERT ALL TABLES IN SCHEMA public TO agente_ia;'
    Invoke-PsqlInteractivo -Usuario postgres -Sql @("SELECT table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee='agente_ia' AND privilege_type='INSERT' ORDER BY table_name LIMIT 12;")
    Write-Host "Capturar H3 en Telegram durante $SegundosVentana segundos. La revocación será automática."
    Start-Sleep -Seconds $SegundosVentana
} finally {
    if ($grantHecho) {
        Write-Paso "A4: REVOCAR privilegio de la prueba $(Get-Hora)"
        try {
            Invoke-PsqlInteractivo -Usuario postgres -Sql @(
                'REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;',
                "SELECT bool_or(has_table_privilege('agente_ia',format('%I.%I',schemaname,tablename),'INSERT')) AS agente_con_insert FROM pg_tables WHERE schemaname='public';"
            )
            Registrar-Evento A4 RESPUESTA 'REVOKE completado; verificar agente_con_insert=f.'
        } catch {
            Write-Warning 'FALLÓ REVOCACIÓN. Ejecutar ya: REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;'
            throw
        }
    }
}
Write-Host 'GRANT/REVOKE no generan fila en auditoria_datos (trigger DML). Evidencia: role_table_grants + H3 + bitacora.'
