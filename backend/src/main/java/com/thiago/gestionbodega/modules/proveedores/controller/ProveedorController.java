package com.thiago.gestionbodega.modules.proveedores.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.proveedores.dto.ActualizarProveedorRequest;
import com.thiago.gestionbodega.modules.proveedores.dto.CrearProveedorRequest;
import com.thiago.gestionbodega.modules.proveedores.dto.ProveedorDto;
import com.thiago.gestionbodega.modules.proveedores.service.ProveedorService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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

    @GetMapping("/{id}")
    public ApiResponse<ProveedorDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<ProveedorDto>> crear(
            @Valid @RequestBody CrearProveedorRequest req
    ) {
        ProveedorDto creado = service.crear(req);
        return ResponseEntity.status(201).body(
                ApiResponse.ok(creado, "Proveedor registrado"));
    }

    @PutMapping("/{id}")
    public ApiResponse<ProveedorDto> actualizar(
            @PathVariable UUID id,
            @Valid @RequestBody ActualizarProveedorRequest req
    ) {
        return ApiResponse.ok(service.actualizar(id, req), "Proveedor actualizado");
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> desactivar(@PathVariable UUID id) {
        service.desactivar(id);
        return ResponseEntity.noContent().build();
    }
}
