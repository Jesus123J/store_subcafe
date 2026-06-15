package com.thiago.gestionbodega.modules.cajas.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record AvanceRequest(
        @NotNull @DecimalMin(value = "0.01") BigDecimal monto,
        String observacion
) {}
