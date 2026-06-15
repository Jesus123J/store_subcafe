package com.thiago.gestionbodega.modules.compras.dto;

import com.thiago.gestionbodega.modules.compras.entity.Compra;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Builder
public record CompraDto(
        UUID id,
        UUID proveedorId,
        String proveedorRazonSocial,
        String proveedorRuc,
        UUID usuarioId,
        String usuarioNombre,
        OffsetDateTime fecha,
        BigDecimal total,
        String nroDocumento,
        String observaciones,
        List<CompraDetalleDto> items
) {

    /** Version compacta sin items (para listados). */
    public static CompraDto sinDetalle(Compra c) {
        return CompraDto.builder()
                .id(c.getId())
                .proveedorId(c.getProveedor().getId())
                .proveedorRazonSocial(c.getProveedor().getRazonSocial())
                .proveedorRuc(c.getProveedor().getRuc())
                .usuarioId(c.getUsuario().getId())
                .usuarioNombre(c.getUsuario().getNombreCompleto())
                .fecha(c.getFecha())
                .total(c.getTotal())
                .nroDocumento(c.getNroDocumento())
                .observaciones(c.getObservaciones())
                .build();
    }

    /** Version completa con items. */
    public static CompraDto conDetalle(Compra c, List<CompraDetalleDto> items) {
        return CompraDto.builder()
                .id(c.getId())
                .proveedorId(c.getProveedor().getId())
                .proveedorRazonSocial(c.getProveedor().getRazonSocial())
                .proveedorRuc(c.getProveedor().getRuc())
                .usuarioId(c.getUsuario().getId())
                .usuarioNombre(c.getUsuario().getNombreCompleto())
                .fecha(c.getFecha())
                .total(c.getTotal())
                .nroDocumento(c.getNroDocumento())
                .observaciones(c.getObservaciones())
                .items(items)
                .build();
    }
}
