package com.thiago.gestionbodega.modules.proveedores.entity;

import com.thiago.gestionbodega.common.audit.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

@Entity
@Table(name = "proveedores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Proveedor extends BaseEntity {

    @Column(name = "razon_social", nullable = false, length = 200)
    private String razonSocial;

    @Column(name = "ruc", unique = true, nullable = false, length = 11)
    private String ruc;

    @Column(name = "direccion", columnDefinition = "TEXT")
    private String direccion;

    @Column(name = "telefono", length = 20)
    private String telefono;

    @Column(name = "activo", nullable = false)
    private boolean activo;
}
