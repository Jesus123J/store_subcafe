package com.thiago.gestionbodega.modules.cajas.dto;

import com.thiago.gestionbodega.modules.cajas.entity.TipoTurno;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record AbrirCajaRequest(
        @NotNull TipoTurno turno,
        @NotNull @DecimalMin(value = "0.00") BigDecimal montoApertura,
        Integer contometroInicio
) {}
