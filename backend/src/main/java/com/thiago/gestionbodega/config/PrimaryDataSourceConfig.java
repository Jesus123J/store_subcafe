package com.thiago.gestionbodega.config;

import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import javax.sql.DataSource;

/**
 * Declara explicitamente el DataSource principal (bodega) como {@code @Primary}
 * junto con sus JdbcTemplate.
 *
 * Necesario porque el modulo de integracion FinantialTracker declara un
 * segundo DataSource + JdbcTemplate. Sin @Primary aca, Spring Boot deja de
 * autoconfigurar los templates principales y los services que hacen
 * {@code private final NamedParameterJdbcTemplate jdbc;} reciben por
 * casualidad el de FT (que no tiene password valido) y todo revienta con
 * "Access denied for user 'root'".
 */
@Configuration
public class PrimaryDataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties primaryDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource.hikari")
    public DataSource dataSource(DataSourceProperties props) {
        return props.initializeDataSourceBuilder().build();
    }

    @Bean
    @Primary
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }

    @Bean
    @Primary
    public NamedParameterJdbcTemplate namedParameterJdbcTemplate(DataSource dataSource) {
        return new NamedParameterJdbcTemplate(dataSource);
    }
}
