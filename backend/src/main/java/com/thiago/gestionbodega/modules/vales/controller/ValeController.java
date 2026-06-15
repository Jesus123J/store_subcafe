package com.thiago.gestionbodega.modules.vales.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.vales.dto.EmitirValeRequest;
import com.thiago.gestionbodega.modules.vales.dto.ValeDto;
import com.thiago.gestionbodega.modules.vales.entity.EstadoVale;
import com.thiago.gestionbodega.modules.vales.service.ValeService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Vales")
@RestController
@RequestMapping("/vales")
@RequiredArgsConstructor
public class ValeController {

    private final ValeService service;

    @GetMapping
    public ApiResponse<List<ValeDto>> listar(@RequestParam(required = false) EstadoVale estado) {
        return ApiResponse.ok(service.listar(estado));
    }

    @PostMapping("/emitir")
    public ResponseEntity<ApiResponse<ValeDto>> emitir(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody EmitirValeRequest req
    ) {
        ValeDto v = service.emitir(username, req);
        return ResponseEntity.status(201).body(ApiResponse.ok(v, "Vale emitido: " + v.codigo()));
    }

    @PostMapping("/{id}/anular")
    public ApiResponse<ValeDto> anular(@PathVariable UUID id) {
        return ApiResponse.ok(service.anular(id), "Vale anulado");
    }
}
