package com.thiago.gestionbodega.modules.productos.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record CrearProductoRequest(
        @Size(max = 50) String codigo,
        @NotBlank @Size(max = 200) String descripcion,
        @NotNull @DecimalMin(value = "0.0") BigDecimal stockInicial,
        @NotNull @DecimalMin(value = "0.0") BigDecimal stockMinimo,
        @NotNull @DecimalMin(value = "0.0") BigDecimal costo,
        @NotNull @DecimalMin(value = "0.0") BigDecimal precioVenta,
        boolean esServicio,
        boolean usaContometro,
        boolean esBazar
) {}
