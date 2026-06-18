package com.thiago.gestionbodega.modules.ventas.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.ventas.dto.CrearVentaRequest;
import com.thiago.gestionbodega.modules.ventas.dto.VentaDto;
import com.thiago.gestionbodega.modules.ventas.service.VentaService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Ventas", description = "POS: registrar y consultar ventas")
@RestController
@RequestMapping("/ventas")
@RequiredArgsConstructor
public class VentaController {

    private final VentaService service;

    @GetMapping
    public ApiResponse<List<VentaDto>> listar() {
        return ApiResponse.ok(service.listar());
    }

    @GetMapping("/{id}")
    public ApiResponse<VentaDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<VentaDto>> crear(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody CrearVentaRequest req
    ) {
        VentaDto creada = service.crear(username, req);
        return ResponseEntity.status(201).body(
                ApiResponse.ok(creada, "Venta registrada"));
    }
}
