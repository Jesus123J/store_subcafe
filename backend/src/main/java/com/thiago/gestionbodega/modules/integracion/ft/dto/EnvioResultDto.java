package com.thiago.gestionbodega.modules.integracion.ft.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Builder
public record EnvioResultDto(
        UUID id,
        Integer loteIdFt,
        Integer trabajadoresEnviados,
        BigDecimal montoTotal,
        OffsetDateTime fecha,
        String estado,
        List<String> dnisNoEncontrados
) {}
