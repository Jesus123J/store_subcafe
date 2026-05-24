package com.thiago.gestionbodega.modules.auth.dto;

import com.thiago.gestionbodega.modules.usuarios.dto.UsuarioDto;

public record LoginResponse(
        String token,
        long expiresIn,        // segundos
        UsuarioDto usuario
) {}
