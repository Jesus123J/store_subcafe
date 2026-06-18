-- ============================================================
-- V7 - Trabajadores de credito viven en clientes, no en usuarios
-- ============================================================
-- Karina importa sus trabajadores como clientes (con es_trabajador = TRUE)
-- desde el sistema viejo. Las tablas creditos_trabajadores y
-- deuda_trabajadores apuntaban a usuarios (cajeros del POS), lo cual
-- impedia registrar credito a alguien que no logueaba al sistema.
--
-- Cambiamos los FK para que apunten a clientes. Las vistas helper se
-- recrean para usar dni + nombres/apellidos en lugar de username.
--
-- Asumimos que creditos_trabajadores y deuda_trabajadores estan VACIAS
-- (nadie pudo registrar credito hasta el fix de JpaAuditingConfig).
-- ============================================================

-- 1) Reapuntar FK de creditos_trabajadores
ALTER TABLE creditos_trabajadores
    DROP FOREIGN KEY fk_creditos_trabajador;

ALTER TABLE creditos_trabajadores
    ADD CONSTRAINT fk_creditos_trabajador
        FOREIGN KEY (trabajador_id) REFERENCES clientes(id);

-- 2) Reapuntar FK de deuda_trabajadores
ALTER TABLE deuda_trabajadores
    DROP FOREIGN KEY fk_deuda_trabajador;

ALTER TABLE deuda_trabajadores
    ADD CONSTRAINT fk_deuda_trabajador
        FOREIGN KEY (trabajador_id) REFERENCES clientes(id);

-- 2b) Reapuntar FK de venta_pagos.trabajador_credito_id
ALTER TABLE venta_pagos
    DROP FOREIGN KEY fk_venta_pagos_trabajador;

ALTER TABLE venta_pagos
    ADD CONSTRAINT fk_venta_pagos_trabajador
        FOREIGN KEY (trabajador_credito_id) REFERENCES clientes(id);

-- 2c) Reapuntar FK de ventas.trabajador_credito_id (columna legacy de V1)
-- Buscamos el nombre del constraint dinamicamente porque V1 no le puso uno fijo.
SET @cs := (
    SELECT CONSTRAINT_NAME
    FROM information_schema.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ventas'
      AND COLUMN_NAME = 'trabajador_credito_id'
      AND REFERENCED_TABLE_NAME = 'usuarios'
    LIMIT 1
);
SET @sql := IF(@cs IS NOT NULL,
    CONCAT('ALTER TABLE ventas DROP FOREIGN KEY ', @cs),
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

ALTER TABLE ventas
    ADD CONSTRAINT fk_ventas_trabajador_credito
        FOREIGN KEY (trabajador_credito_id) REFERENCES clientes(id);

-- 3) Recrear vistas para que muestren los datos del cliente-trabajador
DROP VIEW IF EXISTS v_creditos_del_mes;
DROP VIEW IF EXISTS v_deuda_trabajadores_acumulada;

CREATE VIEW v_creditos_del_mes AS
SELECT
    t.id AS trabajador_id,
    t.dni,
    CONCAT(t.nombres, ' ', t.apellidos) AS nombre_completo,
    COUNT(c.id) AS cantidad_consumos,
    COALESCE(SUM(c.monto), 0) AS monto_pendiente,
    MAX(c.fecha) AS ultimo_consumo,
    YEAR(NOW()) AS anio,
    MONTH(NOW()) AS mes
FROM clientes t
LEFT JOIN creditos_trabajadores c
    ON c.trabajador_id = t.id
    AND c.cerrado = FALSE
    AND c.periodo_anio = YEAR(NOW())
    AND c.periodo_mes = MONTH(NOW())
WHERE t.es_trabajador = TRUE AND t.activo = TRUE
GROUP BY t.id, t.dni, t.nombres, t.apellidos
HAVING COUNT(c.id) > 0;

CREATE VIEW v_deuda_trabajadores_acumulada AS
SELECT
    t.id AS trabajador_id,
    t.dni,
    CONCAT(t.nombres, ' ', t.apellidos) AS nombre_completo,
    COALESCE(d.monto_total, 0) AS deuda_acumulada,
    d.actualizada_en
FROM clientes t
LEFT JOIN deuda_trabajadores d ON d.trabajador_id = t.id
WHERE t.es_trabajador = TRUE AND COALESCE(d.monto_total, 0) > 0;
