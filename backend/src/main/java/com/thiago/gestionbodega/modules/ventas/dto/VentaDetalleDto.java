package com.thiago.gestionbodega.modules.ventas.dto;

import com.thiago.gestionbodega.modules.ventas.entity.VentaDetalle;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record VentaDetalleDto(
        UUID id,
        UUID productoId,
        String productoDescripcion,
        BigDecimal cantidad,
        BigDecimal precioUnitario,
        BigDecimal subtotal
) {
    public static VentaDetalleDto from(VentaDetalle d) {
        return VentaDetalleDto.builder()
                .id(d.getId())
                .productoId(d.getProducto().getId())
                .productoDescripcion(d.getProducto().getDescripcion())
                .cantidad(d.getCantidad())
                .precioUnitario(d.getPrecioUnitario())
                .subtotal(d.getSubtotal())
                .build();
    }
}
