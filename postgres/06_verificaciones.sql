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