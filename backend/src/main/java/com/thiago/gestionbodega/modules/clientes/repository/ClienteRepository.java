package com.thiago.gestionbodega.modules.clientes.repository;

import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ClienteRepository extends JpaRepository<Cliente, UUID> {

    Optional<Cliente> findByDni(String dni);
    boolean existsByDni(String dni);

    @Query("SELECT c FROM Cliente c WHERE c.activo = true AND " +
           "(LOWER(c.dni) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           " LOWER(c.nombres) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           " LOWER(c.apellidos) LIKE LOWER(CONCAT('%', :q, '%')))")
    List<Cliente> buscar(@Param("q") String q);
}
