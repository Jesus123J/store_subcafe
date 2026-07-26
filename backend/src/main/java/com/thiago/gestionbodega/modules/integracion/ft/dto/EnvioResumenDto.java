package com.thiago.gestionbodega.modules.integracion.ft.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Fila del historial de envios a FT (para listar en la UI). */
@Builder
public record EnvioResumenDto(
        UUID id,
        UUID cierreId,
        UUID creditoId,
        Integer loteIdFt,
        OffsetDateTime fecha,
        Integer trabajadoresEnviados,
        BigDecimal montoTotal,
        String estado,
        String motivoReversion,
        OffsetDateTime fechaReversion
) {}
