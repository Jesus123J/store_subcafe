package com.thiago.gestionbodega.modules.cajas.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * Detalle completo de una caja: incluye totales por forma de pago,
 * avances de efectivo y calculo de efectivo esperado en caja.
 *
 * Usado por GET /api/cajas/abierta para el dashboard del turno.
 */
@Builder
public record CajaDetalleDto(
        CajaDto caja,
        BigDecimal totalVentas,
        Map<String, BigDecimal> ventasPorFormaPago,   // {EFECTIVO: 100.0, YAPE: 50.0, ...}
        List<AvanceDto> avances,
        BigDecimal totalAvances,
        BigDecimal efectivoEsperadoEnCaja             // monto_apertura + ventas_efectivo - total_avances
) {}
