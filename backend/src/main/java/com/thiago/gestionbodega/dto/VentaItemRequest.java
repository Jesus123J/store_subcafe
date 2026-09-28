package com.thiago.gestionbodega.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record VentaItemRequest(
        @NotNull UUID productoId,
        @NotNull @DecimalMin(value = "0.01") BigDecimal cantidad,
        /** Opcional: si viene null se usa el precio vigente del producto. */
        @DecimalMin(value = "0.00") BigDecimal precioUnitario
) {}
