-- ============================================================
-- V3 — Pago mixto: una venta puede tener varias formas de pago
-- ============================================================

-- Tabla nueva para representar cada pago parcial de una venta
CREATE TABLE venta_pagos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venta_id UUID NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    forma_pago forma_pago NOT NULL,
    monto NUMERIC(10,2) NOT NULL CHECK (monto > 0),
    codigo_operacion VARCHAR(20),         -- yape/plin: codigo del comprobante
    trabajador_credito_id UUID REFERENCES usuarios(id),
    orden INTEGER NOT NULL DEFAULT 0      -- orden en que se ingresaron los pagos
);

CREATE INDEX idx_venta_pagos_venta ON venta_pagos(venta_id);
CREATE INDEX idx_venta_pagos_forma ON venta_pagos(forma_pago);

-- Migrar los pagos existentes de ventas (1 fila por venta) a venta_pagos
INSERT INTO venta_pagos (venta_id, forma_pago, monto, trabajador_credito_id, orden)
SELECT id, forma_pago, total, trabajador_credito_id, 0
FROM ventas;

-- Las columnas forma_pago y trabajador_credito_id en ventas quedan
-- por compatibilidad pero ahora son redundantes (info esta en venta_pagos)
-- Las marcamos como deprecadas con un comentario:
COMMENT ON COLUMN ventas.forma_pago IS 'DEPRECADO desde V3 - usar venta_pagos. Se mantiene para queries legacy.';
COMMENT ON COLUMN ventas.trabajador_credito_id IS 'DEPRECADO desde V3 - usar venta_pagos.trabajador_credito_id.';

-- Permitir forma_pago NULL para nuevas ventas (ya no tiene sentido un valor unico)
ALTER TABLE ventas ALTER COLUMN forma_pago DROP NOT NULL;

-- ============================================================
-- Trigger: la suma de venta_pagos.monto debe coincidir con ventas.total
-- ============================================================
CREATE OR REPLACE FUNCTION validar_suma_pagos_venta()
RETURNS TRIGGER AS $$
DECLARE
    v_suma NUMERIC(10,2);
    v_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(monto), 0) INTO v_suma
    FROM venta_pagos
    WHERE venta_id = COALESCE(NEW.venta_id, OLD.venta_id);

    SELECT total INTO v_total
    FROM ventas
    WHERE id = COALESCE(NEW.venta_id, OLD.venta_id);

    -- Tolerancia de 1 centavo por redondeos
    IF ABS(v_suma - v_total) > 0.01 THEN
        RAISE EXCEPTION 'Suma de pagos (%.2f) no coincide con total de venta (%.2f)', v_suma, v_total;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_validar_suma_pagos
AFTER INSERT OR UPDATE OR DELETE ON venta_pagos
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION validar_suma_pagos_venta();

-- ============================================================
-- Vista de conveniencia: ventas con detalle de pagos como JSON
-- ============================================================
CREATE OR REPLACE VIEW v_ventas_con_pagos AS
SELECT
    v.id,
    v.fecha,
    v.total,
    v.caja_id,
    v.usuario_id,
    v.anulada,
    (
        SELECT jsonb_agg(jsonb_build_object(
            'formaPago', vp.forma_pago,
            'monto', vp.monto,
            'codigoOperacion', vp.codigo_operacion,
            'trabajadorCreditoId', vp.trabajador_credito_id
        ) ORDER BY vp.orden)
        FROM venta_pagos vp
        WHERE vp.venta_id = v.id
    ) AS pagos
FROM ventas v;
