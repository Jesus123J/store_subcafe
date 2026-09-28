package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.entity.Proveedor;
import com.thiago.gestionbodega.repository.ProveedorRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Proveedores")
@RestController
@RequestMapping("/proveedores")
@RequiredArgsConstructor
public class ProveedorController {

    private final ProveedorRepository repository;

    @GetMapping
    public ApiResponse<List<Proveedor>> listar() {
        return ApiResponse.ok(repository.findAll());
    }
}
