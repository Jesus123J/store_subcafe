-- ============================================================
-- V1 — Esquema inicial Sistema Gestion Bodega (MySQL 8)
-- ============================================================
-- Estas tablas conviven en la MISMA base de datos que FinantialTracker
-- (financialtracker1). Ninguna tabla choca con las de ese sistema.
--
-- Convenciones:
--   * UUID           -> CHAR(36)  (legible en DBeaver / consultas SQL)
--   * enums          -> VARCHAR(20) + CHECK con los valores permitidos
--   * fechas         -> TIMESTAMP(6) (la sesion JDBC trabaja en America/Lima)
--   * booleanos      -> BOOLEAN (TINYINT(1))
--   * nombres de FK / CHECK son unicos por base de datos en MySQL,
--     por eso llevan el prefijo de la tabla.
-- ============================================================

-- ============================================================
-- USUARIOS (del sistema: vendedores, encargados, administradores)
-- ============================================================
CREATE TABLE usuarios (
    id              CHAR(36)      NOT NULL DEFAULT (UUID()),
    username        VARCHAR(50)   NOT NULL,
    password_hash   VARCHAR(255)  NOT NULL,
    nombre_completo VARCHAR(150)  NOT NULL,
    rol             VARCHAR(20)   NOT NULL DEFAULT 'VENDEDOR',
    activo          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en  TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_usuarios_username (username),
    CONSTRAINT chk_usuarios_rol CHECK (rol IN ('VENDEDOR', 'ENCARGADO', 'ADMINISTRADOR'))
) ENGINE = InnoDB;

-- ============================================================
-- PROVEEDORES
-- ============================================================
CREATE TABLE proveedores (
    id             CHAR(36)     NOT NULL DEFAULT (UUID()),
    razon_social   VARCHAR(200) NOT NULL,
    ruc            VARCHAR(11)  NOT NULL,
    direccion      TEXT,
    telefono       VARCHAR(20),
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_proveedores_ruc (ruc)
) ENGINE = InnoDB;

-- ============================================================
-- PRODUCTOS
-- ============================================================
CREATE TABLE productos (
    id             CHAR(36)      NOT NULL DEFAULT (UUID()),
    codigo         VARCHAR(50),
    descripcion    VARCHAR(200)  NOT NULL,
    stock          DECIMAL(10,2) NOT NULL DEFAULT 0,
    stock_minimo   DECIMAL(10,2) NOT NULL DEFAULT 0,
    es_servicio    BOOLEAN       NOT NULL DEFAULT FALSE,
    usa_contometro BOOLEAN       NOT NULL DEFAULT FALSE,
    es_bazar       BOOLEAN       NOT NULL DEFAULT FALSE,   -- canjeable con vales / puntos
    activo         BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_productos_codigo (codigo),
    FULLTEXT KEY ft_productos_descripcion (descripcion)
) ENGINE = InnoDB;

-- Historico de precios: el vigente es el de vigente_desde mas reciente
CREATE TABLE producto_precios (
    id            CHAR(36)      NOT NULL DEFAULT (UUID()),
    producto_id   CHAR(36)      NOT NULL,
    costo         DECIMAL(10,2) NOT NULL,
    precio_venta  DECIMAL(10,2) NOT NULL,
    vigente_desde TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_producto_precios_vigencia (producto_id, vigente_desde DESC),
    CONSTRAINT fk_producto_precios_producto FOREIGN KEY (producto_id)
        REFERENCES productos (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ============================================================
-- COMPRAS
-- ============================================================
CREATE TABLE compras (
    id            CHAR(36)      NOT NULL DEFAULT (UUID()),
    proveedor_id  CHAR(36)      NOT NULL,
    usuario_id    CHAR(36)      NOT NULL,
    fecha         TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    total         DECIMAL(10,2) NOT NULL,
    nro_documento VARCHAR(50),
    observaciones TEXT,
    creado_en     TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT fk_compras_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores (id),
    CONSTRAINT fk_compras_usuario   FOREIGN KEY (usuario_id)   REFERENCES usuarios (id)
) ENGINE = InnoDB;

CREATE TABLE compra_detalle (
    id             CHAR(36)      NOT NULL DEFAULT (UUID()),
    compra_id      CHAR(36)      NOT NULL,
    producto_id    CHAR(36)      NOT NULL,
    cantidad       DECIMAL(10,2) NOT NULL,
    costo_unitario DECIMAL(10,2) NOT NULL,
    subtotal       DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_compra_detalle_compra   FOREIGN KEY (compra_id)   REFERENCES compras (id) ON DELETE CASCADE,
    CONSTRAINT fk_compra_detalle_producto FOREIGN KEY (producto_id) REFERENCES productos (id)
) ENGINE = InnoDB;

-- ============================================================
-- CAJAS / TURNOS
-- ============================================================
CREATE TABLE cajas (
    id                CHAR(36)      NOT NULL DEFAULT (UUID()),
    usuario_id        CHAR(36)      NOT NULL,
    turno             VARCHAR(20)   NOT NULL,
    fecha_apertura    TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    fecha_cierre      TIMESTAMP(6)  NULL,
    monto_apertura    DECIMAL(10,2) NOT NULL DEFAULT 0,
    monto_cierre      DECIMAL(10,2),
    contometro_inicio INT,
    contometro_fin    INT,
    estado            VARCHAR(20)   NOT NULL DEFAULT 'ABIERTA',
    PRIMARY KEY (id),
    CONSTRAINT fk_cajas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT chk_cajas_turno  CHECK (turno  IN ('DIA', 'NOCHE')),
    CONSTRAINT chk_cajas_estado CHECK (estado IN ('ABIERTA', 'CERRADA'))
) ENGINE = InnoDB;

CREATE TABLE avances_efectivo (
    id          CHAR(36)      NOT NULL DEFAULT (UUID()),
    caja_id     CHAR(36)      NOT NULL,
    monto       DECIMAL(10,2) NOT NULL,
    observacion TEXT,
    fecha       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT fk_avances_efectivo_caja FOREIGN KEY (caja_id) REFERENCES cajas (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ============================================================
-- VENTAS
-- ============================================================
CREATE TABLE ventas (
    id                    CHAR(36)      NOT NULL DEFAULT (UUID()),
    caja_id               CHAR(36)      NOT NULL,
    usuario_id            CHAR(36)      NOT NULL,
    fecha                 TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    total                 DECIMAL(10,2) NOT NULL,
    -- DEPRECADO: una venta puede tener varias formas de pago (ver venta_pagos)
    forma_pago            VARCHAR(20)   NULL,
    -- DEPRECADO: usar venta_pagos.trabajador_credito_id
    trabajador_credito_id CHAR(36)      NULL,
    anulada               BOOLEAN       NOT NULL DEFAULT FALSE,
    anulada_por           CHAR(36)      NULL,
    motivo_anulacion      TEXT,
    PRIMARY KEY (id),
    KEY idx_ventas_fecha (fecha DESC),
    KEY idx_ventas_caja  (caja_id),
    CONSTRAINT fk_ventas_caja               FOREIGN KEY (caja_id)               REFERENCES cajas (id),
    CONSTRAINT fk_ventas_usuario            FOREIGN KEY (usuario_id)            REFERENCES usuarios (id),
    CONSTRAINT fk_ventas_trabajador_credito FOREIGN KEY (trabajador_credito_id) REFERENCES usuarios (id),
    CONSTRAINT fk_ventas_anulada_por        FOREIGN KEY (anulada_por)           REFERENCES usuarios (id),
    CONSTRAINT chk_ventas_forma_pago CHECK (forma_pago IN ('EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO'))
) ENGINE = InnoDB;

CREATE TABLE venta_detalle (
    id              CHAR(36)      NOT NULL DEFAULT (UUID()),
    venta_id        CHAR(36)      NOT NULL,
    producto_id     CHAR(36)      NOT NULL,
    cantidad        DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_venta_detalle_venta    FOREIGN KEY (venta_id)    REFERENCES ventas (id) ON DELETE CASCADE,
    CONSTRAINT fk_venta_detalle_producto FOREIGN KEY (producto_id) REFERENCES productos (id)
) ENGINE = InnoDB;

-- Pago mixto: cada fila es un pago parcial de la venta.
-- La suma de venta_pagos.monto debe coincidir con ventas.total.
-- (En PostgreSQL esto era un trigger diferido; MySQL no soporta triggers
--  diferidos, asi que la validacion vive en el servicio de ventas.)
CREATE TABLE venta_pagos (
    id                    CHAR(36)      NOT NULL DEFAULT (UUID()),
    venta_id              CHAR(36)      NOT NULL,
    forma_pago            VARCHAR(20)   NOT NULL,
    monto                 DECIMAL(10,2) NOT NULL,
    codigo_operacion      VARCHAR(20),            -- yape/plin: codigo del comprobante
    trabajador_credito_id CHAR(36)      NULL,
    orden                 INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_venta_pagos_venta (venta_id),
    KEY idx_venta_pagos_forma (forma_pago),
    CONSTRAINT fk_venta_pagos_venta      FOREIGN KEY (venta_id)              REFERENCES ventas (id) ON DELETE CASCADE,
    CONSTRAINT fk_venta_pagos_trabajador FOREIGN KEY (trabajador_credito_id) REFERENCES usuarios (id),
    CONSTRAINT chk_venta_pagos_monto      CHECK (monto > 0),
    CONSTRAINT chk_venta_pagos_forma_pago CHECK (forma_pago IN ('EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO'))
) ENGINE = InnoDB;

-- ============================================================
-- MERMAS
-- ============================================================
CREATE TABLE mermas (
    id          CHAR(36)      NOT NULL DEFAULT (UUID()),
    producto_id CHAR(36)      NOT NULL,
    usuario_id  CHAR(36)      NOT NULL,
    cantidad    DECIMAL(10,2) NOT NULL,
    motivo      VARCHAR(20)   NOT NULL,
    observacion TEXT,
    fecha       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT fk_mermas_producto FOREIGN KEY (producto_id) REFERENCES productos (id),
    CONSTRAINT fk_mermas_usuario  FOREIGN KEY (usuario_id)  REFERENCES usuarios (id),
    CONSTRAINT chk_mermas_motivo CHECK (motivo IN ('VENCIMIENTO', 'DETERIORO', 'OTRO'))
) ENGINE = InnoDB;

-- ============================================================
-- CREDITO A TRABAJADORES (ciclo mensual)
-- ============================================================
CREATE TABLE creditos_trabajadores (
    id            CHAR(36)      NOT NULL DEFAULT (UUID()),
    trabajador_id CHAR(36)      NOT NULL,
    venta_id      CHAR(36)      NULL,
    monto         DECIMAL(10,2) NOT NULL,
    fecha         TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    cerrado       BOOLEAN       NOT NULL DEFAULT FALSE,
    cerrado_en    TIMESTAMP(6)  NULL,
    periodo_anio  INT           NOT NULL DEFAULT (YEAR(CURRENT_DATE)),
    periodo_mes   INT           NOT NULL DEFAULT (MONTH(CURRENT_DATE)),
    PRIMARY KEY (id),
    KEY idx_creditos_periodo (trabajador_id, periodo_anio, periodo_mes, cerrado),
    CONSTRAINT fk_creditos_trabajador FOREIGN KEY (trabajador_id) REFERENCES usuarios (id),
    CONSTRAINT fk_creditos_venta      FOREIGN KEY (venta_id)      REFERENCES ventas (id)
) ENGINE = InnoDB;

-- Deuda acumulada de meses cerrados (lo que va a planilla)
CREATE TABLE deuda_trabajadores (
    id             CHAR(36)      NOT NULL DEFAULT (UUID()),
    trabajador_id  CHAR(36)      NOT NULL,
    monto_total    DECIMAL(10,2) NOT NULL DEFAULT 0,
    actualizada_en TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_deuda_trabajador (trabajador_id),
    CONSTRAINT fk_deuda_trabajador FOREIGN KEY (trabajador_id) REFERENCES usuarios (id)
) ENGINE = InnoDB;

-- Historico de cierres mensuales
CREATE TABLE cierres_mensuales_creditos (
    id                     CHAR(36)      NOT NULL DEFAULT (UUID()),
    anio                   INT           NOT NULL,
    mes                    INT           NOT NULL,
    fecha_cierre           TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    cerrado_por            CHAR(36)      NULL,
    trabajadores_afectados INT           NOT NULL DEFAULT 0,
    monto_total            DECIMAL(12,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_cierres_periodo (anio, mes),
    CONSTRAINT fk_cierres_cerrado_por FOREIGN KEY (cerrado_por) REFERENCES usuarios (id),
    CONSTRAINT chk_cierres_mes CHECK (mes BETWEEN 1 AND 12)
) ENGINE = InnoDB;

-- ============================================================
-- AUDITORIA
-- ============================================================
CREATE TABLE auditoria (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    usuario_id    CHAR(36)     NULL,
    accion        VARCHAR(50)  NOT NULL,
    tabla         VARCHAR(50)  NOT NULL,
    registro_id   VARCHAR(100),
    datos_previos JSON,
    datos_nuevos  JSON,
    fecha         TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_auditoria_fecha   (fecha DESC),
    KEY idx_auditoria_usuario (usuario_id),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
) ENGINE = InnoDB;

-- ============================================================
-- CONFIGURACION (key-value editable por el admin)
-- ============================================================
CREATE TABLE configuracion (
    clave          VARCHAR(80)  NOT NULL,
    valor          TEXT,
    descripcion    TEXT,
    actualizada_en TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (clave)
) ENGINE = InnoDB;

-- ============================================================
-- CLIENTES / TRABAJADORES (reciben vales y puntos)
-- ============================================================
CREATE TABLE clientes (
    id             CHAR(36)     NOT NULL DEFAULT (UUID()),
    dni            VARCHAR(8)   NOT NULL,
    nombres        VARCHAR(150) NOT NULL,
    apellidos      VARCHAR(150) NOT NULL,
    telefono       VARCHAR(20),
    es_trabajador  BOOLEAN      NOT NULL DEFAULT TRUE,
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_clientes_dni (dni),
    FULLTEXT KEY ft_clientes_nombre (nombres, apellidos)
) ENGINE = InnoDB;

-- ============================================================
-- VALES A TRABAJADORES
-- ============================================================
CREATE TABLE vales (
    id                CHAR(36)      NOT NULL DEFAULT (UUID()),
    codigo            VARCHAR(20)   NOT NULL,          -- ej: V-2026-000001
    tipo              VARCHAR(20)   NOT NULL,
    cliente_id        CHAR(36)      NULL,              -- NULL si es CASH (al portador)
    monto_inicial     DECIMAL(10,2) NOT NULL,
    saldo             DECIMAL(10,2) NOT NULL,
    estado            VARCHAR(20)   NOT NULL DEFAULT 'ACTIVO',
    fecha_emision     TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    fecha_vencimiento DATE          NULL,              -- NULL = sin vencer
    emitido_por       CHAR(36)      NULL,
    observaciones     TEXT,
    PRIMARY KEY (id),
    UNIQUE KEY uk_vales_codigo (codigo),
    KEY idx_vales_cliente (cliente_id),
    KEY idx_vales_estado  (estado),
    CONSTRAINT fk_vales_cliente     FOREIGN KEY (cliente_id)  REFERENCES clientes (id),
    CONSTRAINT fk_vales_emitido_por FOREIGN KEY (emitido_por) REFERENCES usuarios (id),
    CONSTRAINT chk_vales_tipo          CHECK (tipo   IN ('CASH', 'NOMBRADO')),
    CONSTRAINT chk_vales_estado        CHECK (estado IN ('ACTIVO', 'CONSUMIDO', 'VENCIDO', 'ANULADO')),
    CONSTRAINT chk_vales_monto_inicial CHECK (monto_inicial > 0),
    CONSTRAINT chk_vales_saldo         CHECK (saldo >= 0)
) ENGINE = InnoDB;

CREATE TABLE vale_movimientos (
    id            CHAR(36)      NOT NULL DEFAULT (UUID()),
    vale_id       CHAR(36)      NOT NULL,
    venta_id      CHAR(36)      NULL,
    monto         DECIMAL(10,2) NOT NULL,
    saldo_despues DECIMAL(10,2) NOT NULL,
    fecha         TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    usuario_id    CHAR(36)      NULL,
    PRIMARY KEY (id),
    KEY idx_vale_movimientos_vale (vale_id),
    CONSTRAINT fk_vale_movimientos_vale    FOREIGN KEY (vale_id)    REFERENCES vales (id) ON DELETE CASCADE,
    CONSTRAINT fk_vale_movimientos_venta   FOREIGN KEY (venta_id)   REFERENCES ventas (id),
    CONSTRAINT fk_vale_movimientos_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
) ENGINE = InnoDB;

-- ============================================================
-- PUNTOS POR CONSUMO
-- ============================================================
CREATE TABLE reglas_puntos (
    id              CHAR(36)      NOT NULL DEFAULT (UUID()),
    descripcion     VARCHAR(200)  NOT NULL,
    soles_por_punto DECIMAL(10,2) NOT NULL,
    activa          BOOLEAN       NOT NULL DEFAULT TRUE,
    vigente_desde   TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    vigente_hasta   TIMESTAMP(6)  NULL,
    creado_en       TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT chk_reglas_puntos_soles CHECK (soles_por_punto > 0)
) ENGINE = InnoDB;

CREATE TABLE productos_canjeables (
    id                CHAR(36)      NOT NULL DEFAULT (UUID()),
    producto_id       CHAR(36)      NOT NULL,
    puntos_requeridos DECIMAL(10,2) NOT NULL,
    activo            BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en         TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_productos_canjeables_producto (producto_id),
    CONSTRAINT fk_productos_canjeables_producto FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE,
    CONSTRAINT chk_productos_canjeables_puntos CHECK (puntos_requeridos > 0)
) ENGINE = InnoDB;

CREATE TABLE movimientos_puntos (
    id            CHAR(36)      NOT NULL DEFAULT (UUID()),
    cliente_id    CHAR(36)      NOT NULL,
    tipo          VARCHAR(20)   NOT NULL,
    puntos        DECIMAL(10,2) NOT NULL,       -- positivo o negativo segun tipo
    saldo_despues DECIMAL(10,2) NOT NULL,
    venta_id      CHAR(36)      NULL,
    observacion   TEXT,
    fecha         TIMESTAMP(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_movimientos_puntos_cliente (cliente_id, fecha DESC),
    CONSTRAINT fk_movimientos_puntos_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id),
    CONSTRAINT fk_movimientos_puntos_venta   FOREIGN KEY (venta_id)   REFERENCES ventas (id),
    CONSTRAINT chk_movimientos_puntos_tipo CHECK (tipo IN ('ACUMULACION', 'CANJE', 'AJUSTE', 'VENCIMIENTO'))
) ENGINE = InnoDB;

-- ============================================================
-- VISTAS
-- ============================================================

-- Stock actual con el precio vigente (ultimo producto_precios) y alerta de minimo
CREATE OR REPLACE VIEW v_stock_actual AS
SELECT p.id,
       p.codigo,
       p.descripcion,
       p.stock,
       p.stock_minimo,
       p.es_servicio,
       p.es_bazar,
       p.usa_contometro,
       pp.costo,
       pp.precio_venta,
       (p.es_servicio = FALSE AND p.stock <= p.stock_minimo) AS bajo_minimo
FROM productos p
LEFT JOIN producto_precios pp
       ON pp.id = (SELECT pp2.id
                   FROM producto_precios pp2
                   WHERE pp2.producto_id = p.id
                   ORDER BY pp2.vigente_desde DESC, pp2.id DESC
                   LIMIT 1)
WHERE p.activo = TRUE;

-- Ventas con sus pagos como JSON
CREATE OR REPLACE VIEW v_ventas_con_pagos AS
SELECT v.id,
       v.fecha,
       v.total,
       v.caja_id,
       v.usuario_id,
       v.anulada,
       (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                   'formaPago',           vp.forma_pago,
                   'monto',               vp.monto,
                   'codigoOperacion',     vp.codigo_operacion,
                   'trabajadorCreditoId', vp.trabajador_credito_id,
                   'orden',               vp.orden))
        FROM venta_pagos vp
        WHERE vp.venta_id = v.id) AS pagos
FROM ventas v;

-- Saldo actual de puntos por cliente
CREATE OR REPLACE VIEW v_puntos_por_cliente AS
SELECT c.id AS cliente_id,
       c.dni,
       c.nombres,
       c.apellidos,
       COALESCE(SUM(mp.puntos), 0) AS saldo_puntos
FROM clientes c
LEFT JOIN movimientos_puntos mp ON mp.cliente_id = c.id
GROUP BY c.id, c.dni, c.nombres, c.apellidos;

-- Creditos del mes actual NO cerrados, agrupados por trabajador
CREATE OR REPLACE VIEW v_creditos_del_mes AS
SELECT t.id AS trabajador_id,
       t.username,
       t.nombre_completo,
       COUNT(c.id)               AS cantidad_consumos,
       COALESCE(SUM(c.monto), 0) AS monto_pendiente,
       MAX(c.fecha)              AS ultimo_consumo,
       YEAR(CURRENT_DATE)        AS anio,
       MONTH(CURRENT_DATE)       AS mes
FROM usuarios t
JOIN creditos_trabajadores c
  ON c.trabajador_id = t.id
 AND c.cerrado = FALSE
 AND c.periodo_anio = YEAR(CURRENT_DATE)
 AND c.periodo_mes  = MONTH(CURRENT_DATE)
GROUP BY t.id, t.username, t.nombre_completo;

-- Deuda acumulada de meses anteriores (la que va a planilla)
CREATE OR REPLACE VIEW v_deuda_trabajadores_acumulada AS
SELECT t.id AS trabajador_id,
       t.username,
       t.nombre_completo,
       d.monto_total AS deuda_acumulada,
       d.actualizada_en
FROM usuarios t
JOIN deuda_trabajadores d ON d.trabajador_id = t.id
WHERE d.monto_total > 0;
