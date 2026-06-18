package com.thiago.gestionbodega.modules.proveedores.dto;

import com.thiago.gestionbodega.modules.proveedores.entity.Proveedor;
import lombok.Builder;

import java.util.UUID;

@Builder
public record ProveedorDto(
        UUID id,
        String razonSocial,
        String ruc,
        String direccion,
        String telefono,
        boolean activo
) {
    public static ProveedorDto from(Proveedor p) {
        return ProveedorDto.builder()
                .id(p.getId())
                .razonSocial(p.getRazonSocial())
                .ruc(p.getRuc())
                .direccion(p.getDireccion())
                .telefono(p.getTelefono())
                .activo(p.isActivo())
                .build();
    }
}
