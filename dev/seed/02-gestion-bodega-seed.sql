-- ============================================================
-- SEED de la bodega (Sub Cafe POS)
-- ============================================================
-- Corre esto DESPUES de que el backend haya arrancado al menos una
-- vez (asi Flyway ya creo todas las tablas V1..V8).
--
--   mysql -u bodega_user -pbodega_pass gestion_bodega < dev/seed/02-gestion-bodega-seed.sql
--
-- Los datos base (usuario admin, proveedor demo, productos iniciales)
-- ya vienen del V2__seed_data.sql — no los recreamos aca.
--
-- Este script solo agrega:
--   - 2 trabajadores (clientes con es_trabajador=TRUE) que coinciden
--     por DNI con los empleados del FT (script 01).
--   - 1 producto de bazar extra con precio.
-- ============================================================

USE gestion_bodega;

-- ------------------------------------------------------------
-- 1. Trabajadores demo (mismos DNI que en FT)
-- ------------------------------------------------------------
INSERT INTO clientes (id, dni, nombres, apellidos, telefono, es_trabajador, activo, creado_en)
SELECT UUID(), '12345678', 'Juan', 'Perez Test', '999111222', TRUE, TRUE, NOW(6)
WHERE NOT EXISTS (SELECT 1 FROM clientes WHERE dni = '12345678');

INSERT INTO clientes (id, dni, nombres, apellidos, telefono, es_trabajador, activo, creado_en)
SELECT UUID(), '87654321', 'Maria', 'Garcia Test', '999333444', TRUE, TRUE, NOW(6)
WHERE NOT EXISTS (SELECT 1 FROM clientes WHERE dni = '87654321');

-- ------------------------------------------------------------
-- 2. Producto de bazar para probar ventas
--    (el V2 seed ya trae varios, este es solo un extra distinguible)
-- ------------------------------------------------------------
SET @producto_id = UUID();

INSERT INTO productos (id, codigo, descripcion, stock, stock_minimo,
                       es_servicio, usa_contometro, es_bazar, activo, creado_en)
SELECT @producto_id, 'DEMO001', 'Galleta Demo', 100, 10,
       FALSE, FALSE, TRUE, TRUE, NOW(6)
WHERE NOT EXISTS (SELECT 1 FROM productos WHERE codigo = 'DEMO001');

-- Precio del producto
INSERT INTO producto_precios (id, producto_id, costo, precio_venta, vigente_desde)
SELECT UUID(), p.id, 0.80, 1.50, NOW(6)
  FROM productos p
 WHERE p.codigo = 'DEMO001'
   AND NOT EXISTS (SELECT 1 FROM producto_precios WHERE producto_id = p.id);

-- ============================================================
-- Verificacion
-- ============================================================
SELECT '======== TRABAJADORES DEMO ========' AS info;
SELECT dni, nombres, apellidos, es_trabajador, activo
  FROM clientes WHERE dni IN ('12345678', '87654321');

SELECT '======== PRODUCTO DEMO ========' AS info;
SELECT p.codigo, p.descripcion, p.stock, pp.precio_venta
  FROM productos p
  LEFT JOIN producto_precios pp ON pp.producto_id = p.id
 WHERE p.codigo = 'DEMO001';

SELECT '' AS ' ';
SELECT 'LISTO: abre el POS, agrega Galleta Demo al carrito, y cobra con Credito -> selecciona Juan Perez o Maria Garcia' AS proximo_paso;
