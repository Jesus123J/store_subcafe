package com.thiago.gestionbodega.modules.ventas.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import com.thiago.gestionbodega.modules.ventas.repository.VentaRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Ventas")
@RestController
@RequestMapping("/ventas")
@RequiredArgsConstructor
public class VentaController {

    private final VentaRepository repository;

    @GetMapping
    public ApiResponse<List<Venta>> listar() {
        return ApiResponse.ok(repository.findAll());
    }
}
