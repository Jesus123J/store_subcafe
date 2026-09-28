package com.thiago.gestionbodega.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

/** Producto para el POS: incluye el precio vigente (ultimo producto_precios). */
@Builder
public record ProductoDto(
        UUID id,
        String codigo,
        String descripcion,
        BigDecimal stock,
        BigDecimal stockMinimo,
        boolean esServicio,
        boolean usaContometro,
        boolean esBazar,
        boolean activo,
        BigDecimal precioVenta,
        BigDecimal costo,
        boolean bajoMinimo
) {}
