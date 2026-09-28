package com.thiago.gestionbodega.dto;

import com.thiago.gestionbodega.entity.Cliente;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;

import java.util.UUID;

@Builder
public record ClienteDto(
        UUID id,
        @NotBlank @Pattern(regexp = "\\d{8,9}", message = "DNI debe tener 8 digitos (9 si es carnet de extranjeria)") String dni,
        @NotBlank @Size(max = 150) String nombres,
        @NotBlank @Size(max = 150) String apellidos,
        String telefono,
        boolean esTrabajador,
        boolean activo,
        Integer empleadoId,          // employees.employee_id (FinantialTracker), null si es manual
        String condicionLaboral,     // Nombrado | CAS
        String origen                // MANUAL | FINANTIAL
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
                .empleadoId(c.getEmpleadoId())
                .condicionLaboral(c.getCondicionLaboral())
                .origen(c.getOrigen())
                .build();
    }
}
