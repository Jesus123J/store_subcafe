-- ============================================================
-- V2 — Datos iniciales (admin + ejemplos)
-- ============================================================

-- Usuario administrador por defecto
-- Username: admin
-- Password: admin123  (hash BCrypt)
-- CAMBIAR EN PRODUCCION
INSERT INTO usuarios (username, password_hash, nombre_completo, rol) VALUES
    ('admin',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Administrador',
     'ADMINISTRADOR'),
    ('vendedor1',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Vendedor de Prueba',
     'VENDEDOR'),
    ('encargado1',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Encargado de Prueba',
     'ENCARGADO');

-- Proveedor de ejemplo
INSERT INTO proveedores (razon_social, ruc, direccion, telefono) VALUES
    ('Distribuidora La Bodega SAC', '20512345678', 'Av. Lima 123, Lima', '999111222');

-- Productos de ejemplo
WITH p1 AS (
    INSERT INTO productos (codigo, descripcion, stock, stock_minimo)
    VALUES ('GAS001', 'Gaseosa Inca Kola 500ml', 24, 6)
    RETURNING id
),
p2 AS (
    INSERT INTO productos (codigo, descripcion, stock, stock_minimo)
    VALUES ('GAL001', 'Galletas Soda Field', 50, 10)
    RETURNING id
),
p3 AS (
    INSERT INTO productos (codigo, descripcion, stock, stock_minimo, es_servicio, usa_contometro)
    VALUES ('SRV001', 'Fotocopia A4', 0, 0, TRUE, TRUE)
    RETURNING id
)
INSERT INTO producto_precios (producto_id, costo, precio_venta)
SELECT id, 2.50, 3.50 FROM p1 UNION ALL
SELECT id, 1.20, 2.00 FROM p2 UNION ALL
SELECT id, 0.05, 0.20 FROM p3;
