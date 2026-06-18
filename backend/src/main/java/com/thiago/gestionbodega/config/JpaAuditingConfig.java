package com.thiago.gestionbodega.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

import java.time.OffsetDateTime;
import java.util.Optional;

/**
 * Provee {@code OffsetDateTime} a {@code @CreatedDate} y {@code @LastModifiedDate}.
 *
 * Por defecto Spring Data genera {@code LocalDateTime} y falla al asignarlo a
 * campos {@code OffsetDateTime} (como {@code BaseEntity.actualizadoEn}) con
 * {@code "Cannot convert unsupported date type java.time.LocalDateTime to java.time.OffsetDateTime"}.
 *
 * El error solo se dispara al UPDATE de un BaseEntity (ej: al descontar stock
 * de un producto durante una venta), por eso paso desapercibido hasta hoy.
 */
@Configuration
@EnableJpaAuditing(dateTimeProviderRef = "auditingDateTimeProvider")
public class JpaAuditingConfig {

    @Bean
    public DateTimeProvider auditingDateTimeProvider() {
        return () -> Optional.of(OffsetDateTime.now());
    }
}
