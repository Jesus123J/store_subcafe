package com.thiago.gestionbodega.modules.creditos.repository;

import com.thiago.gestionbodega.modules.creditos.entity.CreditoTrabajador;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CreditoTrabajadorRepository extends JpaRepository<CreditoTrabajador, UUID> {

    /** Creditos pendientes (no cerrados) de un trabajador identificado por DNI. */
    List<CreditoTrabajador> findByTrabajadorDniAndCerradoFalse(String trabajadorDni);
}
