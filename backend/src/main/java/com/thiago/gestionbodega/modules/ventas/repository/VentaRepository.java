package com.thiago.gestionbodega.modules.ventas.repository;

import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface VentaRepository extends JpaRepository<Venta, UUID> {
    List<Venta> findByFechaBetweenAndAnuladaFalse(OffsetDateTime inicio, OffsetDateTime fin);
    List<Venta> findByCajaId(UUID cajaId);
}
