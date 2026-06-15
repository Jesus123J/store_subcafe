package com.thiago.gestionbodega.modules.compras.repository;

import com.thiago.gestionbodega.modules.compras.entity.CompraDetalle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CompraDetalleRepository extends JpaRepository<CompraDetalle, UUID> {
    List<CompraDetalle> findByCompraIdOrderByIdAsc(UUID compraId);
}
