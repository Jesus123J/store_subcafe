package com.thiago.gestionbodega.repository;

import com.thiago.gestionbodega.entity.CreditoTrabajador;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CreditoTrabajadorRepository extends JpaRepository<CreditoTrabajador, UUID> {
    List<CreditoTrabajador> findByTrabajadorIdAndCerradoFalse(UUID trabajadorId);
    List<CreditoTrabajador> findByClienteIdOrderByFechaDesc(UUID clienteId);
    List<CreditoTrabajador> findByVentaId(UUID ventaId);
}
