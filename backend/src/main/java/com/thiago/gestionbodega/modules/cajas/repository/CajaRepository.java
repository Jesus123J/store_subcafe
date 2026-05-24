package com.thiago.gestionbodega.modules.cajas.repository;

import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.entity.EstadoCaja;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CajaRepository extends JpaRepository<Caja, UUID> {
    List<Caja> findByEstado(EstadoCaja estado);
}
