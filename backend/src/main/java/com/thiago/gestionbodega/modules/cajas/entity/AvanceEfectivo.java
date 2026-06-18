package com.thiago.gestionbodega.modules.cajas.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Avance de efectivo registrado durante un turno (ej: cambio para el vendedor,
 * pago a proveedor menor, etc). Resta del efectivo esperado en caja al cierre.
 */
@Entity
@Table(name = "avances_efectivo")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AvanceEfectivo {

    @Id
    @GeneratedValue
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "caja_id", nullable = false)
    private Caja caja;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "observacion", columnDefinition = "TEXT")
    private String observacion;

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @PrePersist
    void onCreate() {
        if (fecha == null) fecha = OffsetDateTime.now();
    }
}
