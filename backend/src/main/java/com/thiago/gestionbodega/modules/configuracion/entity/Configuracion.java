package com.thiago.gestionbodega.modules.configuracion.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "configuracion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Configuracion {

    @Id
    @Column(name = "clave", length = 80)
    private String clave;

    @Column(name = "valor", columnDefinition = "TEXT")
    private String valor;

    @Column(name = "descripcion", columnDefinition = "TEXT")
    private String descripcion;

    @Column(name = "actualizada_en", nullable = false)
    private OffsetDateTime actualizadaEn;

    @PrePersist @PreUpdate
    void onSave() { actualizadaEn = OffsetDateTime.now(); }
}
