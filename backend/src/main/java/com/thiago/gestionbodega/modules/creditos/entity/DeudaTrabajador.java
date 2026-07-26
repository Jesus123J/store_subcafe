package com.thiago.gestionbodega.modules.creditos.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Deuda acumulada de un trabajador (planilla). Referenciado solo por DNI
 * — el trabajador vive en FinantialTracker.
 */
@Entity
@Table(name = "deuda_trabajadores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeudaTrabajador {

    @Id
    @GeneratedValue
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    @Column(name = "trabajador_dni", nullable = false, unique = true, length = 8)
    private String trabajadorDni;

    @Column(name = "monto_total", nullable = false, precision = 10, scale = 2)
    private BigDecimal montoTotal;

    @Column(name = "actualizada_en", nullable = false)
    private OffsetDateTime actualizadaEn;
}
