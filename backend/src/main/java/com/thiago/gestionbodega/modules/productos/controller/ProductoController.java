package com.thiago.gestionbodega.modules.productos.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.productos.entity.Producto;
import com.thiago.gestionbodega.modules.productos.repository.ProductoRepository;
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

    private final ProductoRepository repository;

    @GetMapping
    public ApiResponse<List<Producto>> listar() {
        return ApiResponse.ok(repository.findByActivoTrue());
    }
}
