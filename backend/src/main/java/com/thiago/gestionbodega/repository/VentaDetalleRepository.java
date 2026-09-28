package com.thiago.gestionbodega.repository;

import com.thiago.gestionbodega.entity.VentaDetalle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VentaDetalleRepository extends JpaRepository<VentaDetalle, UUID> {
    List<VentaDetalle> findByVentaId(UUID ventaId);
}
