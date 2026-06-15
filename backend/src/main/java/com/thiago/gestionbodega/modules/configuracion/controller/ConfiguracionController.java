package com.thiago.gestionbodega.modules.configuracion.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.configuracion.entity.Configuracion;
import com.thiago.gestionbodega.modules.configuracion.repository.ConfiguracionRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * API de configuracion del negocio. Funciona como un key-value store
 * donde el admin puede leer/escribir todos los datos editables.
 */
@Tag(name = "Configuracion")
@RestController
@RequestMapping("/configuracion")
@RequiredArgsConstructor
public class ConfiguracionController {

    private final ConfiguracionRepository repo;

    @GetMapping
    public ApiResponse<Map<String, String>> obtener() {
        Map<String, String> out = new LinkedHashMap<>();
        repo.findAll().forEach(c -> out.put(c.getClave(), c.getValor()));
        return ApiResponse.ok(out);
    }

    @PutMapping
    @Transactional
    public ApiResponse<Map<String, String>> actualizar(@RequestBody Map<String, String> body) {
        body.forEach((clave, valor) -> {
            Configuracion c = repo.findById(clave).orElseGet(() ->
                Configuracion.builder().clave(clave).build());
            c.setValor(valor);
            repo.save(c);
        });
        return obtener();
    }
}
