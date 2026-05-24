package com.thiago.gestionbodega.modules.creditos.entity;

import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "deuda_trabajadores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeudaTrabajador {

    @Id
    @GeneratedValue
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trabajador_id", nullable = false, unique = true)
    private Usuario trabajador;

    @Column(name = "monto_total", nullable = false, precision = 10, scale = 2)
    private BigDecimal montoTotal;

    @Column(name = "actualizada_en", nullable = false)
    private OffsetDateTime actualizadaEn;
}
