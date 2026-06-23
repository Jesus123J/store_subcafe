package com.thiago.gestionbodega.modules.ventas.dto;

import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Pago parcial de una venta (pago mixto).
 * Si formaPago es CREDITO, trabajadorCreditoId es obligatorio.
 * Si es YAPE/PLIN/NIUBIZ, codigoOperacion suele estar presente.
 */
public record VentaPagoRequest(
        @NotNull FormaPago formaPago,
        @NotNull @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0") BigDecimal monto,
        @Size(max = 20) String codigoOperacion,
        UUID trabajadorCreditoId
) {}
