-- ============================================================
-- V8 - Historial de envios a FinantialTracker (sistema de planilla)
-- ============================================================
-- Cada corte mensual (o envio individual) genera un registro que
-- referencia el lote_id creado en la BD financialtracker1. Permite:
--   - Ver que cierres ya fueron migrados a planilla
--   - Bloquear reenvios accidentales
--   - Revertir un envio (borra el lote en FT y marca este registro)
-- ============================================================

CREATE TABLE envios_financialtracker (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),

    -- Origen: puede ser un cierre mensual completo o un credito individual
    cierre_id       CHAR(36) NULL,          -- FK cierres_mensuales_creditos
    credito_id      CHAR(36) NULL,          -- FK creditos_trabajadores (envio individual)

    -- Destino en FinantialTracker
    lote_id_ft      INT NOT NULL,           -- lote_carga_abono.id
    service_concept_id INT NOT NULL,        -- service_concept.ID usado

    fecha           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    enviado_por     CHAR(36) NULL,          -- usuario admin que envio

    trabajadores_enviados INT NOT NULL,
    monto_total     DECIMAL(12, 2) NOT NULL,

    estado          ENUM('ACTIVO', 'REVERTIDO') NOT NULL DEFAULT 'ACTIVO',
    motivo_reversion TEXT,
    fecha_reversion DATETIME(6),
    revertido_por   CHAR(36) NULL,

    CONSTRAINT fk_envios_ft_cierre  FOREIGN KEY (cierre_id)  REFERENCES cierres_mensuales_creditos(id),
    CONSTRAINT fk_envios_ft_credito FOREIGN KEY (credito_id) REFERENCES creditos_trabajadores(id),
    CONSTRAINT fk_envios_ft_usuario FOREIGN KEY (enviado_por) REFERENCES usuarios(id),
    CONSTRAINT fk_envios_ft_reverter FOREIGN KEY (revertido_por) REFERENCES usuarios(id),

    INDEX idx_envios_lote (lote_id_ft),
    INDEX idx_envios_cierre (cierre_id),
    INDEX idx_envios_credito (credito_id),
    INDEX idx_envios_estado (estado)
);
