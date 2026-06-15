package com.thiago.gestionbodega.modules.reportes.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * Reporte de ventas para un rango de fechas. Incluye totales globales,
 * desglose por forma de pago, por turno y serie diaria para graficos.
 */
@Builder
public record VentasDiariasDto(
        LocalDate desde,
        LocalDate hasta,
        BigDecimal totalGeneral,
        long cantidadTransacciones,
        BigDecimal ticketPromedio,
        Map<String, BigDecimal> porFormaPago,
        Map<String, BigDecimal> porTurno,
        List<SerieDiariaDto> serieDiaria
) {

    @Builder
    public record SerieDiariaDto(LocalDate fecha, BigDecimal total) {}
}
