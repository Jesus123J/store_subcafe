package com.thiago.gestionbodega.modules.cajas.repository;

import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.entity.EstadoCaja;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CajaRepository extends JpaRepository<Caja, UUID> {

    List<Caja> findByEstado(EstadoCaja estado);

    /**
     * Retorna la caja ABIERTA del usuario indicado (o vacio si no tiene ninguna).
     * Solo deberia existir una por usuario.
     */
    Optional<Caja> findFirstByUsuarioIdAndEstado(UUID usuarioId, EstadoCaja estado);

    boolean existsByUsuarioIdAndEstado(UUID usuarioId, EstadoCaja estado);

    /**
     * Suma de montos de los pagos de venta agrupados por forma de pago para una caja.
     * Solo cuenta ventas NO anuladas.
     *
     * Retorna lista de arrays [formaPago: String, total: BigDecimal].
     */
    @Query(value = """
            SELECT vp.forma_pago, COALESCE(SUM(vp.monto), 0)
            FROM venta_pagos vp
            JOIN ventas v ON v.id = vp.venta_id
            WHERE v.caja_id = :cajaId AND v.anulada = false
            GROUP BY vp.forma_pago
            """, nativeQuery = true)
    List<Object[]> totalesPorFormaPago(@Param("cajaId") UUID cajaId);

    @Query(value = """
            SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.caja_id = :cajaId AND v.anulada = false
            """, nativeQuery = true)
    BigDecimal totalVentasNoAnuladas(@Param("cajaId") UUID cajaId);
}
