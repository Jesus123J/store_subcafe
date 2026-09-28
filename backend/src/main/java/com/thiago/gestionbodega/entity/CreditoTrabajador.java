package com.thiago.gestionbodega.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

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
    private UUID id;

    /** @deprecated LEGACY: usuario del sistema. Usar {@link #cliente}. */
    @Deprecated
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_id")
    private Usuario trabajador;

    /** Trabajador (cliente sincronizado desde FinantialTracker) que debe. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_id")
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "venta_id")
    private Venta venta;

    @Column(name = "monto", nullable = false, precision = 10, scale = 2)
    private BigDecimal monto;

    @Column(name = "descripcion", length = 200)
    private String descripcion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "registrado_por")
    private Usuario registradoPor;

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @Column(name = "cerrado", nullable = false)
    private boolean cerrado;

    @Column(name = "cerrado_en")
    private OffsetDateTime cerradoEn;

    /** cierres_mensuales_creditos.id (CHAR(36)) en el que se incluyo. */
    @Column(name = "cierre_id")
    private UUID cierreId;

    /** Periodo (anio/mes) al que pertenece el credito para el cierre mensual. */
    @Column(name = "periodo_anio", nullable = false)
    private Integer periodoAnio;

    @Column(name = "periodo_mes", nullable = false)
    private Integer periodoMes;

    @PrePersist
    void onCreate() {
        OffsetDateTime ahora = OffsetDateTime.now();
        if (fecha == null) fecha = ahora;
        if (periodoAnio == null) periodoAnio = ahora.getYear();
        if (periodoMes == null) periodoMes = ahora.getMonthValue();
    }
}
