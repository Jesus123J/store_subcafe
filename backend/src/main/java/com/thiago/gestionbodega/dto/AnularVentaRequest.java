package com.thiago.gestionbodega.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AnularVentaRequest(
        @NotBlank @Size(max = 300) String motivo
) {}
