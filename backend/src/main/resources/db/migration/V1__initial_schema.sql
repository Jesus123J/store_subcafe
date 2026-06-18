-- ============================================================
-- V1 — Schema inicial (MySQL 8 / MariaDB)
-- ============================================================

-- ============================================================
-- USUARIOS
-- ============================================================
CREATE TABLE usuarios (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    rol ENUM('VENDEDOR', 'ENCARGADO', 'ADMINISTRADOR') NOT NULL DEFAULT 'VENDEDOR',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);

-- ============================================================
-- PROVEEDORES
-- ============================================================
CREATE TABLE proveedores (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    razon_social VARCHAR(200) NOT NULL,
    ruc VARCHAR(11) UNIQUE NOT NULL,
    direccion TEXT,
    telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);

-- ============================================================
-- PRODUCTOS
-- ============================================================
CREATE TABLE productos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    codigo VARCHAR(50) UNIQUE,
    descripcion VARCHAR(200) NOT NULL,
    stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_minimo DECIMAL(10,2) NOT NULL DEFAULT 0,
    es_servicio BOOLEAN NOT NULL DEFAULT FALSE,
    usa_contometro BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FULLTEXT KEY idx_productos_descripcion (descripcion)
);

CREATE TABLE producto_precios (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    producto_id CHAR(36) NOT NULL,
    costo DECIMAL(10,2) NOT NULL,
    precio_venta DECIMAL(10,2) NOT NULL,
    vigente_desde DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_producto_precios_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
    INDEX idx_producto_precios_vigencia (producto_id, vigente_desde DESC)
);

-- ============================================================
-- COMPRAS
-- ============================================================
CREATE TABLE compras (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    proveedor_id CHAR(36) NOT NULL,
    usuario_id CHAR(36) NOT NULL,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    total DECIMAL(10,2) NOT NULL,
    nro_documento VARCHAR(50),
    observaciones TEXT,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_compras_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(id),
    CONSTRAINT fk_compras_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

CREATE TABLE compra_detalle (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    compra_id CHAR(36) NOT NULL,
    producto_id CHAR(36) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    costo_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_compra_detalle_compra FOREIGN KEY (compra_id) REFERENCES compras(id) ON DELETE CASCADE,
    CONSTRAINT fk_compra_detalle_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
);

-- ============================================================
-- CAJAS / TURNOS
-- ============================================================
CREATE TABLE cajas (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    usuario_id CHAR(36) NOT NULL,
    turno ENUM('DIA', 'NOCHE') NOT NULL,
    fecha_apertura DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    fecha_cierre DATETIME(6),
    monto_apertura DECIMAL(10,2) NOT NULL DEFAULT 0,
    monto_cierre DECIMAL(10,2),
    contometro_inicio INT,
    contometro_fin INT,
    estado ENUM('ABIERTA', 'CERRADA') NOT NULL DEFAULT 'ABIERTA',
    CONSTRAINT fk_cajas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

CREATE TABLE avances_efectivo (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    caja_id CHAR(36) NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    observacion TEXT,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_avances_caja FOREIGN KEY (caja_id) REFERENCES cajas(id) ON DELETE CASCADE
);

-- ============================================================
-- VENTAS
-- ============================================================
CREATE TABLE ventas (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    caja_id CHAR(36) NOT NULL,
    usuario_id CHAR(36) NOT NULL,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    total DECIMAL(10,2) NOT NULL,
    forma_pago ENUM('EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO'),
    trabajador_credito_id CHAR(36),
    anulada BOOLEAN NOT NULL DEFAULT FALSE,
    anulada_por CHAR(36),
    motivo_anulacion TEXT,
    CONSTRAINT fk_ventas_caja FOREIGN KEY (caja_id) REFERENCES cajas(id),
    CONSTRAINT fk_ventas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ventas_trabajador FOREIGN KEY (trabajador_credito_id) REFERENCES usuarios(id),
    CONSTRAINT fk_ventas_anulada_por FOREIGN KEY (anulada_por) REFERENCES usuarios(id),
    INDEX idx_ventas_fecha (fecha DESC),
    INDEX idx_ventas_caja (caja_id)
);

CREATE TABLE venta_detalle (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    venta_id CHAR(36) NOT NULL,
    producto_id CHAR(36) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_venta_detalle_venta FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
    CONSTRAINT fk_venta_detalle_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
);

-- ============================================================
-- MERMAS
-- ============================================================
CREATE TABLE mermas (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    producto_id CHAR(36) NOT NULL,
    usuario_id CHAR(36) NOT NULL,
    cantidad DECIMAL(10,2) NOT NULL,
    motivo ENUM('VENCIMIENTO', 'DETERIORO', 'OTRO') NOT NULL,
    observacion TEXT,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_mermas_producto FOREIGN KEY (producto_id) REFERENCES productos(id),
    CONSTRAINT fk_mermas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

-- ============================================================
-- CREDITO A TRABAJADORES
-- ============================================================
CREATE TABLE creditos_trabajadores (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    trabajador_id CHAR(36) NOT NULL,
    venta_id CHAR(36),
    monto DECIMAL(10,2) NOT NULL,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    cerrado BOOLEAN NOT NULL DEFAULT FALSE,
    cerrado_en DATETIME(6),
    CONSTRAINT fk_creditos_trabajador FOREIGN KEY (trabajador_id) REFERENCES usuarios(id),
    CONSTRAINT fk_creditos_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
);

CREATE TABLE deuda_trabajadores (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    trabajador_id CHAR(36) NOT NULL UNIQUE,
    monto_total DECIMAL(10,2) NOT NULL DEFAULT 0,
    actualizada_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_deuda_trabajador FOREIGN KEY (trabajador_id) REFERENCES usuarios(id)
);

-- ============================================================
-- AUDITORIA
-- ============================================================
CREATE TABLE auditoria (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id CHAR(36),
    accion VARCHAR(50) NOT NULL,
    tabla VARCHAR(50) NOT NULL,
    registro_id VARCHAR(100),
    datos_previos JSON,
    datos_nuevos JSON,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    INDEX idx_auditoria_fecha (fecha DESC),
    INDEX idx_auditoria_usuario (usuario_id)
);
