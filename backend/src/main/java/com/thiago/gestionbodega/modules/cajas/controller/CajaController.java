package com.thiago.gestionbodega.modules.cajas.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.cajas.dto.*;
import com.thiago.gestionbodega.modules.cajas.service.CajaService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Cajas", description = "Apertura, cierre, cuadre y avances de caja por turno")
@RestController
@RequestMapping("/cajas")
@RequiredArgsConstructor
public class CajaController {

    private final CajaService service;

    @GetMapping
    public ApiResponse<List<CajaDto>> listar() {
        return ApiResponse.ok(service.listar());
    }

    /** Caja abierta del usuario en sesion (con totales por forma de pago + avances). */
    @GetMapping("/abierta")
    public ApiResponse<CajaDetalleDto> obtenerAbierta(@AuthenticationPrincipal String username) {
        return ApiResponse.ok(service.obtenerCajaAbiertaDelUsuario(username));
    }

    @PostMapping("/abrir")
    public ResponseEntity<ApiResponse<CajaDto>> abrir(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody AbrirCajaRequest req
    ) {
        CajaDto caja = service.abrirCaja(username, req);
        return ResponseEntity.status(201).body(ApiResponse.ok(caja, "Caja abierta"));
    }

    @PostMapping("/{id}/cerrar")
    public ApiResponse<CajaDto> cerrar(
            @PathVariable UUID id,
            @AuthenticationPrincipal String username,
            @Valid @RequestBody CerrarCajaRequest req
    ) {
        return ApiResponse.ok(service.cerrarCaja(id, username, req), "Caja cerrada");
    }

    @PostMapping("/{id}/avances")
    public ResponseEntity<ApiResponse<AvanceDto>> registrarAvance(
            @PathVariable UUID id,
            @AuthenticationPrincipal String username,
            @Valid @RequestBody AvanceRequest req
    ) {
        AvanceDto avance = service.registrarAvance(id, username, req);
        return ResponseEntity.status(201).body(ApiResponse.ok(avance, "Avance registrado"));
    }
}
