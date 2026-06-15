package com.thiago.gestionbodega.modules.compras.dto;

import com.thiago.gestionbodega.modules.compras.entity.CompraDetalle;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record CompraDetalleDto(
        UUID id,
        UUID productoId,
        String productoDescripcion,
        BigDecimal cantidad,
        BigDecimal costoUnitario,
        BigDecimal subtotal
) {
    public static CompraDetalleDto from(CompraDetalle d) {
        return CompraDetalleDto.builder()
                .id(d.getId())
                .productoId(d.getProducto().getId())
                .productoDescripcion(d.getProducto().getDescripcion())
                .cantidad(d.getCantidad())
                .costoUnitario(d.getCostoUnitario())
                .subtotal(d.getSubtotal())
                .build();
    }
}
