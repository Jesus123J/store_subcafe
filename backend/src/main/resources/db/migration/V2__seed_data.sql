-- ============================================================
-- V2 — Datos iniciales (admin + configuracion + ejemplos)
-- ============================================================
-- Los IDs son fijos para que el seed sea reproducible.

-- Usuarios por defecto. Password de los 3: admin123 (hash BCrypt).
-- CAMBIAR EN PRODUCCION.
INSERT INTO usuarios (id, username, password_hash, nombre_completo, rol) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Administrador', 'ADMINISTRADOR'),
    ('00000000-0000-0000-0000-000000000002', 'vendedor1',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Vendedor de Prueba', 'VENDEDOR'),
    ('00000000-0000-0000-0000-000000000003', 'encargado1',
     '$2b$10$4WbayYuRs6yU5hvulLShXeI6.4LO7sDVzdXcycToLGBXxXyRp1FqC',
     'Encargado de Prueba', 'ENCARGADO');

-- Configuracion del negocio (editable desde la app)
INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('negocio.razon_social', 'Sub Cafe',          'Razon social del negocio'),
    ('negocio.ruc',          '20000000000',       'RUC del negocio'),
    ('negocio.direccion',    'Av. Principal 123', 'Direccion fiscal'),
    ('negocio.telefono',     '999000000',         'Telefono de contacto'),
    ('pagos.yape_numero',    '',                  'Numero Yape del negocio'),
    ('pagos.plin_numero',    '',                  'Numero Plin del negocio'),
    ('impresora.ip',         '',                  'IP impresora termica'),
    ('impresora.modo',       'red',               'Modo: red | usb');

-- Regla de puntos por defecto: 1 punto por cada S/. 10 de consumo
INSERT INTO reglas_puntos (id, descripcion, soles_por_punto) VALUES
    ('00000000-0000-0000-0000-000000000101', 'Regla base: 1 punto por cada S/. 10 de consumo', 10.00);

-- Proveedor de ejemplo
INSERT INTO proveedores (id, razon_social, ruc, direccion, telefono) VALUES
    ('00000000-0000-0000-0000-000000000201', 'Distribuidora La Bodega SAC', '20512345678', 'Av. Lima 123, Lima', '999111222');

-- Productos de ejemplo
INSERT INTO productos (id, codigo, descripcion, stock, stock_minimo, es_servicio, usa_contometro, es_bazar) VALUES
    ('00000000-0000-0000-0000-000000000301', 'GAS001', 'Gaseosa Inca Kola 500ml', 24, 6,  FALSE, FALSE, TRUE),
    ('00000000-0000-0000-0000-000000000302', 'GAL001', 'Galletas Soda Field',     50, 10, FALSE, FALSE, TRUE),
    ('00000000-0000-0000-0000-000000000303', 'SRV001', 'Fotocopia A4',            0,  0,  TRUE,  TRUE,  FALSE);

INSERT INTO producto_precios (producto_id, costo, precio_venta) VALUES
    ('00000000-0000-0000-0000-000000000301', 2.50, 3.50),
    ('00000000-0000-0000-0000-000000000302', 1.20, 2.00),
    ('00000000-0000-0000-0000-000000000303', 0.05, 0.20);
