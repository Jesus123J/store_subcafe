package com.thiago.gestionbodega.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Builder
public record CierreMensualResultDto(
        String cierreId,
        int anio,
        int mes,
        OffsetDateTime fechaCierre,
        int trabajadoresAfectados,
        BigDecimal montoTotal,
        int creditosCerrados,
        int exportadosFinantial,     // abonos creados en FinantialTracker
        int erroresFinantial         // trabajadores que no se pudieron exportar (ver detalle del cierre)
) {}
