package com.thiago.gestionbodega.modules.usuarios.dto;

import com.thiago.gestionbodega.modules.usuarios.entity.RolUsuario;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CrearUsuarioRequest(
        @NotBlank @Size(min = 3, max = 50) String username,
        @NotBlank @Size(min = 6, max = 100) String password,
        @NotBlank @Size(max = 150) String nombreCompleto,
        @NotNull RolUsuario rol
) {}
