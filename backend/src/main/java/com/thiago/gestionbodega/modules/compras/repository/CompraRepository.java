package com.thiago.gestionbodega.modules.compras.repository;

import com.thiago.gestionbodega.modules.compras.entity.Compra;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface CompraRepository extends JpaRepository<Compra, UUID> {
}
