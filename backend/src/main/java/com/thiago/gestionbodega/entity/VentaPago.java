package com.thiago.gestionbodega.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Pago parcial de una venta. Una venta puede tener varios VentaPago
 * (ej: parte en efectivo, parte en Yape, parte en credito).
 *
 * Restriccion a nivel BD (trigger): la suma de monto debe coincidir
 * con ventas.total.
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
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venta_id", nullable = false)
    private Venta venta;

    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pago", nullable = false, length = 20)
    private FormaPago formaPago;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "codigo_operacion", length = 20)
    private String codigoOperacion;

    /** @deprecated LEGACY (usuario del sistema). Usar {@link #clienteCredito}. */
    @Deprecated
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_credito_id")
    private Usuario trabajadorCredito;

    /** Trabajador que asume el credito (solo cuando formaPago = CREDITO). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_credito_id")
    private Cliente clienteCredito;

    @Column(name = "orden", nullable = false)
    @Builder.Default
    private Integer orden = 0;
}
