package com.thiago.gestionbodega.modules.ventas.repository;

import com.thiago.gestionbodega.modules.ventas.entity.VentaDetalle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VentaDetalleRepository extends JpaRepository<VentaDetalle, UUID> {
    List<VentaDetalle> findByVentaIdOrderByIdAsc(UUID ventaId);
}
