package com.thiago.gestionbodega.modules.ventas.entity;

import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
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

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @Column(name = "total", nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "forma_pago", nullable = false, columnDefinition = "forma_pago")
    private FormaPago formaPago;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trabajador_credito_id")
    private Usuario trabajadorCredito;

    @Column(name = "anulada", nullable = false)
    private boolean anulada;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "anulada_por")
    private Usuario anuladaPor;

    @Column(name = "motivo_anulacion", columnDefinition = "TEXT")
    private String motivoAnulacion;
}
