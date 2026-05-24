package com.thiago.gestionbodega.modules.usuarios.dto;

import com.thiago.gestionbodega.modules.usuarios.entity.RolUsuario;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ActualizarUsuarioRequest(
        @NotBlank @Size(max = 150) String nombreCompleto,
        @NotNull RolUsuario rol,
        boolean activo
) {}
