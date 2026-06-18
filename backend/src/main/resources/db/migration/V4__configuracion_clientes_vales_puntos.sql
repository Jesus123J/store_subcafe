-- ============================================================
-- V4 — Configuracion, Clientes, Vales y Puntos (MySQL)
-- ============================================================

-- ============================================================
-- CONFIGURACION
-- ============================================================
CREATE TABLE configuracion (
    clave VARCHAR(80) PRIMARY KEY,
    valor TEXT,
    descripcion TEXT,
    actualizada_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
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
-- CLIENTES / TRABAJADORES
-- ============================================================
CREATE TABLE clientes (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    dni VARCHAR(8) UNIQUE NOT NULL,
    nombres VARCHAR(150) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    es_trabajador BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_clientes_dni (dni),
    FULLTEXT KEY idx_clientes_nombre (nombres, apellidos)
);


-- ============================================================
-- VALES A TRABAJADORES
-- ============================================================
CREATE TABLE vales (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    codigo VARCHAR(20) UNIQUE NOT NULL,
    tipo ENUM('CASH', 'NOMBRADO') NOT NULL,
    cliente_id CHAR(36),
    monto_inicial DECIMAL(10,2) NOT NULL CHECK (monto_inicial > 0),
    saldo DECIMAL(10,2) NOT NULL CHECK (saldo >= 0),
    estado ENUM('ACTIVO', 'CONSUMIDO', 'VENCIDO', 'ANULADO') NOT NULL DEFAULT 'ACTIVO',
    fecha_emision DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    fecha_vencimiento DATE,
    emitido_por CHAR(36),
    observaciones TEXT,
    CONSTRAINT fk_vales_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    CONSTRAINT fk_vales_emisor FOREIGN KEY (emitido_por) REFERENCES usuarios(id),
    INDEX idx_vales_codigo (codigo),
    INDEX idx_vales_cliente (cliente_id),
    INDEX idx_vales_estado (estado)
);

CREATE TABLE vale_movimientos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    vale_id CHAR(36) NOT NULL,
    venta_id CHAR(36),
    monto DECIMAL(10,2) NOT NULL,
    saldo_despues DECIMAL(10,2) NOT NULL,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    usuario_id CHAR(36),
    CONSTRAINT fk_vm_vale FOREIGN KEY (vale_id) REFERENCES vales(id) ON DELETE CASCADE,
    CONSTRAINT fk_vm_venta FOREIGN KEY (venta_id) REFERENCES ventas(id),
    CONSTRAINT fk_vm_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    INDEX idx_vale_movimientos_vale (vale_id)
);


-- ============================================================
-- PUNTOS POR CONSUMO
-- ============================================================
CREATE TABLE reglas_puntos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    descripcion VARCHAR(200) NOT NULL,
    soles_por_punto DECIMAL(10,2) NOT NULL CHECK (soles_por_punto > 0),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    vigente_desde DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    vigente_hasta DATETIME(6),
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);

INSERT INTO reglas_puntos (descripcion, soles_por_punto)
VALUES ('Regla base: 1 punto por cada S/. 10 de consumo', 10.00);

CREATE TABLE productos_canjeables (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    producto_id CHAR(36) NOT NULL UNIQUE,
    puntos_requeridos DECIMAL(10,2) NOT NULL CHECK (puntos_requeridos > 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_canjeables_producto FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
);

CREATE TABLE movimientos_puntos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    cliente_id CHAR(36) NOT NULL,
    tipo ENUM('ACUMULACION', 'CANJE', 'AJUSTE', 'VENCIMIENTO') NOT NULL,
    puntos DECIMAL(10,2) NOT NULL,
    saldo_despues DECIMAL(10,2) NOT NULL,
    venta_id CHAR(36),
    observacion TEXT,
    fecha DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_mp_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    CONSTRAINT fk_mp_venta FOREIGN KEY (venta_id) REFERENCES ventas(id),
    INDEX idx_mp_cliente (cliente_id, fecha DESC)
);

CREATE OR REPLACE VIEW v_puntos_por_cliente AS
SELECT c.id AS cliente_id,
       c.dni,
       c.nombres,
       c.apellidos,
       COALESCE(SUM(mp.puntos), 0) AS saldo_puntos
FROM clientes c
LEFT JOIN movimientos_puntos mp ON mp.cliente_id = c.id
GROUP BY c.id, c.dni, c.nombres, c.apellidos;
