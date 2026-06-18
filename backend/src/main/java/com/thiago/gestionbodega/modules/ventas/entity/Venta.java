package com.thiago.gestionbodega.modules.ventas.entity;

import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

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
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "caja_id", nullable = false)
    private Caja caja;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

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
    @Column(name = "forma_pago", length = 10)
    private FormaPago formaPago;

    /**
     * @deprecated Desde V3 - usar {@code pagos[i].trabajadorCredito}.
     * Desde V7 apunta a {@link Cliente} (con es_trabajador = TRUE), no a Usuario.
     */
    @Deprecated
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_credito_id")
    private Cliente trabajadorCredito;

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

    /** Helper para agregar un pago manteniendo la relacion bidireccional. */
    public void agregarPago(VentaPago pago) {
        pago.setVenta(this);
        pago.setOrden(this.pagos.size());
        this.pagos.add(pago);
    }
}
