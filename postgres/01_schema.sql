-- NutriAnimales S.A. | Esquema PostgreSQL 16
-- Ejecutar como usuario administrador SOLO para instalación.
-- CREATE TABLE IF NOT EXISTS no valida estructuras existentes.

CREATE TABLE IF NOT EXISTS plantas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(150) NOT NULL,
    capacidad_produccion NUMERIC(12,2) CHECK (capacidad_produccion >= 0),
    estado VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('aves','cerdos','ganado','peces')),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS materias_primas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(80) NOT NULL,
    stock_actual NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
    proveedor VARCHAR(150)
);

CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('distribuidor','empresa','persona')),
    correo VARCHAR(255),
    segmento VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS lotes_produccion (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    planta_id INTEGER NOT NULL REFERENCES plantas(id),
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    cantidad_producida NUMERIC(14,2) NOT NULL CHECK (cantidad_producida > 0),
    fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estado VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS ventas (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id),
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    cantidad NUMERIC(14,2) NOT NULL CHECK (cantidad > 0),
    precio_total NUMERIC(14,2) NOT NULL CHECK (precio_total >= 0),
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estado VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS control_calidad (
    id SERIAL PRIMARY KEY,
    lote_id INTEGER NOT NULL REFERENCES lotes_produccion(id),
    parametro VARCHAR(120) NOT NULL,
    valor_obtenido NUMERIC(14,4) NOT NULL,
    valor_esperado NUMERIC(14,4) NOT NULL,
    aprobado BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS gastos (
    id SERIAL PRIMARY KEY,
    categoria VARCHAR(80) NOT NULL,
    descripcion TEXT,
    monto NUMERIC(14,2) NOT NULL CHECK (monto >= 0),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    aprobado_por VARCHAR(120)
);

CREATE TABLE IF NOT EXISTS auditoria_datos (
    id BIGSERIAL PRIMARY KEY,
    tabla VARCHAR(100) NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    usuario VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_cliente INET DEFAULT inet_client_addr(),
    fila_id INTEGER,
    valor_antes JSONB,
    valor_nuevo JSONB
);

CREATE TABLE IF NOT EXISTS backups (
    id BIGSERIAL PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estado VARCHAR(30) NOT NULL,
    ruta TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS alertas_auditoria (
    id BIGSERIAL PRIMARY KEY,
    tipo VARCHAR(60) NOT NULL,
    alerta VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    severidad VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS pg_settings_baseline (
    name TEXT PRIMARY KEY,
    valor_esperado TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_lotes_planta_id ON lotes_produccion(planta_id);
CREATE INDEX IF NOT EXISTS idx_lotes_producto_id ON lotes_produccion(producto_id);
CREATE INDEX IF NOT EXISTS idx_ventas_cliente_id ON ventas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ventas_producto_id ON ventas(producto_id);
CREATE INDEX IF NOT EXISTS idx_control_calidad_lote_id ON control_calidad(lote_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_tabla ON auditoria_datos(tabla);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria_datos(usuario);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria_datos(fecha);
