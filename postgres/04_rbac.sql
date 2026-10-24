-- NutriAnimales S.A. | RBAC PostgreSQL 16
-- Ejecutar como postgres despues de 03_auditoria.sql.
-- No contiene passwords. Establecer por separado con \password en psql.
-- Es seguro reejecutar para objetos/roles ya creados; no quita otros GRANT previos.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_gerente') THEN CREATE ROLE rol_gerente NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_ti') THEN CREATE ROLE rol_ti NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_auditor') THEN CREATE ROLE rol_auditor NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='gerente_db') THEN CREATE ROLE gerente_db LOGIN INHERIT; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ti_db') THEN CREATE ROLE ti_db LOGIN INHERIT; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='auditor_db') THEN CREATE ROLE auditor_db LOGIN INHERIT; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='agente_ia') THEN CREATE ROLE agente_ia LOGIN INHERIT; END IF;
END
$roles$;

ALTER ROLE rol_gerente NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE rol_ti NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE rol_auditor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE gerente_db LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE ti_db LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE auditor_db LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER ROLE agente_ia LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;

GRANT rol_gerente TO gerente_db;
GRANT rol_ti TO ti_db;
GRANT rol_auditor TO auditor_db;

-- Publicar solo agregados al gerente, no datos individuales.
CREATE OR REPLACE VIEW public.reporte_ventas_gerencia AS
SELECT fecha::date AS fecha, COUNT(*) AS cantidad_ventas, SUM(precio_total) AS total_ventas
FROM public.ventas GROUP BY fecha::date;

GRANT CONNECT ON DATABASE nutrianimales_db TO rol_gerente, rol_ti, rol_auditor, agente_ia;
GRANT USAGE ON SCHEMA public TO rol_gerente, rol_ti, rol_auditor, agente_ia;

GRANT SELECT ON public.reporte_ventas_gerencia TO rol_gerente;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_ti;
GRANT INSERT ON public.backups, public.alertas_auditoria TO rol_ti;
GRANT USAGE ON SEQUENCE public.backups_id_seq, public.alertas_auditoria_id_seq TO rol_ti;
GRANT SELECT ON public.auditoria_datos, public.backups, public.alertas_auditoria TO rol_auditor;
GRANT SELECT ON public.plantas, public.productos, public.materias_primas,
    public.lotes_produccion, public.ventas, public.clientes,
    public.control_calidad, public.gastos TO agente_ia;

-- Restricciones explicitas. El propietario/superusuario sigue teniendo sus facultades.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.auditoria_datos FROM rol_gerente, rol_ti, rol_auditor, agente_ia;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_auditoria() FROM PUBLIC;

-- Los permisos para futuros objetos requieren GRANT adicionales o ALTER DEFAULT PRIVILEGES.
-- Configurar passwords INTERACTIVAMENTE en psql (sin escribirlas aqui):
-- \password gerente_db
-- \password ti_db
-- \password auditor_db
-- \password agente_ia
