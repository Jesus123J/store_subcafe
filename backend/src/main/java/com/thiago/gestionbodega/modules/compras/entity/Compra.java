package com.thiago.gestionbodega.modules.compras.entity;

import com.thiago.gestionbodega.modules.proveedores.entity.Proveedor;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "compras")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Compra {

    @Id
    @GeneratedValue
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "proveedor_id", nullable = false)
    private Proveedor proveedor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

    @Column(name = "fecha", nullable = false)
    private OffsetDateTime fecha;

    @Column(name = "total", nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    @Column(name = "nro_documento", length = 50)
    private String nroDocumento;

    @Column(name = "observaciones", columnDefinition = "TEXT")
    private String observaciones;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private OffsetDateTime creadoEn;
}
