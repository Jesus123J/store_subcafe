package com.thiago.gestionbodega.modules.vales.dto;

import com.thiago.gestionbodega.modules.vales.entity.EstadoVale;
import com.thiago.gestionbodega.modules.vales.entity.TipoVale;
import com.thiago.gestionbodega.modules.vales.entity.Vale;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Builder
public record ValeDto(
        UUID id,
        String codigo,
        TipoVale tipo,
        UUID clienteId,
        String clienteNombre,
        String clienteDni,
        BigDecimal montoInicial,
        BigDecimal saldo,
        EstadoVale estado,
        OffsetDateTime fechaEmision,
        LocalDate fechaVencimiento,
        String observaciones
) {
    public static ValeDto from(Vale v) {
        return ValeDto.builder()
                .id(v.getId())
                .codigo(v.getCodigo())
                .tipo(v.getTipo())
                .clienteId(v.getCliente() != null ? v.getCliente().getId() : null)
                .clienteNombre(v.getCliente() != null ? v.getCliente().getNombreCompleto() : null)
                .clienteDni(v.getCliente() != null ? v.getCliente().getDni() : null)
                .montoInicial(v.getMontoInicial())
                .saldo(v.getSaldo())
                .estado(v.getEstado())
                .fechaEmision(v.getFechaEmision())
                .fechaVencimiento(v.getFechaVencimiento())
                .observaciones(v.getObservaciones())
                .build();
    }
}
