package com.thiago.gestionbodega.modules.usuarios.repository;

import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UsuarioRepository extends JpaRepository<Usuario, UUID> {
    Optional<Usuario> findByUsername(String username);
    boolean existsByUsername(String username);
}
