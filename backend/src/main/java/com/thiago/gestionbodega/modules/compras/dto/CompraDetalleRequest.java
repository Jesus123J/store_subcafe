package com.thiago.gestionbodega.modules.compras.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record CompraDetalleRequest(
        @NotNull UUID productoId,
        @NotNull @DecimalMin(value = "0.01") BigDecimal cantidad,
        @NotNull @DecimalMin(value = "0.00") BigDecimal costoUnitario
) {}
