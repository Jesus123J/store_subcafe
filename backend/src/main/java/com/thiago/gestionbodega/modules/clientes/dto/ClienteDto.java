package com.thiago.gestionbodega.modules.clientes.dto;

import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.util.UUID;

@Builder
public record ClienteDto(
        UUID id,
        @NotBlank @Pattern(regexp = "\\d{8}", message = "DNI debe tener 8 digitos") String dni,
        @NotBlank @Size(max = 150) String nombres,
        @NotBlank @Size(max = 150) String apellidos,
        String telefono,
        boolean esTrabajador,
        boolean activo
) {
    public static ClienteDto from(Cliente c) {
        return ClienteDto.builder()
                .id(c.getId())
                .dni(c.getDni())
                .nombres(c.getNombres())
                .apellidos(c.getApellidos())
                .telefono(c.getTelefono())
                .esTrabajador(c.isEsTrabajador())
                .activo(c.isActivo())
                .build();
    }
}
