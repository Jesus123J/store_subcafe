package com.thiago.gestionbodega.modules.productos.dto;

import com.thiago.gestionbodega.modules.productos.entity.Producto;
import com.thiago.gestionbodega.modules.productos.entity.ProductoPrecio;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

@Builder
public record ProductoDto(
        UUID id,
        String codigo,
        String descripcion,
        BigDecimal stock,
        BigDecimal stockMinimo,
        BigDecimal costo,
        BigDecimal precioVenta,
        boolean esServicio,
        boolean usaContometro,
        boolean esBazar,
        boolean activo
) {

    public static ProductoDto from(Producto p, ProductoPrecio precio) {
        return ProductoDto.builder()
                .id(p.getId())
                .codigo(p.getCodigo())
                .descripcion(p.getDescripcion())
                .stock(p.getStock())
                .stockMinimo(p.getStockMinimo())
                .costo(precio != null ? precio.getCosto() : BigDecimal.ZERO)
                .precioVenta(precio != null ? precio.getPrecioVenta() : BigDecimal.ZERO)
                .esServicio(p.isEsServicio())
                .usaContometro(p.isUsaContometro())
                .esBazar(p.isEsBazar())
                .activo(p.isActivo())
                .build();
    }
}
