package com.thiago.gestionbodega.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record GuardarProveedorRequest(
        @NotBlank @Size(max = 200) String razonSocial,
        @NotBlank @Pattern(regexp = "\\d{11}", message = "El RUC debe tener 11 digitos") String ruc,
        @Size(max = 500) String direccion,
        @Size(max = 20) String telefono,
        Boolean activo
) {}
