-- ============================================================
-- V2 — Datos iniciales (MySQL 8 / MariaDB)
-- ============================================================

-- Usuarios admin/encargado/vendedor con contrasena admin123
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

-- Productos de ejemplo + sus precios (MySQL no soporta CTEs con INSERT como PostgreSQL,
-- asi que usamos variables de sesion para guardar los UUIDs generados)

INSERT INTO productos (id, codigo, descripcion, stock, stock_minimo) VALUES
    (UUID(), 'GAS001', 'Gaseosa Inca Kola 500ml', 24, 6),
    (UUID(), 'GAL001', 'Galletas Soda Field', 50, 10);

INSERT INTO productos (id, codigo, descripcion, stock, stock_minimo, es_servicio, usa_contometro) VALUES
    (UUID(), 'SRV001', 'Fotocopia A4', 0, 0, TRUE, TRUE);

INSERT INTO producto_precios (producto_id, costo, precio_venta)
SELECT id, 2.50, 3.50 FROM productos WHERE codigo = 'GAS001'
UNION ALL
SELECT id, 1.20, 2.00 FROM productos WHERE codigo = 'GAL001'
UNION ALL
SELECT id, 0.05, 0.20 FROM productos WHERE codigo = 'SRV001';
