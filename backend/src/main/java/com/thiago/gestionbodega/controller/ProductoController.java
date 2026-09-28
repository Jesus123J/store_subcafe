package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.ProductoDto;
import com.thiago.gestionbodega.service.ProductoService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Productos")
@RestController
@RequestMapping("/productos")
@RequiredArgsConstructor
public class ProductoController {

    private final ProductoService service;

    /** Productos activos con precio vigente, listos para el POS. */
    @GetMapping
    public ApiResponse<List<ProductoDto>> listar() {
        return ApiResponse.ok(service.listarActivos());
    }
}
