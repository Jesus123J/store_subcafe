package com.thiago.gestionbodega.modules.proveedores.repository;

import com.thiago.gestionbodega.modules.proveedores.entity.Proveedor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProveedorRepository extends JpaRepository<Proveedor, UUID> {
    Optional<Proveedor> findByRuc(String ruc);
}
