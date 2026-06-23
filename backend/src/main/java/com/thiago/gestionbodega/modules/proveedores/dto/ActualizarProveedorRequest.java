package com.thiago.gestionbodega.modules.proveedores.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ActualizarProveedorRequest(
        @NotBlank @Size(max = 200) String razonSocial,
        @Size(max = 1000) String direccion,
        @Size(max = 20) String telefono,
        boolean activo
) {}
