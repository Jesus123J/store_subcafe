package com.thiago.gestionbodega.modules.creditos.entity;

import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

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
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(length = 36)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trabajador_id", nullable = false)
    private Cliente trabajador;

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
