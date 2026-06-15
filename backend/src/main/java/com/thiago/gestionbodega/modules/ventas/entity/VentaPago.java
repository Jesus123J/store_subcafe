package com.thiago.gestionbodega.modules.ventas.entity;

import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
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
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "forma_pago", nullable = false, columnDefinition = "forma_pago")
    private FormaPago formaPago;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "codigo_operacion", length = 20)
    private String codigoOperacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_credito_id")
    private Usuario trabajadorCredito;

    @Column(name = "orden", nullable = false)
    @Builder.Default
    private Integer orden = 0;
}
