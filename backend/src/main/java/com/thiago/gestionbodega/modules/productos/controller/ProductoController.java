package com.thiago.gestionbodega.modules.productos.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.productos.dto.ActualizarProductoRequest;
import com.thiago.gestionbodega.modules.productos.dto.CrearProductoRequest;
import com.thiago.gestionbodega.modules.productos.dto.ProductoDto;
import com.thiago.gestionbodega.modules.productos.service.ProductoService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Productos", description = "Catalogo de productos y servicios")
@RestController
@RequestMapping("/productos")
@RequiredArgsConstructor
public class ProductoController {

    private final ProductoService service;

    @GetMapping
    public ApiResponse<List<ProductoDto>> listar(
            @RequestParam(name = "soloActivos", defaultValue = "true") boolean soloActivos
    ) {
        return ApiResponse.ok(service.listar(soloActivos));
    }

    @GetMapping("/{id}")
    public ApiResponse<ProductoDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ProductoDto>> crear(
            @Valid @RequestBody CrearProductoRequest req
    ) {
        ProductoDto creado = service.crear(req);
        return ResponseEntity.status(201).body(
                ApiResponse.ok(creado, "Producto registrado"));
    }

    @PutMapping("/{id}")
    public ApiResponse<ProductoDto> actualizar(
            @PathVariable UUID id,
            @Valid @RequestBody ActualizarProductoRequest req
    ) {
        return ApiResponse.ok(service.actualizar(id, req), "Producto actualizado");
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> desactivar(@PathVariable UUID id) {
        service.desactivar(id);
        return ResponseEntity.noContent().build();
    }
}
