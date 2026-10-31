-- NutriAnimales | Lectura de monitoreo para n8n (PostgreSQL 16).
-- Instalar despues de 04_rbac.sql. Para una base existente, usar actualizar-monitoreo.ps1.
-- Ejecutar con ON_ERROR_STOP y una transaccion externa; es reejecutable.
-- No cambia datos de negocio, passwords ni los grants particulares de otros perfiles.

DO $preflight$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM regexp_split_to_table(current_setting('shared_preload_libraries'), ',') AS x(lib)
        WHERE btrim(lib, ' "') = 'pg_stat_statements'
    ) OR current_setting('compute_query_id') <> 'on' THEN
        RAISE EXCEPTION 'Falta cargar pg_stat_statements con compute_query_id=on. Aplicar el overlay y recrear solo postgres conservando sus volumenes';
    END IF;
    IF to_regclass('public.pg_settings_baseline') IS NULL
       OR to_regclass('public.auditoria_datos') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='agente_ia') THEN
        RAISE EXCEPTION 'La base NutriAnimales debe estar instalada antes de actualizar monitoreo';
    END IF;
END $preflight$;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;

DO $schema$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
                   WHERE e.extname='pg_stat_statements' AND n.nspname='public') THEN
        RAISE EXCEPTION 'pg_stat_statements ya existe en otro esquema. Revisar su instalacion sin eliminarla';
    END IF;
END $schema$;

-- Instalaciones antiguas podian heredar TEMP de PUBLIC. Alinear el acceso
-- con el RBAC actual sin cambiar CONNECT, passwords ni datos existentes.
SELECT current_database() AS monitor_db \gset
REVOKE CREATE, TEMPORARY ON DATABASE :"monitor_db" FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

GRANT SELECT ON public.auditoria_datos, public.backups,
    public.alertas_auditoria, public.pg_settings_baseline TO agente_ia;
GRANT pg_read_all_stats TO agente_ia;
GRANT SELECT ON public.pg_stat_statements, public.pg_stat_statements_info TO agente_ia;
-- Necesario tambien cuando el administrador revoco EXECUTE por defecto a PUBLIC.
GRANT EXECUTE ON FUNCTION public.pg_stat_statements(boolean), public.pg_stat_statements_info() TO agente_ia;
REVOKE ALL ON FUNCTION public.pg_stat_statements_reset(oid, oid, bigint) FROM agente_ia;

-- Baseline actualizado solo por este procedimiento administrativo autorizado.
INSERT INTO public.pg_settings_baseline(name, valor_esperado)
VALUES ('shared_preload_libraries', current_setting('shared_preload_libraries')),
       ('compute_query_id', 'on'), ('ssl_min_protocol_version', 'TLSv1.2')
ON CONFLICT (name) DO UPDATE SET valor_esperado=EXCLUDED.valor_esperado;

DO $permissions$
DECLARE r record;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='agente_ia' AND rolcanlogin AND rolinherit
                   AND NOT (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) THEN
        RAISE EXCEPTION 'agente_ia debe conservar LOGIN/INHERIT sin privilegios administrativos';
    END IF;
    FOR r IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname='public' LOOP
        IF has_table_privilege('agente_ia', format('%I.%I',r.schemaname,r.tablename), 'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER') THEN
            RAISE EXCEPTION 'Permiso de escritura previo incompatible en %.%; revisar grants antes de actualizar',r.schemaname,r.tablename;
        END IF;
    END LOOP;
    IF has_function_privilege('agente_ia','public.pg_stat_statements_reset(oid,oid,bigint)','EXECUTE') THEN
        RAISE EXCEPTION 'agente_ia hereda permiso para reiniciar estadisticas; revisar grants';
    END IF;
END $permissions$;
