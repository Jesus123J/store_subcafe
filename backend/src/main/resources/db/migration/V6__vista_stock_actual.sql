-- ============================================================
-- V6 - Vista v_stock_actual (faltaba al migrar a MySQL)
-- ============================================================
-- La consume ReporteRepository (stockActual + stockBajo) y posiblemente
-- otras pantallas de inventario. Une cada producto activo con el ultimo
-- registro de producto_precios para tener costo y precio_venta vigentes.
-- ============================================================

DROP VIEW IF EXISTS v_stock_actual;

CREATE VIEW v_stock_actual AS
SELECT
    p.id,
    p.codigo,
    p.descripcion,
    p.stock,
    p.stock_minimo,
    COALESCE(pp.costo, 0)        AS costo,
    COALESCE(pp.precio_venta, 0) AS precio_venta,
    (NOT p.es_servicio AND p.stock <= p.stock_minimo) AS bajo_minimo
FROM productos p
LEFT JOIN (
    -- ultimo precio por producto
    SELECT pr.producto_id, pr.costo, pr.precio_venta
    FROM producto_precios pr
    INNER JOIN (
        SELECT producto_id, MAX(vigente_desde) AS max_vigente
        FROM producto_precios
        GROUP BY producto_id
    ) latest
      ON latest.producto_id = pr.producto_id
     AND latest.max_vigente = pr.vigente_desde
) pp ON pp.producto_id = p.id
WHERE p.activo = TRUE;
