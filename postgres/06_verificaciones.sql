-- =====================================================
-- NUTRIANIMALES - VERIFICACIONES DE POSTGRESQL
-- Persona 2 - Base de datos y seguridad
-- =====================================================

-- 1. Version de PostgreSQL
SELECT version();

-- 2. Tablas de la aplicacion
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 3. Cantidad de registros de prueba
SELECT
    (SELECT COUNT(*) FROM public.plantas) AS plantas,
    (SELECT COUNT(*) FROM public.productos) AS productos,
    (SELECT COUNT(*) FROM public.materias_primas) AS materias_primas,
    (SELECT COUNT(*) FROM public.clientes) AS clientes,
    (SELECT COUNT(*) FROM public.lotes_produccion) AS lotes,
    (SELECT COUNT(*) FROM public.ventas) AS ventas,
    (SELECT COUNT(*) FROM public.control_calidad) AS control_calidad,
    (SELECT COUNT(*) FROM public.gastos) AS gastos;

-- 4. Triggers de auditoria activos
SELECT
    event_object_table AS tabla,
    trigger_name,
    string_agg(event_manipulation, ', ' ORDER BY event_manipulation) AS operaciones
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trg_auditoria%'
GROUP BY event_object_table, trigger_name
ORDER BY event_object_table;

-- 5. Roles y usuarios de la aplicacion
SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname IN (
    'rol_gerente', 'rol_ti', 'rol_auditor',
    'gerente_db', 'ti_db', 'auditor_db', 'agente_ia'
)
ORDER BY rolname;

-- 6. Seguridad de conexiones
SELECT name, setting
FROM pg_settings
WHERE name IN (
    'ssl',
    'password_encryption',
    'log_min_duration_statement',
    'shared_preload_libraries',
    'compute_query_id'
)
ORDER BY name;

-- 7. Reglas de autenticacion
SELECT type, auth_method, error
FROM pg_hba_file_rules;

-- 8. Permisos de escritura sobre auditoria
SELECT
    rolname AS usuario,
    has_table_privilege(rolname, 'public.auditoria_datos', 'INSERT') AS insertar,
    has_table_privilege(rolname, 'public.auditoria_datos', 'UPDATE') AS modificar,
    has_table_privilege(rolname, 'public.auditoria_datos', 'DELETE') AS eliminar
FROM pg_roles
WHERE rolname IN ('gerente_db', 'ti_db', 'auditor_db', 'agente_ia')
ORDER BY rolname;
-- Aserciones: psql debe ejecutarse con ON_ERROR_STOP=1. Un listado no prueba cumplimiento.
DO $verify$
DECLARE r record;
BEGIN
 IF (SELECT count(*) FROM pg_tables WHERE schemaname='public') <> 12 THEN
   RAISE EXCEPTION 'Se esperaban 12 tablas public';
 END IF;
 IF (SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
     WHERE n.nspname='public' AND c.contype='f' AND c.convalidated) <> 5 THEN
   RAISE EXCEPTION 'Faltan claves foraneas validadas';
 END IF;
 IF (SELECT count(*) FROM pg_trigger WHERE tgname IN
     ('trg_auditoria_lotes','trg_auditoria_ventas','trg_auditoria_clientes','trg_auditoria_formulas') AND tgenabled='O') <> 4 THEN
   RAISE EXCEPTION 'Faltan triggers de auditoria activos';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_settings_baseline b LEFT JOIN pg_settings s USING(name)
     WHERE s.name IS NULL OR b.valor_esperado <> s.setting) THEN
   RAISE EXCEPTION 'La configuracion se desvia del baseline';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_hba_file_rules WHERE error IS NOT NULL OR auth_method IN ('trust','md5','password')) THEN
   RAISE EXCEPTION 'HBA invalido o con autenticacion debil';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_stat_ssl WHERE pid=pg_backend_pid() AND ssl) THEN
   RAISE EXCEPTION 'La verificacion requiere conexion TLS';
 END IF;
 IF (SELECT count(*) FROM pg_roles WHERE rolname IN
     ('rol_propietario_auditoria','rol_gerente','rol_ti','rol_auditor','gerente_db','ti_db','auditor_db','agente_ia')) <> 8 THEN
   RAISE EXCEPTION 'Faltan roles esperados';
 END IF;
 FOR r IN SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles
     WHERE rolname IN ('rol_propietario_auditoria','rol_gerente','rol_ti','rol_auditor','gerente_db','ti_db','auditor_db','agente_ia') LOOP
   IF r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls THEN
     RAISE EXCEPTION 'Privilegios administrativos inesperados: %', r.rolname;
   END IF;
 END LOOP;
 FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('gerente_db','ti_db','auditor_db','agente_ia') LOOP
   IF has_table_privilege(r.rolname,'public.auditoria_datos','INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
      OR has_schema_privilege(r.rolname,'public','CREATE')
      OR has_database_privilege(r.rolname,current_database(),'CREATE,TEMP')
      OR has_function_privilege(r.rolname,'public.fn_auditoria()','EXECUTE') THEN
     RAISE EXCEPTION 'Permiso prohibido para %', r.rolname;
   END IF;
 END LOOP;
 IF NOT pg_has_role('gerente_db','rol_gerente','MEMBER')
 OR NOT pg_has_role('ti_db','rol_ti','MEMBER')
 OR NOT pg_has_role('auditor_db','rol_auditor','MEMBER') THEN
   RAISE EXCEPTION 'Membresias RBAC incorrectas';
 END IF;
 IF NOT has_table_privilege('gerente_db','public.reporte_ventas_gerencia','SELECT')
 OR has_table_privilege('gerente_db','public.ventas','SELECT')
 OR NOT has_table_privilege('ti_db','public.backups','INSERT')
 OR has_table_privilege('ti_db','public.ventas','UPDATE')
 OR NOT has_table_privilege('auditor_db','public.auditoria_datos','SELECT')
 OR has_table_privilege('auditor_db','public.clientes','SELECT')
 OR NOT has_table_privilege('agente_ia','public.productos','SELECT')
 OR has_table_privilege('agente_ia','public.productos','UPDATE') THEN
   RAISE EXCEPTION 'Matriz RBAC incorrecta';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid='public.fn_auditoria()'::regprocedure
     AND prosecdef AND proowner=(SELECT oid FROM pg_roles WHERE rolname='rol_propietario_auditoria')
     AND proconfig @> ARRAY['search_path=pg_catalog, pg_temp']) THEN
   RAISE EXCEPTION 'Funcion de auditoria sin endurecimiento esperado';
 END IF;
END $verify$;

-- Monitoreo: comprobar privilegios efectivos, no solo la existencia de GRANT.
DO $monitor$
DECLARE r record;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
     WHERE e.extname='pg_stat_statements' AND n.nspname='public')
 OR NOT EXISTS (SELECT 1 FROM regexp_split_to_table(current_setting('shared_preload_libraries'), ',') AS x(lib)
     WHERE btrim(lib, ' "')='pg_stat_statements')
 OR current_setting('compute_query_id') <> 'on' THEN
   RAISE EXCEPTION 'pg_stat_statements no esta cargado/instalado con compute_query_id=on';
 END IF;
 IF NOT pg_has_role('agente_ia','pg_read_all_stats','USAGE') THEN
   RAISE EXCEPTION 'Falta lectura ampliada de estadisticas para agente_ia';
 END IF;
 FOR r IN SELECT schemaname,tablename FROM pg_tables WHERE schemaname='public' LOOP
   IF NOT has_table_privilege('agente_ia',format('%I.%I',r.schemaname,r.tablename),'SELECT')
      OR has_table_privilege('agente_ia',format('%I.%I',r.schemaname,r.tablename),'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER') THEN
     RAISE EXCEPTION 'agente_ia debe tener solo SELECT sobre %.%',r.schemaname,r.tablename;
   END IF;
 END LOOP;
 IF NOT has_table_privilege('agente_ia','public.pg_stat_statements','SELECT')
 OR NOT has_function_privilege('agente_ia','public.pg_stat_statements(boolean)','EXECUTE')
 OR NOT has_function_privilege('agente_ia','public.pg_stat_statements_info()','EXECUTE')
 OR has_function_privilege('agente_ia','public.pg_stat_statements_reset(oid,oid,bigint)','EXECUTE') THEN
   RAISE EXCEPTION 'Permisos de funciones/estadisticas incorrectos para agente_ia';
 END IF;
 IF pg_has_role('agente_ia','pg_write_all_data','USAGE')
 OR pg_has_role('agente_ia','pg_monitor','USAGE')
 OR pg_has_role('agente_ia','pg_read_server_files','USAGE')
 OR pg_has_role('agente_ia','pg_write_server_files','USAGE')
 OR pg_has_role('agente_ia','pg_execute_server_program','USAGE')
 OR pg_has_role('agente_ia','pg_signal_backend','USAGE') THEN
   RAISE EXCEPTION 'agente_ia tiene un rol privilegiado ajeno al monitoreo de lectura';
 END IF;
END $monitor$;

-- Comprobar las consultas de lectura con los permisos del propio agente.
SET ROLE agente_ia;
SELECT current_user AS cuenta, (SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()) AS tls;
SELECT count(*) AS filas_estadisticas_visibles FROM public.pg_stat_statements;
SELECT count(*) AS sesiones_visibles FROM pg_catalog.pg_stat_activity;
SELECT count(*) AS bloqueos_visibles FROM pg_catalog.pg_locks;
SELECT count(*) AS parametros_baseline FROM public.pg_settings_baseline;
RESET ROLE;
SELECT 'PASS: esquema, integridad, auditoria, RBAC de lectura, TLS y pg_stat_statements' AS resultado;
