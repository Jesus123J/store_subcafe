-- ============================================================
-- V5 — Flag es_bazar en productos + soporte para cierre mensual de creditos
-- ============================================================
-- Aplica la respuesta de Karina sobre vales/puntos canjeables solo en
-- productos del bazar, y el ciclo mensual de creditos a trabajadores.

-- ============================================================
-- 1) Productos del bazar (para canje de vales y puntos)
-- ============================================================
ALTER TABLE productos
    ADD COLUMN es_bazar BOOLEAN NOT NULL DEFAULT FALSE;

-- Por defecto, marcamos como del bazar los productos NO servicio (mas comun)
-- El admin puede ajustar despues. Esto es solo un seed inicial razonable.
UPDATE productos SET es_bazar = TRUE WHERE es_servicio = FALSE;


-- ============================================================
-- 2) Cierre mensual de creditos
-- ============================================================
-- A la tabla creditos_trabajadores le agregamos columnas para rastrear
-- en que cierre se incluyo cada credito.
ALTER TABLE creditos_trabajadores
    ADD COLUMN periodo_anio INTEGER NOT NULL DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER,
    ADD COLUMN periodo_mes INTEGER NOT NULL DEFAULT EXTRACT(MONTH FROM NOW())::INTEGER;

CREATE INDEX idx_creditos_periodo
    ON creditos_trabajadores(trabajador_id, periodo_anio, periodo_mes, cerrado);


-- ============================================================
-- 3) Historico de cierres mensuales
-- ============================================================
CREATE TABLE cierres_mensuales_creditos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fecha_cierre TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cerrado_por UUID REFERENCES usuarios(id),
    trabajadores_afectados INTEGER NOT NULL DEFAULT 0,
    monto_total NUMERIC(12,2) NOT NULL DEFAULT 0,
    UNIQUE(anio, mes)
);


-- ============================================================
-- 4) Vistas helper
-- ============================================================
DROP VIEW IF EXISTS v_creditos_del_mes;
DROP VIEW IF EXISTS v_deuda_trabajadores_acumulada;

-- Creditos del mes actual NO cerrados, agrupados por trabajador
CREATE VIEW v_creditos_del_mes AS
SELECT
    t.id AS trabajador_id,
    t.username,
    t.nombre_completo,
    COUNT(c.id) AS cantidad_consumos,
    COALESCE(SUM(c.monto), 0) AS monto_pendiente,
    MAX(c.fecha) AS ultimo_consumo,
    EXTRACT(YEAR FROM NOW())::INTEGER AS anio,
    EXTRACT(MONTH FROM NOW())::INTEGER AS mes
FROM usuarios t
LEFT JOIN creditos_trabajadores c
    ON c.trabajador_id = t.id
    AND c.cerrado = FALSE
    AND c.periodo_anio = EXTRACT(YEAR FROM NOW())::INTEGER
    AND c.periodo_mes = EXTRACT(MONTH FROM NOW())::INTEGER
GROUP BY t.id, t.username, t.nombre_completo
HAVING COUNT(c.id) > 0;

-- Deuda acumulada de meses anteriores (la que va a planilla)
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
