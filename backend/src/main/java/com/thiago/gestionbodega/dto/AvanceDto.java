package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.AvanceEfectivo;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Builder
public record AvanceDto(
        UUID id,
        BigDecimal monto,
        String observacion,
        OffsetDateTime fecha
) {
    public static AvanceDto from(AvanceEfectivo a) {
        return AvanceDto.builder()
                .id(a.getId())
                .monto(a.getMonto())
                .observacion(a.getObservacion())
                .fecha(a.getFecha())
                .build();
    }
}
