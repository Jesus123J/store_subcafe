-- ============================================================
-- V3 — Pago mixto: una venta puede tener varias formas de pago (MySQL)
-- ============================================================

CREATE TABLE venta_pagos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    venta_id CHAR(36) NOT NULL,
    forma_pago ENUM('EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO') NOT NULL,
    monto DECIMAL(10,2) NOT NULL CHECK (monto > 0),
    codigo_operacion VARCHAR(20),
    trabajador_credito_id CHAR(36),
    orden INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_venta_pagos_venta FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
    CONSTRAINT fk_venta_pagos_trabajador FOREIGN KEY (trabajador_credito_id) REFERENCES usuarios(id),
    INDEX idx_venta_pagos_venta (venta_id),
    INDEX idx_venta_pagos_forma (forma_pago)
);

-- Migrar pagos existentes (1 fila por venta) a venta_pagos
INSERT INTO venta_pagos (venta_id, forma_pago, monto, trabajador_credito_id, orden)
SELECT id, forma_pago, total, trabajador_credito_id, 0
FROM ventas
WHERE forma_pago IS NOT NULL;

-- La columna forma_pago en ventas se mantiene para queries legacy/reportes,
-- pero ahora la fuente de verdad es venta_pagos (suma de monto = ventas.total)
-- MySQL no soporta DEFERRABLE triggers como PostgreSQL, asi que la validacion
-- de suma_pagos == total se hace en el codigo (CompraService/VentaService).

-- Vista de conveniencia: ventas con detalle de pagos como JSON
CREATE OR REPLACE VIEW v_ventas_con_pagos AS
SELECT
    v.id,
    v.fecha,
    v.total,
    v.caja_id,
    v.usuario_id,
    v.anulada,
    (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            'formaPago', vp.forma_pago,
            'monto', vp.monto,
            'codigoOperacion', vp.codigo_operacion,
            'trabajadorCreditoId', vp.trabajador_credito_id
        )
     )
     FROM venta_pagos vp
     WHERE vp.venta_id = v.id
    ) AS pagos
FROM ventas v;
