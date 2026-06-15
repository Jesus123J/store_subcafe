package com.thiago.gestionbodega.modules.cajas.dto;

import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.entity.EstadoCaja;
import com.thiago.gestionbodega.modules.cajas.entity.TipoTurno;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * DTO basico de una caja. Sin detalle de ventas (ver CajaDetalleDto para eso).
 */
@Builder
public record CajaDto(
        UUID id,
        UUID usuarioId,
        String usuarioNombre,
        TipoTurno turno,
        EstadoCaja estado,
        OffsetDateTime fechaApertura,
        OffsetDateTime fechaCierre,
        BigDecimal montoApertura,
        BigDecimal montoCierre,
        Integer contometroInicio,
        Integer contometroFin
) {
    public static CajaDto from(Caja c) {
        return CajaDto.builder()
                .id(c.getId())
                .usuarioId(c.getUsuario().getId())
                .usuarioNombre(c.getUsuario().getNombreCompleto())
                .turno(c.getTurno())
                .estado(c.getEstado())
                .fechaApertura(c.getFechaApertura())
                .fechaCierre(c.getFechaCierre())
                .montoApertura(c.getMontoApertura())
                .montoCierre(c.getMontoCierre())
                .contometroInicio(c.getContometroInicio())
                .contometroFin(c.getContometroFin())
                .build();
    }
}
