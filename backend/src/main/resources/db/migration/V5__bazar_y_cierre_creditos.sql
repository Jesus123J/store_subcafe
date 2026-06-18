-- ============================================================
-- V5 — es_bazar en productos + cierre mensual de creditos (MySQL)
-- ============================================================

-- ============================================================
-- 1) Productos del bazar
-- ============================================================
ALTER TABLE productos
    ADD COLUMN es_bazar BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE productos SET es_bazar = TRUE WHERE es_servicio = FALSE;


-- ============================================================
-- 2) Cierre mensual de creditos
-- ============================================================
ALTER TABLE creditos_trabajadores
    ADD COLUMN periodo_anio INT NOT NULL DEFAULT (YEAR(NOW())),
    ADD COLUMN periodo_mes INT NOT NULL DEFAULT (MONTH(NOW()));

CREATE INDEX idx_creditos_periodo
    ON creditos_trabajadores(trabajador_id, periodo_anio, periodo_mes, cerrado);


-- ============================================================
-- 3) Historico de cierres mensuales
-- ============================================================
CREATE TABLE cierres_mensuales_creditos (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    anio INT NOT NULL,
    mes INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fecha_cierre DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    cerrado_por CHAR(36),
    trabajadores_afectados INT NOT NULL DEFAULT 0,
    monto_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    UNIQUE KEY uk_anio_mes (anio, mes),
    CONSTRAINT fk_cierres_usuario FOREIGN KEY (cerrado_por) REFERENCES usuarios(id)
);


-- ============================================================
-- 4) Vistas helper
-- ============================================================
DROP VIEW IF EXISTS v_creditos_del_mes;
DROP VIEW IF EXISTS v_deuda_trabajadores_acumulada;

CREATE VIEW v_creditos_del_mes AS
SELECT
    t.id AS trabajador_id,
    t.username,
    t.nombre_completo,
    COUNT(c.id) AS cantidad_consumos,
    COALESCE(SUM(c.monto), 0) AS monto_pendiente,
    MAX(c.fecha) AS ultimo_consumo,
    YEAR(NOW()) AS anio,
    MONTH(NOW()) AS mes
FROM usuarios t
LEFT JOIN creditos_trabajadores c
    ON c.trabajador_id = t.id
    AND c.cerrado = FALSE
    AND c.periodo_anio = YEAR(NOW())
    AND c.periodo_mes = MONTH(NOW())
GROUP BY t.id, t.username, t.nombre_completo
HAVING COUNT(c.id) > 0;

CREATE VIEW v_deuda_trabajadores_acumulada AS
SELECT
    t.id AS trabajador_id,
    t.username,
    t.nombre_completo,
    COALESCE(d.monto_total, 0) AS deuda_acumulada,
    d.actualizada_en
FROM usuarios t
LEFT JOIN deuda_trabajadores d ON d.trabajador_id = t.id
WHERE COALESCE(d.monto_total, 0) > 0;
