package com.thiago.gestionbodega.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "ventas")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Venta {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "caja_id", nullable = false)
    private Caja caja;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

    /** Trabajador identificado en la venta (opcional). Acumula puntos aunque pague al contado. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_id")
    private Cliente cliente;

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @Column(name = "total", nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    /**
     * @deprecated Desde V3 una venta puede tener varias formas de pago.
     * Usar {@link #pagos} en su lugar. Esta columna se mantiene por
     * compatibilidad con queries y reportes legacy.
     */
    @Deprecated
    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pago", length = 20)
    private FormaPago formaPago;

    /**
     * @deprecated Desde V3 - usar {@code pagos[i].trabajadorCredito}.
     */
    @Deprecated
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_credito_id")
    private Usuario trabajadorCredito;

    /**
     * Pagos parciales que conforman el total de la venta.
     * Una venta puede dividirse entre varias formas de pago.
     * La suma de pagos[].monto debe ser igual a {@link #total}
     * (validado por trigger en BD).
     */
    @OneToMany(mappedBy = "venta", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<VentaPago> pagos = new ArrayList<>();

    @Column(name = "anulada", nullable = false)
    private boolean anulada;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "anulada_por")
    private Usuario anuladaPor;

    @Column(name = "motivo_anulacion", columnDefinition = "TEXT")
    private String motivoAnulacion;

    @Column(name = "observacion", length = 300)
    private String observacion;

    @OneToMany(mappedBy = "venta", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<VentaDetalle> items = new ArrayList<>();

    /** Helper para agregar un item manteniendo la relacion bidireccional. */
    public void agregarItem(VentaDetalle item) {
        item.setVenta(this);
        this.items.add(item);
    }

    /** Helper para agregar un pago manteniendo la relacion bidireccional. */
    public void agregarPago(VentaPago pago) {
        pago.setVenta(this);
        pago.setOrden(this.pagos.size());
        this.pagos.add(pago);
    }
}
