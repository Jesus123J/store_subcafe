package com.thiago.gestionbodega.dto;


public record LoginResponse(
        String token,
        long expiresIn,        // segundos
        UsuarioDto usuario
) {}
