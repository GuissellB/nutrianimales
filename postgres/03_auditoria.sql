-- NutriAnimales S.A. | Auditoria segura PostgreSQL 16
-- Ejecutar como postgres DESPUES de 01_schema.sql y 02_seed.sql.
-- Idempotente para reinstalacion local; NO elimina filas de auditoria.
-- Importante: SESSION_USER identifica la cuenta PostgreSQL, no a cada usuario de N8N.

DO $role$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_propietario_auditoria') THEN
        CREATE ROLE rol_propietario_auditoria NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END
$role$;

ALTER ROLE rol_propietario_auditoria NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT USAGE ON SCHEMA public TO rol_propietario_auditoria;
ALTER TABLE public.auditoria_datos OWNER TO rol_propietario_auditoria;

CREATE OR REPLACE FUNCTION public.fn_auditoria()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.auditoria_datos
            (tabla, operacion, usuario, fecha, ip_cliente, fila_id, valor_antes, valor_nuevo)
        VALUES
            (TG_TABLE_NAME, TG_OP, SESSION_USER, NOW(), inet_client_addr(), NEW.id, NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.auditoria_datos
            (tabla, operacion, usuario, fecha, ip_cliente, fila_id, valor_antes, valor_nuevo)
        VALUES
            (TG_TABLE_NAME, TG_OP, SESSION_USER, NOW(), inet_client_addr(), NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.auditoria_datos
            (tabla, operacion, usuario, fecha, ip_cliente, fila_id, valor_antes, valor_nuevo)
        VALUES
            (TG_TABLE_NAME, TG_OP, SESSION_USER, NOW(), inet_client_addr(), OLD.id, to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$function$;

ALTER FUNCTION public.fn_auditoria() OWNER TO rol_propietario_auditoria;
REVOKE ALL ON FUNCTION public.fn_auditoria() FROM PUBLIC;
-- Un trigger ya existente puede invocar la funcion sin EXECUTE otorgado al usuario DML.
-- Nadie fuera del propietario puede insertar, modificar o borrar auditoria directamente,
-- salvo grants especificos (p.ej. lectura al rol_auditor y rol_ti).

DROP TRIGGER IF EXISTS trg_auditoria_lotes ON public.lotes_produccion;
CREATE TRIGGER trg_auditoria_lotes AFTER INSERT OR UPDATE OR DELETE ON public.lotes_produccion
FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_ventas ON public.ventas;
CREATE TRIGGER trg_auditoria_ventas AFTER INSERT OR UPDATE OR DELETE ON public.ventas
FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_clientes ON public.clientes;
CREATE TRIGGER trg_auditoria_clientes AFTER INSERT OR UPDATE OR DELETE ON public.clientes
FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_formulas ON public.productos;
CREATE TRIGGER trg_auditoria_formulas AFTER INSERT OR UPDATE OR DELETE ON public.productos
FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
