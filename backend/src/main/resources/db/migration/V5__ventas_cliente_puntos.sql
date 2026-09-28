-- ============================================================
-- V5 — Cliente identificado en la venta (para acumular puntos)
-- ============================================================
-- El POS puede identificar al trabajador que compra aunque pague al
-- contado; con eso se acumulan puntos segun la regla activa.
ALTER TABLE ventas
    ADD COLUMN cliente_id CHAR(36) NULL COMMENT 'Trabajador identificado en la venta (puntos)' AFTER usuario_id,
    ADD KEY idx_ventas_cliente (cliente_id),
    ADD CONSTRAINT fk_ventas_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id);

-- Referencia de la venta en los movimientos de puntos ya existia (venta_id).
-- Evita acumular dos veces por la misma venta.
ALTER TABLE movimientos_puntos
    ADD UNIQUE KEY uk_movimientos_puntos_venta_tipo (venta_id, tipo);
