-- ============================================================
-- V1 — Schema inicial Sistema Gestion Bodega
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USUARIOS
-- ============================================================
CREATE TYPE rol_usuario AS ENUM ('VENDEDOR', 'ENCARGADO', 'ADMINISTRADOR');

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    rol rol_usuario NOT NULL DEFAULT 'VENDEDOR',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PROVEEDORES
-- ============================================================
CREATE TABLE proveedores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    razon_social VARCHAR(200) NOT NULL,
    ruc VARCHAR(11) UNIQUE NOT NULL,
    direccion TEXT,
    telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PRODUCTOS
-- ============================================================
CREATE TABLE productos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(50) UNIQUE,
    descripcion VARCHAR(200) NOT NULL,
    stock NUMERIC(10,2) NOT NULL DEFAULT 0,
    stock_minimo NUMERIC(10,2) NOT NULL DEFAULT 0,
    es_servicio BOOLEAN NOT NULL DEFAULT FALSE,
    usa_contometro BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_productos_descripcion ON productos USING gin (to_tsvector('spanish', descripcion));

CREATE TABLE producto_precios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
    costo NUMERIC(10,2) NOT NULL,
    precio_venta NUMERIC(10,2) NOT NULL,
    vigente_desde TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_producto_precios_vigencia ON producto_precios(producto_id, vigente_desde DESC);

-- ============================================================
-- COMPRAS
-- ============================================================
CREATE TABLE compras (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proveedor_id UUID NOT NULL REFERENCES proveedores(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total NUMERIC(10,2) NOT NULL,
    nro_documento VARCHAR(50),
    observaciones TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE compra_detalle (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    compra_id UUID NOT NULL REFERENCES compras(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES productos(id),
    cantidad NUMERIC(10,2) NOT NULL,
    costo_unitario NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL
);

-- ============================================================
-- CAJAS / TURNOS
-- ============================================================
CREATE TYPE tipo_turno AS ENUM ('DIA', 'NOCHE');
CREATE TYPE estado_caja AS ENUM ('ABIERTA', 'CERRADA');

CREATE TABLE cajas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    turno tipo_turno NOT NULL,
    fecha_apertura TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_cierre TIMESTAMPTZ,
    monto_apertura NUMERIC(10,2) NOT NULL DEFAULT 0,
    monto_cierre NUMERIC(10,2),
    contometro_inicio INTEGER,
    contometro_fin INTEGER,
    estado estado_caja NOT NULL DEFAULT 'ABIERTA'
);

CREATE TABLE avances_efectivo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caja_id UUID NOT NULL REFERENCES cajas(id) ON DELETE CASCADE,
    monto NUMERIC(10,2) NOT NULL,
    observacion TEXT,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- VENTAS
-- ============================================================
CREATE TYPE forma_pago AS ENUM ('EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO');

CREATE TABLE ventas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caja_id UUID NOT NULL REFERENCES cajas(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total NUMERIC(10,2) NOT NULL,
    forma_pago forma_pago NOT NULL,
    trabajador_credito_id UUID REFERENCES usuarios(id),
    anulada BOOLEAN NOT NULL DEFAULT FALSE,
    anulada_por UUID REFERENCES usuarios(id),
    motivo_anulacion TEXT
);

CREATE INDEX idx_ventas_fecha ON ventas(fecha DESC);
CREATE INDEX idx_ventas_caja ON ventas(caja_id);

CREATE TABLE venta_detalle (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id UUID NOT NULL REFERENCES productos(id),
    cantidad NUMERIC(10,2) NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL
);

-- ============================================================
-- MERMAS
-- ============================================================
CREATE TYPE motivo_merma AS ENUM ('VENCIMIENTO', 'DETERIORO', 'OTRO');

CREATE TABLE mermas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    producto_id UUID NOT NULL REFERENCES productos(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    cantidad NUMERIC(10,2) NOT NULL,
    motivo motivo_merma NOT NULL,
    observacion TEXT,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CREDITO A TRABAJADORES
-- ============================================================
CREATE TABLE creditos_trabajadores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trabajador_id UUID NOT NULL REFERENCES usuarios(id),
    venta_id UUID REFERENCES ventas(id),
    monto NUMERIC(10,2) NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cerrado BOOLEAN NOT NULL DEFAULT FALSE,
    cerrado_en TIMESTAMPTZ
);

CREATE TABLE deuda_trabajadores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trabajador_id UUID NOT NULL REFERENCES usuarios(id),
    monto_total NUMERIC(10,2) NOT NULL DEFAULT 0,
    actualizada_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_deuda_trabajador ON deuda_trabajadores(trabajador_id);

-- ============================================================
-- AUDITORIA
-- ============================================================
CREATE TABLE auditoria (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID REFERENCES usuarios(id),
    accion VARCHAR(50) NOT NULL,
    tabla VARCHAR(50) NOT NULL,
    registro_id VARCHAR(100),
    datos_previos JSONB,
    datos_nuevos JSONB,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auditoria_fecha ON auditoria(fecha DESC);
CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id);
