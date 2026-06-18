package com.thiago.gestionbodega.modules.ventas.dto;

import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Builder
public record VentaDto(
        UUID id,
        UUID cajaId,
        UUID usuarioId,
        String usuarioNombre,
        OffsetDateTime fecha,
        BigDecimal total,
        boolean anulada,
        List<VentaDetalleDto> items,
        List<VentaPagoDto> pagos
) {
    public static VentaDto sinDetalle(Venta v) {
        return VentaDto.builder()
                .id(v.getId())
                .cajaId(v.getCaja().getId())
                .usuarioId(v.getUsuario().getId())
                .usuarioNombre(v.getUsuario().getNombreCompleto())
                .fecha(v.getFecha())
                .total(v.getTotal())
                .anulada(v.isAnulada())
                .build();
    }

    public static VentaDto conDetalle(Venta v,
                                      List<VentaDetalleDto> items,
                                      List<VentaPagoDto> pagos) {
        return VentaDto.builder()
                .id(v.getId())
                .cajaId(v.getCaja().getId())
                .usuarioId(v.getUsuario().getId())
                .usuarioNombre(v.getUsuario().getNombreCompleto())
                .fecha(v.getFecha())
                .total(v.getTotal())
                .anulada(v.isAnulada())
                .items(items)
                .pagos(pagos)
                .build();
    }
}
