package com.thiago.gestionbodega.modules.vales.dto;

import com.thiago.gestionbodega.modules.vales.entity.TipoVale;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record EmitirValeRequest(
        @NotNull TipoVale tipo,
        UUID clienteId,                                  // obligatorio si tipo=NOMBRADO
        @NotNull @DecimalMin(value = "0.01") BigDecimal monto,
        LocalDate fechaVencimiento,                      // null = sin vencer
        String observaciones
) {}
