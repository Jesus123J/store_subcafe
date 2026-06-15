package com.thiago.gestionbodega.modules.clientes.entity;

import com.thiago.gestionbodega.common.audit.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "clientes")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Cliente extends BaseEntity {

    @Column(name = "dni", unique = true, nullable = false, length = 8)
    private String dni;

    @Column(name = "nombres", nullable = false, length = 150)
    private String nombres;

    @Column(name = "apellidos", nullable = false, length = 150)
    private String apellidos;

    @Column(name = "telefono", length = 20)
    private String telefono;

    @Column(name = "es_trabajador", nullable = false)
    private boolean esTrabajador;

    @Column(name = "activo", nullable = false)
    private boolean activo;

    public String getNombreCompleto() {
        return nombres + " " + apellidos;
    }
}
