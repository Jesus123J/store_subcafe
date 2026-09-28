package com.thiago.gestionbodega.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

import java.time.OffsetDateTime;
import java.util.Optional;

/**
 * Auditoria JPA: rellena creado_en / actualizado_en (ver BaseEntity).
 *
 * Spring Data por defecto entrega LocalDateTime y no sabe convertirlo a
 * OffsetDateTime (falla con "Cannot convert unsupported date type"), asi que
 * registramos un DateTimeProvider que devuelve OffsetDateTime directamente.
 */
@Configuration
@EnableJpaAuditing(dateTimeProviderRef = "auditingDateTimeProvider")
public class JpaAuditingConfig {

    @Bean
    public DateTimeProvider auditingDateTimeProvider() {
        return () -> Optional.of(OffsetDateTime.now());
    }
}
