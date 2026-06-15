package com.thiago.gestionbodega.modules.clientes.dto;

import lombok.Builder;

import java.util.List;

@Builder
public record ImportResultDto(
        int total,
        int creados,
        int actualizados,
        int errores,
        List<String> mensajesError
) {}
