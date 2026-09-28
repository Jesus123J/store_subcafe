package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.VentaDetalle;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record VentaItemDto(
        UUID id,
        UUID productoId,
        String codigo,
        String descripcion,
        BigDecimal cantidad,
        BigDecimal precioUnitario,
        BigDecimal subtotal
) {
    public static VentaItemDto from(VentaDetalle d) {
        return VentaItemDto.builder()
                .id(d.getId())
                .productoId(d.getProducto().getId())
                .codigo(d.getProducto().getCodigo())
                .descripcion(d.getProducto().getDescripcion())
                .cantidad(d.getCantidad())
                .precioUnitario(d.getPrecioUnitario())
                .subtotal(d.getSubtotal())
                .build();
    }
}
