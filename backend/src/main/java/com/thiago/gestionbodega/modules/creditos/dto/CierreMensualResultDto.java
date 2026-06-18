package com.thiago.gestionbodega.modules.creditos.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Builder
public record CierreMensualResultDto(
        int anio,
        int mes,
        OffsetDateTime fechaCierre,
        int trabajadoresAfectados,
        BigDecimal montoTotal,
        int creditosCerrados
) {}
