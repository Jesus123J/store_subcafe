package com.thiago.gestionbodega.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

/** Deuda registrada a mano (sin pasar por el POS), p. ej. consumo anotado en cuaderno. */
public record RegistrarConsumoCreditoRequest(
        @NotNull UUID clienteId,
        @NotNull @DecimalMin(value = "0.01") BigDecimal monto,
        @NotBlank @Size(max = 200) String descripcion
) {}
