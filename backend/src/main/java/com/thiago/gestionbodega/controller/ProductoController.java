package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.GuardarProductoRequest;
import com.thiago.gestionbodega.dto.ProductoDto;
import com.thiago.gestionbodega.service.ProductoService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

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

    @GetMapping("/{id}")
    public ApiResponse<ProductoDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ResponseEntity<ApiResponse<ProductoDto>> crear(@Valid @RequestBody GuardarProductoRequest req) {
        return ResponseEntity.status(201).body(ApiResponse.ok(service.crear(req), "Producto creado"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<ProductoDto> actualizar(@PathVariable UUID id, @Valid @RequestBody GuardarProductoRequest req) {
        return ApiResponse.ok(service.actualizar(id, req), "Producto actualizado");
    }
}
