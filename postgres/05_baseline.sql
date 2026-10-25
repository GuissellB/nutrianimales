-- NutriAnimales S.A.
-- Baseline de seguridad de PostgreSQL
-- Referencia para alerta H5

INSERT INTO public.pg_settings_baseline
    (name, valor_esperado)
VALUES
    ('ssl', 'on'),
    ('ssl_min_protocol_version', 'TLSv1.2'),
    ('password_encryption', 'scram-sha-256'),
    ('log_min_duration_statement', '1000')
ON CONFLICT (name)
DO UPDATE SET
    valor_esperado = EXCLUDED.valor_esperado;

-- Comparar configuracion actual contra baseline

SELECT
    b.name AS parametro,
    b.valor_esperado,
    s.setting AS valor_actual,
    CASE
        WHEN s.name IS NULL THEN 'NO ENCONTRADO'
        WHEN b.valor_esperado = s.setting THEN 'CORRECTO'
        ELSE 'DESVIACION'
    END AS estado
FROM public.pg_settings_baseline b
LEFT JOIN pg_catalog.pg_settings s
    ON b.name = s.name
ORDER BY b.name;