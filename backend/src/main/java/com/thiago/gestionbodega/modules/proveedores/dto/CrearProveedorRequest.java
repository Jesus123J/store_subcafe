package com.thiago.gestionbodega.modules.proveedores.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CrearProveedorRequest(
        @NotBlank @Size(max = 200) String razonSocial,
        @NotBlank @Pattern(regexp = "^\\d{11}$", message = "RUC debe tener 11 digitos") String ruc,
        @Size(max = 1000) String direccion,
        @Size(max = 20) String telefono
) {}
