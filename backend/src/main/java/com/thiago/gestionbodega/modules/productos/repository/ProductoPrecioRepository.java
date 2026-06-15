package com.thiago.gestionbodega.modules.productos.repository;

import com.thiago.gestionbodega.modules.productos.entity.ProductoPrecio;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProductoPrecioRepository extends JpaRepository<ProductoPrecio, UUID> {

    /** Devuelve el ultimo precio (mas reciente) de un producto. */
    Optional<ProductoPrecio> findFirstByProductoIdOrderByVigenteDesdeDesc(UUID productoId);
}
