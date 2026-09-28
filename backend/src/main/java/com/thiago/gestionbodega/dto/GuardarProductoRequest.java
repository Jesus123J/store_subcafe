package com.thiago.gestionbodega.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/** Alta / edicion de producto. Si cambia costo o precio se crea un nuevo producto_precios. */
public record GuardarProductoRequest(
        @Size(max = 50) String codigo,
        @NotBlank @Size(max = 200) String descripcion,
        @DecimalMin(value = "0.00") BigDecimal stock,          // solo en alta (stock inicial)
        @DecimalMin(value = "0.00") BigDecimal stockMinimo,
        boolean esServicio,
        boolean usaContometro,
        boolean esBazar,
        Boolean activo,                                        // null = no cambiar
        @NotNull @DecimalMin(value = "0.00") BigDecimal costo,
        @NotNull @DecimalMin(value = "0.01") BigDecimal precioVenta
) {}
