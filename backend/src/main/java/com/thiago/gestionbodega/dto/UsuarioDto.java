package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.RolUsuario;
import com.thiago.gestionbodega.entity.Usuario;
import lombok.Builder;

import java.util.UUID;

@Builder
public record UsuarioDto(
        UUID id,
        String username,
        String nombreCompleto,
        RolUsuario rol,
        boolean activo
) {
    public static UsuarioDto from(Usuario u) {
        return UsuarioDto.builder()
                .id(u.getId())
                .username(u.getUsername())
                .nombreCompleto(u.getNombreCompleto())
                .rol(u.getRol())
                .activo(u.isActivo())
                .build();
    }
}
