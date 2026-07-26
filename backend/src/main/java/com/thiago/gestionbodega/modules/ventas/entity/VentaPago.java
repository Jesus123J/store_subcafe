package com.thiago.gestionbodega.modules.ventas.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Pago parcial de una venta. Una venta puede tener varios VentaPago
 * (ej: parte en efectivo, parte en Yape, parte en credito).
 *
 * Cuando forma_pago = CREDITO, trabajadorCreditoDni referencia al
 * empleado en FinantialTracker (sin FK local — passthrough).
 */
@Entity
@Table(name = "venta_pagos")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VentaPago {

    @Id
    @GeneratedValue
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venta_id", nullable = false)
    private Venta venta;

    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pago", nullable = false, length = 10)
    private FormaPago formaPago;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "codigo_operacion", length = 20)
    private String codigoOperacion;

    /** DNI del trabajador cuando forma_pago = CREDITO. */
    @Column(name = "trabajador_credito_dni", length = 8)
    private String trabajadorCreditoDni;

    @Column(name = "orden", nullable = false)
    @Builder.Default
    private Integer orden = 0;
}
