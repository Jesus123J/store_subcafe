package com.thiago.gestionbodega.modules.configuracion.repository;

import com.thiago.gestionbodega.modules.configuracion.entity.Configuracion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ConfiguracionRepository extends JpaRepository<Configuracion, String> {}
