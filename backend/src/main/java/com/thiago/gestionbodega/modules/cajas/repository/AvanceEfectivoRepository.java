package com.thiago.gestionbodega.modules.cajas.repository;

import com.thiago.gestionbodega.modules.cajas.entity.AvanceEfectivo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AvanceEfectivoRepository extends JpaRepository<AvanceEfectivo, UUID> {

    List<AvanceEfectivo> findByCajaIdOrderByFechaDesc(UUID cajaId);

    @org.springframework.data.jpa.repository.Query(
        "SELECT COALESCE(SUM(a.monto), 0) FROM AvanceEfectivo a WHERE a.caja.id = :cajaId"
    )
    Optional<BigDecimal> sumarMontosPorCaja(UUID cajaId);
}
