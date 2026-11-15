<# A5: patrón de lectura masiva SIN COPIAR NI EXPORTAR datos.
Se ejecutan SELECT autorizados en el laboratorio con agente_ia; la salida se
redirige a /dev/null DENTRO del contenedor PostgreSQL. Alerta D7 por delta
> 1000 filas en pg_stat_statements (después de baseline de flujo activo).
#>
param([switch]$ConfirmarLaboratorio)
. "$PSScriptRoot/_comun.ps1"
Assert-Laboratorio -ConfirmarLaboratorio:$ConfirmarLaboratorio
Assert-Postgres
Write-Paso "A5: lecturas masivas controladas $(Get-Hora)"
Registrar-Evento A5 INICIO 'SELECT sobre clientes/ventas con agente_ia. Sin exportación de datos.'
Invoke-PsqlInteractivo -Usuario agente_ia -ArchivoSalida '/dev/null' -Sql @(
    'SELECT * FROM public.clientes;',
    'SELECT * FROM public.ventas;',
    'SELECT * FROM public.ventas;'
)
Registrar-Evento A5 FIN 'SELECT completos; revisar D7 y pg_stat_statements.'
Write-Paso "A5 terminó $(Get-Hora)"
Write-Host 'Capturar D7 antes de que se reinicie la ventana de sondeo.'
Write-Host 'Query para auditor: SELECT r.rolname,s.calls,s.rows,left(s.query,100) FROM public.pg_stat_statements s JOIN pg_roles r ON r.oid=s.userid WHERE r.rolname=''agente_ia'' AND (s.query ILIKE ''%ventas%'' OR s.query ILIKE ''%clientes%'') ORDER BY s.rows DESC;'
Write-Host 'Acción: revisar usuario y procedencia; revocar acceso o rotar credenciales si el evento es no autorizado.'
Write-Host 'SELECT no genera filas en auditoria_datos (solo DML): fuente válida es pg_stat_statements.'
