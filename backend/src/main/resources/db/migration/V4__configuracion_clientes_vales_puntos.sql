-- ============================================================
-- V4 — Configuracion, Clientes (trabajadores externos), Vales y Puntos
-- ============================================================

-- ============================================================
-- CONFIGURACION (Issue #6)
-- ============================================================
-- Tabla key-value para todos los datos editables del negocio
CREATE TABLE configuracion (
    clave VARCHAR(80) PRIMARY KEY,
    valor TEXT,
    descripcion TEXT,
    actualizada_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('negocio.razon_social', 'Sub Cafe',                'Razon social del negocio'),
    ('negocio.ruc',          '20000000000',             'RUC del negocio'),
    ('negocio.direccion',    'Av. Principal 123',       'Direccion fiscal'),
    ('negocio.telefono',     '999000000',               'Telefono de contacto'),
    ('pagos.yape_numero',    '',                        'Numero Yape del negocio'),
    ('pagos.plin_numero',    '',                        'Numero Plin del negocio'),
    ('impresora.ip',         '',                        'IP impresora termica'),
    ('impresora.modo',       'red',                     'Modo: red | usb');


-- ============================================================
-- CLIENTES / TRABAJADORES (Issue #5)
-- ============================================================
-- Tabla para trabajadores del negocio donde se entregan vales/puntos.
-- Importable desde el sistema viejo de prestamos.
CREATE TABLE clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dni VARCHAR(8) UNIQUE NOT NULL,
    nombres VARCHAR(150) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    es_trabajador BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clientes_dni ON clientes(dni);
CREATE INDEX idx_clientes_nombre ON clientes USING gin (
    to_tsvector('spanish', nombres || ' ' || apellidos)
);


-- ============================================================
-- VALES A TRABAJADORES (Issue #2)
-- ============================================================
CREATE TYPE tipo_vale AS ENUM ('CASH', 'NOMBRADO');
CREATE TYPE estado_vale AS ENUM ('ACTIVO', 'CONSUMIDO', 'VENCIDO', 'ANULADO');

CREATE TABLE vales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(20) UNIQUE NOT NULL,         -- ej: V-2026-000001
    tipo tipo_vale NOT NULL,
    cliente_id UUID REFERENCES clientes(id),    -- NULL si es CASH (al portador)
    monto_inicial NUMERIC(10,2) NOT NULL CHECK (monto_inicial > 0),
    saldo NUMERIC(10,2) NOT NULL CHECK (saldo >= 0),
    estado estado_vale NOT NULL DEFAULT 'ACTIVO',
    fecha_emision TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_vencimiento DATE,                     -- NULL = sin vencer
    emitido_por UUID REFERENCES usuarios(id),
    observaciones TEXT
);

CREATE INDEX idx_vales_codigo ON vales(codigo);
CREATE INDEX idx_vales_cliente ON vales(cliente_id) WHERE cliente_id IS NOT NULL;
CREATE INDEX idx_vales_estado ON vales(estado);

-- Movimientos: cada uso parcial o total del vale
CREATE TABLE vale_movimientos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vale_id UUID NOT NULL REFERENCES vales(id) ON DELETE CASCADE,
    venta_id UUID REFERENCES ventas(id),
    monto NUMERIC(10,2) NOT NULL,
    saldo_despues NUMERIC(10,2) NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    usuario_id UUID REFERENCES usuarios(id)
);

CREATE INDEX idx_vale_movimientos_vale ON vale_movimientos(vale_id);


-- ============================================================
-- PUNTOS POR CONSUMO (Issue #3)
-- ============================================================
-- Reglas de acumulacion (1 regla activa a la vez; historico)
CREATE TABLE reglas_puntos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    descripcion VARCHAR(200) NOT NULL,
    soles_por_punto NUMERIC(10,2) NOT NULL CHECK (soles_por_punto > 0),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    vigente_desde TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    vigente_hasta TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Regla por defecto: 1 punto por cada S/. 10 de consumo (ajustable)
INSERT INTO reglas_puntos (descripcion, soles_por_punto)
VALUES ('Regla base: 1 punto por cada S/. 10 de consumo', 10.00);

-- Catalogo de productos canjeables por puntos (lo define el admin)
CREATE TABLE productos_canjeables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    puntos_requeridos NUMERIC(10,2) NOT NULL CHECK (puntos_requeridos > 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (producto_id)
);

-- Movimientos de puntos: + por compra, - por canje
CREATE TYPE tipo_movimiento_puntos AS ENUM ('ACUMULACION', 'CANJE', 'AJUSTE', 'VENCIMIENTO');

CREATE TABLE movimientos_puntos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID NOT NULL REFERENCES clientes(id),
    tipo tipo_movimiento_puntos NOT NULL,
    puntos NUMERIC(10,2) NOT NULL,           -- positivo o negativo segun tipo
    saldo_despues NUMERIC(10,2) NOT NULL,
    venta_id UUID REFERENCES ventas(id),
    observacion TEXT,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_movimientos_puntos_cliente ON movimientos_puntos(cliente_id, fecha DESC);

-- Vista helper: saldo actual de puntos por cliente
CREATE OR REPLACE VIEW v_puntos_por_cliente AS
SELECT c.id AS cliente_id,
       c.dni,
       c.nombres,
       c.apellidos,
       COALESCE(SUM(mp.puntos), 0) AS saldo_puntos
FROM clientes c
LEFT JOIN movimientos_puntos mp ON mp.cliente_id = c.id
GROUP BY c.id, c.dni, c.nombres, c.apellidos;
