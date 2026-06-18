package com.thiago.gestionbodega.modules.ventas.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record VentaDetalleRequest(
        @NotNull UUID productoId,
        @NotNull @DecimalMin(value = "0.001") BigDecimal cantidad,
        /** Precio aplicado en la venta (puede diferir del precio_venta por canje, descuento manual, etc). */
        @NotNull @DecimalMin(value = "0.0") BigDecimal precioUnitario
) {}
