package com.thiago.gestionbodega.modules.vales.repository;

import com.thiago.gestionbodega.modules.vales.entity.EstadoVale;
import com.thiago.gestionbodega.modules.vales.entity.Vale;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ValeRepository extends JpaRepository<Vale, UUID> {
    Optional<Vale> findByCodigo(String codigo);
    List<Vale> findByEstadoOrderByFechaEmisionDesc(EstadoVale estado);
    List<Vale> findByClienteIdAndEstado(UUID clienteId, EstadoVale estado);
    long countByEstado(EstadoVale estado);
}
