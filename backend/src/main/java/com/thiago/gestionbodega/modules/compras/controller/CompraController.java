package com.thiago.gestionbodega.modules.compras.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.compras.dto.CompraDto;
import com.thiago.gestionbodega.modules.compras.dto.CrearCompraRequest;
import com.thiago.gestionbodega.modules.compras.service.CompraService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Compras", description = "Compras a proveedores con actualizacion automatica de stock")
@RestController
@RequestMapping("/compras")
@RequiredArgsConstructor
public class CompraController {

    private final CompraService service;

    @GetMapping
    public ApiResponse<List<CompraDto>> listar() {
        return ApiResponse.ok(service.listar());
    }

    @GetMapping("/{id}")
    public ApiResponse<CompraDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtenerConDetalle(id));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CompraDto>> crear(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody CrearCompraRequest req
    ) {
        CompraDto creada = service.crear(username, req);
        return ResponseEntity.status(201).body(
                ApiResponse.ok(creada, "Compra registrada. Stock actualizado."));
    }
}
