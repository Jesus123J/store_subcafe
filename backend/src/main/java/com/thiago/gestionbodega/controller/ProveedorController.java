package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.GuardarProveedorRequest;
import com.thiago.gestionbodega.dto.ProveedorDto;
import com.thiago.gestionbodega.service.ProveedorService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Proveedores")
@RestController
@RequestMapping("/proveedores")
@RequiredArgsConstructor
public class ProveedorController {

    private final ProveedorService service;

    @GetMapping
    public ApiResponse<List<ProveedorDto>> listar() {
        return ApiResponse.ok(service.listar());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ResponseEntity<ApiResponse<ProveedorDto>> crear(@Valid @RequestBody GuardarProveedorRequest req) {
        return ResponseEntity.status(201).body(ApiResponse.ok(service.crear(req), "Proveedor creado"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<ProveedorDto> actualizar(@PathVariable UUID id, @Valid @RequestBody GuardarProveedorRequest req) {
        return ApiResponse.ok(service.actualizar(id, req), "Proveedor actualizado");
    }
}
