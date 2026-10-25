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
    'log_min_duration_statement'
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
SELECT 'PASS: esquema, integridad declarada, triggers, RBAC, TLS, HBA y baseline' AS resultado;
