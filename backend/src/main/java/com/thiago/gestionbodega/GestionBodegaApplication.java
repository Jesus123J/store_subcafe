package com.thiago.gestionbodega;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * {@code @EnableJpaAuditing} esta en {@link com.thiago.gestionbodega.config.JpaAuditingConfig}
 * para poder configurar el {@code DateTimeProvider} con {@code OffsetDateTime}.
 */
@SpringBootApplication
public class GestionBodegaApplication {

    public static void main(String[] args) {
        SpringApplication.run(GestionBodegaApplication.class, args);
    }
}
