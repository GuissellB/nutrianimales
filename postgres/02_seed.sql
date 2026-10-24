-- NutriAnimales S.A. | Datos ficticios de prueba (PostgreSQL 16)
-- Orden: tablas independientes antes de tablas con claves foráneas.
-- Reejecutable: ON CONFLICT (id) DO NOTHING evita insertar los mismos IDs dos veces.
-- No contiene datos personales reales.

INSERT INTO plantas (id, nombre, ubicacion, capacidad_produccion, estado)
VALUES (1, 'Planta Alajuela', 'Alajuela', 15000.00, 'activa'),
       (2, 'Planta Heredia', 'Heredia', 12000.00, 'activa'),
       (3, 'Planta Cartago', 'Cartago', 10000.00, 'activa')
ON CONFLICT (id) DO NOTHING;

INSERT INTO productos (id, codigo, nombre, tipo, precio_unitario, activo)
SELECT n, 'PROD-' || lpad(n::text, 4, '0'),
       'Alimento balanceado ' || n,
       (ARRAY['aves','cerdos','ganado','peces'])[1 + (n - 1) % 4],
       (2500 + n * 37.5)::numeric(12,2),
       n % 10 <> 0
FROM generate_series(1, 50) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO materias_primas (id, nombre, categoria, stock_actual, stock_minimo, proveedor)
SELECT n, 'Materia prima ' || n,
       (ARRAY['cereal','proteina','mineral','vitamina'])[1 + (n - 1) % 4],
       (150 + n * 3)::numeric(14,2), 100.00,
       'Proveedor ficticio ' || (1 + (n - 1) % 10)
FROM generate_series(1, 100) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO clientes (id, nombre, tipo, correo, segmento)
SELECT n, 'Cliente ficticio ' || n,
       (ARRAY['distribuidor','empresa','persona'])[1 + (n - 1) % 3],
       'cliente' || n || '@example.com',
       (ARRAY['mayorista','regional','minorista'])[1 + (n - 1) % 3]
FROM generate_series(1, 200) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO lotes_produccion
    (id, codigo, planta_id, producto_id, cantidad_producida, fecha_inicio, estado)
SELECT n, 'LOTE-' || lpad(n::text, 5, '0'),
       1 + (n - 1) % 3,
       1 + (n - 1) % 50,
       (100 + n * 2)::numeric(14,2),
       TIMESTAMPTZ '2026-10-01 08:00:00-06' + ((n - 1) % 20) * INTERVAL '1 day',
       (ARRAY['producido','en_proceso','pendiente'])[1 + (n - 1) % 3]
FROM generate_series(1, 500) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO ventas
    (id, cliente_id, producto_id, cantidad, precio_total, fecha, estado)
SELECT n, 1 + (n - 1) % 200,
       1 + (n - 1) % 50,
       (1 + n % 15)::numeric(14,2),
       ((1 + n % 15) * (2500 + (1 + (n - 1) % 50) * 37.5))::numeric(14,2),
       TIMESTAMPTZ '2026-10-01 09:00:00-06' + ((n - 1) % 20) * INTERVAL '1 day',
       (ARRAY['confirmada','pendiente','despachada'])[1 + (n - 1) % 3]
FROM generate_series(1, 1000) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO control_calidad
    (id, lote_id, parametro, valor_obtenido, valor_esperado, aprobado)
SELECT n, n,
       (ARRAY['humedad','proteina','densidad'])[1 + (n - 1) % 3],
       (10 + (n % 7) * 0.5)::numeric(14,4),
       12.0000,
       (n % 7) BETWEEN 2 AND 6
FROM generate_series(1, 300) AS n
ON CONFLICT (id) DO NOTHING;

INSERT INTO gastos (id, categoria, descripcion, monto, fecha, aprobado_por)
SELECT n,
       (ARRAY['operacion','mantenimiento','logistica','personal'])[1 + (n - 1) % 4],
       'Gasto ficticio ' || n,
       (5000 + n * 80)::numeric(14,2),
       DATE '2026-10-01' + ((n - 1) % 20),
       'Supervisor ficticio ' || (1 + (n - 1) % 5)
FROM generate_series(1, 200) AS n
ON CONFLICT (id) DO NOTHING;

-- Sincronizar las secuencias SERIAL para que los futuros INSERT sin ID no colisionen.
-- GREATEST protege las secuencias incluso si se ejecuta el seed en otra instalación.
SELECT setval(pg_get_serial_sequence('plantas','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM plantas), 1));
SELECT setval(pg_get_serial_sequence('productos','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM productos), 1));
SELECT setval(pg_get_serial_sequence('materias_primas','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM materias_primas), 1));
SELECT setval(pg_get_serial_sequence('clientes','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM clientes), 1));
SELECT setval(pg_get_serial_sequence('lotes_produccion','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM lotes_produccion), 1));
SELECT setval(pg_get_serial_sequence('ventas','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM ventas), 1));
SELECT setval(pg_get_serial_sequence('control_calidad','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM control_calidad), 1));
SELECT setval(pg_get_serial_sequence('gastos','id'),
              GREATEST((SELECT COALESCE(MAX(id), 1) FROM gastos), 1));
