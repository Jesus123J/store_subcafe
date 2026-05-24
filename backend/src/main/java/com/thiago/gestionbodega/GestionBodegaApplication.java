package com.thiago.gestionbodega;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@SpringBootApplication
@EnableJpaAuditing
public class GestionBodegaApplication {

    public static void main(String[] args) {
        SpringApplication.run(GestionBodegaApplication.class, args);
    }
}
