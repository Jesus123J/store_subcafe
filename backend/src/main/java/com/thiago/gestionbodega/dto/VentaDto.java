package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.Venta;
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
        String motivoAnulacion,
        String observacion,
        boolean tieneCredito,
        UUID clienteId,
        String clienteNombre,
        List<VentaItemDto> items,
        List<VentaPagoDto> pagos
) {
    public static VentaDto from(Venta v) {
        return VentaDto.builder()
                .id(v.getId())
                .cajaId(v.getCaja().getId())
                .usuarioId(v.getUsuario().getId())
                .usuarioNombre(v.getUsuario().getNombreCompleto())
                .fecha(v.getFecha())
                .total(v.getTotal())
                .anulada(v.isAnulada())
                .motivoAnulacion(v.getMotivoAnulacion())
                .observacion(v.getObservacion())
                .tieneCredito(v.getPagos().stream().anyMatch(p -> p.getClienteCredito() != null))
                .clienteId(v.getCliente() != null ? v.getCliente().getId() : null)
                .clienteNombre(v.getCliente() != null ? v.getCliente().getNombreCompleto() : null)
                .items(v.getItems().stream().map(VentaItemDto::from).toList())
                .pagos(v.getPagos().stream().map(VentaPagoDto::from).toList())
                .build();
    }
}
