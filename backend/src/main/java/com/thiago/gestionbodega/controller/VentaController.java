package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.AnularVentaRequest;
import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.CrearVentaRequest;
import com.thiago.gestionbodega.dto.VentaDto;
import com.thiago.gestionbodega.service.VentaService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Ventas", description = "POS: venta con pago mixto. CREDITO solo a trabajadores (genera deuda)")
@RestController
@RequestMapping("/ventas")
@RequiredArgsConstructor
public class VentaController {

    private final VentaService service;

    @GetMapping
    public ApiResponse<List<VentaDto>> listar(@RequestParam(required = false) UUID cajaId) {
        return ApiResponse.ok(service.listar(cajaId));
    }

    @GetMapping("/{id}")
    public ApiResponse<VentaDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<VentaDto>> crear(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody CrearVentaRequest req) {
        VentaDto v = service.crear(username, req);
        String msg = v.tieneCredito() ? "Venta registrada. Deuda anotada al trabajador." : "Venta registrada";
        return ResponseEntity.status(201).body(ApiResponse.ok(v, msg));
    }

    @PostMapping("/{id}/anular")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<VentaDto> anular(
            @PathVariable UUID id,
            @AuthenticationPrincipal String username,
            @Valid @RequestBody AnularVentaRequest req) {
        return ApiResponse.ok(service.anular(id, username, req), "Venta anulada");
    }
}
