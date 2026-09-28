package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.CreditoTrabajador;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Builder
public record DeudorMovimientoDto(
        UUID id,
        UUID clienteId,
        String clienteNombre,
        String clienteDni,
        UUID ventaId,
        BigDecimal monto,
        String descripcion,
        OffsetDateTime fecha,
        boolean cerrado,
        OffsetDateTime cerradoEn,
        Integer periodoAnio,
        Integer periodoMes,
        String registradoPor
) {
    public static DeudorMovimientoDto from(CreditoTrabajador c) {
        return DeudorMovimientoDto.builder()
                .id(c.getId())
                .clienteId(c.getCliente() != null ? c.getCliente().getId() : null)
                .clienteNombre(c.getCliente() != null ? c.getCliente().getNombreCompleto() : null)
                .clienteDni(c.getCliente() != null ? c.getCliente().getDni() : null)
                .ventaId(c.getVenta() != null ? c.getVenta().getId() : null)
                .monto(c.getMonto())
                .descripcion(c.getDescripcion())
                .fecha(c.getFecha())
                .cerrado(c.isCerrado())
                .cerradoEn(c.getCerradoEn())
                .periodoAnio(c.getPeriodoAnio())
                .periodoMes(c.getPeriodoMes())
                .registradoPor(c.getRegistradoPor() != null ? c.getRegistradoPor().getNombreCompleto() : null)
                .build();
    }
}
