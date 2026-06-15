package com.thiago.gestionbodega.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Configuracion de Flyway.
 *
 * Define una estrategia de migracion que ejecuta {@code repair()} antes de
 * {@code migrate()}. Esto sincroniza los checksums de la tabla
 * {@code flyway_schema_history} con los archivos actuales sin destruir
 * datos.
 *
 * Es util en desarrollo cuando se ajusta una migracion ya aplicada y Flyway
 * bloquea el arranque con: {@code Migration checksum mismatch for migration version N}.
 *
 * En produccion conviene desactivarlo (env var {@code FLYWAY_REPAIR=false}) y
 * gestionar cambios solo creando nuevas migraciones (V4, V5, ...).
 */
@Configuration
public class FlywayConfig {

    private static final Logger log = LoggerFactory.getLogger(FlywayConfig.class);

    @Value("${app.flyway.repair-on-startup:true}")
    private boolean repairOnStartup;

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            if (repairOnStartup) {
                log.info("Flyway: ejecutando repair() antes de migrate() (resuelve checksum mismatches)");
                flyway.repair();
            }
            log.info("Flyway: ejecutando migrate()");
            flyway.migrate();
        };
    }
}
