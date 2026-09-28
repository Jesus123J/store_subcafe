-- ============================================================
-- V4 — Deudores: la deuda por credito cuelga del TRABAJADOR (clientes)
--      y se exporta a FinantialTracker como `abono` al cerrar el mes.
-- ============================================================
-- Antes, creditos_trabajadores / deuda_trabajadores apuntaban a `usuarios`
-- (usuarios del sistema). El trabajador que compra a credito es un
-- empleado del hospital = fila de `clientes` (sincronizada desde
-- `employees` de FinantialTracker). Un cliente externo NO puede comprar
-- a credito: para el solo se registra la venta.
-- ============================================================

-- 1) creditos_trabajadores: ahora por cliente (trabajador)
ALTER TABLE creditos_trabajadores
    MODIFY trabajador_id CHAR(36) NULL COMMENT 'LEGACY: usuario del sistema. Usar cliente_id',
    ADD COLUMN cliente_id     CHAR(36)     NULL COMMENT 'Trabajador (clientes.id) que debe' AFTER trabajador_id,
    ADD COLUMN descripcion    VARCHAR(200) NULL COMMENT 'Resumen del consumo (productos)' AFTER monto,
    ADD COLUMN registrado_por CHAR(36)     NULL COMMENT 'Usuario del sistema que registro el credito' AFTER descripcion,
    ADD COLUMN cierre_id      CHAR(36)     NULL COMMENT 'Cierre mensual en el que se incluyo' AFTER cerrado_en,
    ADD KEY idx_creditos_cliente (cliente_id, cerrado, periodo_anio, periodo_mes),
    ADD CONSTRAINT fk_creditos_cliente        FOREIGN KEY (cliente_id)     REFERENCES clientes (id),
    ADD CONSTRAINT fk_creditos_registrado_por FOREIGN KEY (registrado_por) REFERENCES usuarios (id),
    ADD CONSTRAINT fk_creditos_cierre         FOREIGN KEY (cierre_id)      REFERENCES cierres_mensuales_creditos (id);

-- 2) deuda_trabajadores: acumulado por cliente
ALTER TABLE deuda_trabajadores
    MODIFY trabajador_id CHAR(36) NULL COMMENT 'LEGACY: usuario del sistema. Usar cliente_id',
    ADD COLUMN cliente_id CHAR(36) NULL AFTER trabajador_id,
    ADD UNIQUE KEY uk_deuda_cliente (cliente_id),
    ADD CONSTRAINT fk_deuda_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id);

-- 3) venta_pagos: el pago a credito indica QUE trabajador debe
ALTER TABLE venta_pagos
    ADD COLUMN cliente_credito_id CHAR(36) NULL COMMENT 'Trabajador que asume el credito' AFTER trabajador_credito_id,
    ADD CONSTRAINT fk_venta_pagos_cliente FOREIGN KEY (cliente_credito_id) REFERENCES clientes (id);

ALTER TABLE ventas
    ADD COLUMN observacion VARCHAR(300) NULL AFTER motivo_anulacion;

-- 4) Detalle de cada cierre: una fila por trabajador. Es lo que MAS ADELANTE se
--    reflejara en FinantialTracker como `abono` (ft_abono_id). Mientras la union
--    este desactivada, ft_abono_id queda NULL y aqui se ve el proceso completo.
CREATE TABLE cierre_creditos_detalle (
    id                 CHAR(36)      NOT NULL DEFAULT (UUID()),
    cierre_id          CHAR(36)      NOT NULL,
    cliente_id         CHAR(36)      NOT NULL,
    cantidad_consumos  INT           NOT NULL DEFAULT 0,
    monto              DECIMAL(10,2) NOT NULL,
    -- Enlace con FinantialTracker (abono.ID). NULL = aun no exportado.
    ft_abono_id        INT           NULL,
    ft_exportado_en    TIMESTAMP(6)  NULL,
    ft_error           VARCHAR(500)  NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_cierre_detalle (cierre_id, cliente_id),
    KEY idx_cierre_detalle_ft (ft_abono_id),
    CONSTRAINT fk_cierre_detalle_cierre  FOREIGN KEY (cierre_id)  REFERENCES cierres_mensuales_creditos (id) ON DELETE CASCADE,
    CONSTRAINT fk_cierre_detalle_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id)
) ENGINE = InnoDB;

-- 5) Parametros de la union con FinantialTracker (editables en Configuracion)
INSERT INTO configuracion (clave, valor, descripcion) VALUES
    ('finantial.concepto_abono_id',  '8',                 'service_concept.ID usado para las deudas de la tienda (8 = DESCUENTOS CREDITO BAZAR)'),
    ('finantial.usuario_id',         '3',                 'user.iduser de FinantialTracker con el que se registran los abonos'),
    ('finantial.descuento_desde',    'BOLETA DE HABERES', 'abono.discount_from'),
    ('finantial.exportar_al_cerrar', 'false',             'false = SOLO se registra el proceso en la tienda (cierre_creditos_detalle). Poner true cuando se active la union: al cerrar el mes se crean los abonos en FinantialTracker');

-- 6) Vistas por trabajador (reemplazan a las basadas en usuarios)
DROP VIEW IF EXISTS v_creditos_del_mes;
DROP VIEW IF EXISTS v_deuda_trabajadores_acumulada;

-- Creditos del mes actual NO cerrados, agrupados por trabajador
CREATE VIEW v_creditos_del_mes AS
SELECT c.id                                   AS cliente_id,
       c.dni,
       CONCAT(c.apellidos, ' ', c.nombres)    AS nombre_completo,
       c.empleado_id,
       c.condicion_laboral,
       COUNT(cr.id)                           AS cantidad_consumos,
       COALESCE(SUM(cr.monto), 0)             AS monto_pendiente,
       MAX(cr.fecha)                          AS ultimo_consumo,
       YEAR(CURRENT_DATE)                     AS anio,
       MONTH(CURRENT_DATE)                    AS mes
FROM clientes c
JOIN creditos_trabajadores cr
  ON cr.cliente_id = c.id
 AND cr.cerrado = FALSE
GROUP BY c.id, c.dni, c.apellidos, c.nombres, c.empleado_id, c.condicion_laboral;

-- Deuda acumulada de meses cerrados (la que va a planilla / FinantialTracker)
CREATE VIEW v_deuda_trabajadores_acumulada AS
SELECT c.id                                   AS cliente_id,
       c.dni,
       CONCAT(c.apellidos, ' ', c.nombres)    AS nombre_completo,
       c.empleado_id,
       d.monto_total                          AS deuda_acumulada,
       d.actualizada_en
FROM clientes c
JOIN deuda_trabajadores d ON d.cliente_id = c.id
WHERE d.monto_total > 0;

-- Deudores: un renglon por trabajador con deuda viva (mes en curso + acumulada)
CREATE OR REPLACE VIEW v_deudores AS
SELECT c.id                                   AS cliente_id,
       c.dni,
       c.apellidos,
       c.nombres,
       CONCAT(c.apellidos, ' ', c.nombres)    AS nombre_completo,
       c.empleado_id,
       c.condicion_laboral,
       COALESCE(m.monto_pendiente, 0)         AS pendiente_mes,
       COALESCE(m.cantidad_consumos, 0)       AS consumos_mes,
       m.ultimo_consumo,
       COALESCE(d.monto_total, 0)             AS deuda_acumulada,
       COALESCE(m.monto_pendiente, 0) + COALESCE(d.monto_total, 0) AS deuda_total,
       (SELECT COUNT(*) FROM cierre_creditos_detalle cd
          WHERE cd.cliente_id = c.id AND cd.ft_abono_id IS NULL AND cd.ft_error IS NOT NULL) AS exportaciones_pendientes
FROM clientes c
LEFT JOIN (SELECT cliente_id, SUM(monto) monto_pendiente, COUNT(*) cantidad_consumos, MAX(fecha) ultimo_consumo
           FROM creditos_trabajadores WHERE cerrado = FALSE GROUP BY cliente_id) m ON m.cliente_id = c.id
LEFT JOIN deuda_trabajadores d ON d.cliente_id = c.id
WHERE COALESCE(m.monto_pendiente, 0) > 0 OR COALESCE(d.monto_total, 0) > 0;
