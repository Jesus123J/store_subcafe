package com.thiago.gestionbodega.modules.reportes.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record TopProductoDto(
        UUID productoId,
        String descripcion,
        BigDecimal cantidadVendida,
        BigDecimal totalFacturado
) {}
