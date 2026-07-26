package com.thiago.gestionbodega.modules.reportes.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Fila del reporte de creditos por trabajador. Se usa tanto para creditos
 * pendientes del mes actual como para deuda historica acumulada.
 * El nombre del trabajador se resuelve en el frontend contra FT (passthrough).
 */
@Builder
public record CreditoReporteDto(
        String dni,
        long cantidadConsumos,
        BigDecimal montoPendiente,
        BigDecimal deudaAcumulada,
        OffsetDateTime ultimoConsumo
) {}
