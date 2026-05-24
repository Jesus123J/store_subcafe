package com.thiago.gestionbodega.modules.productos.repository;

import com.thiago.gestionbodega.modules.productos.entity.Producto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProductoRepository extends JpaRepository<Producto, UUID> {
    Optional<Producto> findByCodigo(String codigo);
    List<Producto> findByActivoTrue();
}
