-- ============================================================
-- V9 - Trabajadores como servicio externo: solo DNI, sin FK local
-- ============================================================
-- Redisenio: los trabajadores viven en FinantialTracker.employees. La
-- bodega NO tiene copia local, solo referencia por DNI. Cuando la UI
-- necesita ver la lista o el nombre de un trabajador, hace passthrough
-- a FT en vivo. Sin conexion a FT -> se muestra solo el DNI.
--
-- Esta migracion:
--   1. Agrega columna trabajador_dni en las 3 tablas que lo referencian
--   2. Copia el DNI desde clientes.dni (los actualmente vinculados)
--   3. Elimina las FK hacia clientes
--   4. Elimina las columnas trabajador_id (UUID)
--   5. Recrea las vistas para agrupar por DNI (nombre lo resuelve la app)
--   6. Borra los clientes con es_trabajador=TRUE y la columna es_trabajador
-- ============================================================

-- ------------------------------------------------------------
-- 1) creditos_trabajadores: nuevo trabajador_dni
-- ------------------------------------------------------------
ALTER TABLE creditos_trabajadores
    ADD COLUMN trabajador_dni VARCHAR(8) NULL AFTER trabajador_id;

UPDATE creditos_trabajadores ct
  JOIN clientes cl ON cl.id = ct.trabajador_id
   SET ct.trabajador_dni = cl.dni;

ALTER TABLE creditos_trabajadores DROP FOREIGN KEY fk_creditos_trabajador;
ALTER TABLE creditos_trabajadores DROP COLUMN trabajador_id;
ALTER TABLE creditos_trabajadores MODIFY trabajador_dni VARCHAR(8) NOT NULL;
CREATE INDEX idx_creditos_dni ON creditos_trabajadores(trabajador_dni);

-- ------------------------------------------------------------
-- 2) deuda_trabajadores: nuevo trabajador_dni (unico)
-- ------------------------------------------------------------
ALTER TABLE deuda_trabajadores
    ADD COLUMN trabajador_dni VARCHAR(8) NULL AFTER trabajador_id;

UPDATE deuda_trabajadores dt
  JOIN clientes cl ON cl.id = dt.trabajador_id
   SET dt.trabajador_dni = cl.dni;

ALTER TABLE deuda_trabajadores DROP FOREIGN KEY fk_deuda_trabajador;
ALTER TABLE deuda_trabajadores DROP COLUMN trabajador_id;
ALTER TABLE deuda_trabajadores MODIFY trabajador_dni VARCHAR(8) NOT NULL UNIQUE;

-- ------------------------------------------------------------
-- 3) venta_pagos: nuevo trabajador_credito_dni
-- ------------------------------------------------------------
ALTER TABLE venta_pagos
    ADD COLUMN trabajador_credito_dni VARCHAR(8) NULL AFTER trabajador_credito_id;

UPDATE venta_pagos vp
  JOIN clientes cl ON cl.id = vp.trabajador_credito_id
   SET vp.trabajador_credito_dni = cl.dni
 WHERE vp.trabajador_credito_id IS NOT NULL;

ALTER TABLE venta_pagos DROP FOREIGN KEY fk_venta_pagos_trabajador;
ALTER TABLE venta_pagos DROP COLUMN trabajador_credito_id;
CREATE INDEX idx_venta_pagos_dni ON venta_pagos(trabajador_credito_dni);

-- ------------------------------------------------------------
-- 4) ventas.trabajador_credito_id (legacy): mismo tratamiento
-- ------------------------------------------------------------
ALTER TABLE ventas
    ADD COLUMN trabajador_credito_dni VARCHAR(8) NULL AFTER trabajador_credito_id;

UPDATE ventas v
  JOIN clientes cl ON cl.id = v.trabajador_credito_id
   SET v.trabajador_credito_dni = cl.dni
 WHERE v.trabajador_credito_id IS NOT NULL;

ALTER TABLE ventas DROP FOREIGN KEY fk_ventas_trabajador_credito;
ALTER TABLE ventas DROP COLUMN trabajador_credito_id;

-- ------------------------------------------------------------
-- 5) Recrear vistas: agrupan por DNI, sin nombre (lo resuelve la app)
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_creditos_del_mes;
DROP VIEW IF EXISTS v_deuda_trabajadores_acumulada;

CREATE VIEW v_creditos_del_mes AS
SELECT
    c.trabajador_dni AS dni,
    COUNT(c.id) AS cantidad_consumos,
    COALESCE(SUM(c.monto), 0) AS monto_pendiente,
    MAX(c.fecha) AS ultimo_consumo,
    YEAR(NOW()) AS anio,
    MONTH(NOW()) AS mes
FROM creditos_trabajadores c
WHERE c.cerrado = FALSE
  AND c.periodo_anio = YEAR(NOW())
  AND c.periodo_mes = MONTH(NOW())
GROUP BY c.trabajador_dni;

CREATE VIEW v_deuda_trabajadores_acumulada AS
SELECT
    d.trabajador_dni AS dni,
    d.monto_total AS deuda_acumulada,
    d.actualizada_en
FROM deuda_trabajadores d
WHERE d.monto_total > 0;

-- ------------------------------------------------------------
-- 6) Limpieza: quitar clientes que eran solo trabajadores + columna
-- ------------------------------------------------------------
DELETE FROM clientes WHERE es_trabajador = TRUE;
ALTER TABLE clientes DROP COLUMN es_trabajador;
