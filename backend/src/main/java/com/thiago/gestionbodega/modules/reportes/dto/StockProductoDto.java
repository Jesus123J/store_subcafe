package com.thiago.gestionbodega.modules.reportes.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Producto en el reporte de stock: incluye costo y precio actuales y la
 * valoracion del inventario (stock * costo).
 */
@Builder
public record StockProductoDto(
        UUID id,
        String codigo,
        String descripcion,
        BigDecimal stock,
        BigDecimal stockMinimo,
        BigDecimal costo,
        BigDecimal precioVenta,
        BigDecimal valoracion,
        boolean bajoMinimo
) {}
