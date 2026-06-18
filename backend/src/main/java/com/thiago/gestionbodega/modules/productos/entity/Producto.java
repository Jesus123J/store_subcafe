package com.thiago.gestionbodega.modules.productos.entity;

import com.thiago.gestionbodega.common.audit.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "productos")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Producto extends BaseEntity {

    @Column(name = "codigo", unique = true, length = 50)
    private String codigo;

    @Column(name = "descripcion", nullable = false, length = 200)
    private String descripcion;

    @Column(name = "stock", nullable = false, precision = 10, scale = 2)
    private BigDecimal stock;

    @Column(name = "stock_minimo", nullable = false, precision = 10, scale = 2)
    private BigDecimal stockMinimo;

    @Column(name = "es_servicio", nullable = false)
    private boolean esServicio;

    @Column(name = "usa_contometro", nullable = false)
    private boolean usaContometro;

    /** True si el producto se puede canjear con vales o puntos (regla de Karina). */
    @Column(name = "es_bazar", nullable = false)
    private boolean esBazar;

    @Column(name = "activo", nullable = false)
    private boolean activo;
}
