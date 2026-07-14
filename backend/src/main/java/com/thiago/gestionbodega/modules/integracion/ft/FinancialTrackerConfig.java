package com.thiago.gestionbodega.modules.integracion.ft;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import javax.sql.DataSource;

/**
 * Configuracion del segundo DataSource: conexion a la BD financialtracker1 del
 * sistema de planilla del Hospital San Juan de Dios (FinantialTracker/Subcafae-HSJ).
 *
 * Solo se activa si integracion.financialtracker.enabled=true. Si esta
 * desactivado, los beans no se crean y los controladores del modulo devuelven
 * 503 (ver FinancialTrackerController).
 *
 * El pool es pequeno (max 3) porque solo se usa 1 vez al mes para cerrar el
 * periodo o para envios individuales esporadicos.
 */
@Configuration
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true", matchIfMissing = false)
public class FinancialTrackerConfig {

    @Bean
    @ConfigurationProperties("integracion.financialtracker")
    public FinancialTrackerProperties financialTrackerProperties() {
        return new FinancialTrackerProperties();
    }

    @Bean(name = "financialTrackerDataSource", destroyMethod = "close")
    public DataSource financialTrackerDataSource(FinancialTrackerProperties props) {
        HikariConfig cfg = new HikariConfig();
        cfg.setJdbcUrl(props.getUrl());
        cfg.setUsername(props.getUser());
        cfg.setPassword(props.getPassword());
        cfg.setDriverClassName("org.mariadb.jdbc.Driver");
        cfg.setMaximumPoolSize(3);
        cfg.setMinimumIdle(0);
        cfg.setConnectionTimeout(10_000);
        cfg.setIdleTimeout(60_000);
        cfg.setPoolName("FinancialTrackerPool");
        // Auto-commit off: los envios se hacen dentro de una transaccion manual
        cfg.setAutoCommit(true);
        return new HikariDataSource(cfg);
    }

    @Bean(name = "ftJdbc")
    public NamedParameterJdbcTemplate ftJdbc(
            @Qualifier("financialTrackerDataSource") DataSource ds) {
        return new NamedParameterJdbcTemplate(ds);
    }
}
