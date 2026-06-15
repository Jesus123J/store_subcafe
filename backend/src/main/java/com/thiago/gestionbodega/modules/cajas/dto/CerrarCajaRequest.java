package com.thiago.gestionbodega.modules.cajas.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record CerrarCajaRequest(
        @NotNull @DecimalMin(value = "0.00") BigDecimal montoCierre,
        Integer contometroFin
) {}
