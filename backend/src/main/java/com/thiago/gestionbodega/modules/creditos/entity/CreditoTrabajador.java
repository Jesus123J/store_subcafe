package com.thiago.gestionbodega.modules.creditos.entity;

import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Consumo a credito de un trabajador. El trabajador se identifica solo por
 * DNI — vive en FinantialTracker.employees, no hay tabla local ni FK.
 *
 * Para mostrar el nombre en la UI, la app resuelve via passthrough a FT.
 */
@Entity
@Table(name = "creditos_trabajadores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreditoTrabajador {

    @Id
    @GeneratedValue
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    /** DNI del trabajador en FinantialTracker.employees.national_id. */
    @Column(name = "trabajador_dni", nullable = false, length = 8)
    private String trabajadorDni;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "venta_id")
    private Venta venta;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @Column(name = "cerrado", nullable = false)
    private boolean cerrado;

    @Column(name = "cerrado_en")
    private OffsetDateTime cerradoEn;
}
