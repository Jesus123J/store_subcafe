package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.DeudorMovimientoDto;
import com.thiago.gestionbodega.dto.RegistrarConsumoCreditoRequest;
import com.thiago.gestionbodega.service.CierreCreditosService;
import com.thiago.gestionbodega.service.DeudorService;
import com.thiago.gestionbodega.service.FinantialTrackerService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Deudores: trabajadores del hospital con deuda en la tienda y su reflejo
 * en FinantialTracker (abonos por planilla).
 */
@Tag(name = "Deudores", description = "Deudas de trabajadores por compras a credito y su exportacion a FinantialTracker")
@RestController
@RequestMapping("/deudores")
@RequiredArgsConstructor
public class DeudorController {

    private final DeudorService service;
    private final CierreCreditosService cierreService;
    private final FinantialTrackerService finantial;

    /** Trabajadores con deuda viva (mes en curso + acumulada). */
    @GetMapping
    public ApiResponse<List<Map<String, Object>>> listar(@RequestParam(required = false) String q) {
        return ApiResponse.ok(service.listar(q));
    }

    @GetMapping("/resumen")
    public ApiResponse<Map<String, Object>> resumen() {
        return ApiResponse.ok(service.resumen());
    }

    /** Estado de cuenta de un trabajador: consumos, cierres y abonos en FinantialTracker. */
    @GetMapping("/{clienteId}")
    public ApiResponse<Map<String, Object>> detalle(@PathVariable UUID clienteId) {
        return ApiResponse.ok(service.detalle(clienteId));
    }

    /** Anotar una deuda a mano (consumo que no paso por el POS). */
    @PostMapping("/consumos")
    public ResponseEntity<ApiResponse<DeudorMovimientoDto>> registrarConsumo(
            @AuthenticationPrincipal String username,
            @Valid @RequestBody RegistrarConsumoCreditoRequest req) {
        return ResponseEntity.status(201).body(
                ApiResponse.ok(service.registrarConsumo(username, req), "Deuda registrada"));
    }

    @DeleteMapping("/consumos/{creditoId}")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<Void> eliminarConsumo(@PathVariable UUID creditoId) {
        service.eliminarConsumo(creditoId);
        return ApiResponse.ok(null, "Consumo eliminado");
    }

    // ─── FinantialTracker ───

    /** Detalle de un cierre: que trabajador, cuanto y con que abono quedo en FinantialTracker. */
    @GetMapping("/cierres/{cierreId}")
    public ApiResponse<List<Map<String, Object>>> detalleCierre(@PathVariable String cierreId) {
        return ApiResponse.ok(cierreService.detalleCierre(cierreId));
    }

    /** Reintenta exportar a FinantialTracker las deudas del cierre que fallaron. */
    @PostMapping("/cierres/{cierreId}/exportar-finantial")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<Map<String, Object>> exportarCierre(@PathVariable String cierreId) {
        int[] r = cierreService.exportarCierre(cierreId);
        return ApiResponse.ok(Map.of("exportados", r[0], "errores", r[1]),
                "Exportacion: " + r[0] + " abonos creados, " + r[1] + " con error");
    }

    /** Abonos que la tienda ha creado en FinantialTracker y su estado alla (Pendiente / Pagado). */
    @GetMapping("/finantial/abonos")
    public ApiResponse<List<Map<String, Object>>> abonosFinantial(@RequestParam(defaultValue = "100") int limite) {
        return ApiResponse.ok(finantial.abonosDeLaTienda(limite));
    }

    /** Conceptos de FinantialTracker (para configurar finantial.concepto_abono_id). */
    @GetMapping("/finantial/conceptos")
    public ApiResponse<List<Map<String, Object>>> conceptosFinantial() {
        return ApiResponse.ok(finantial.conceptos());
    }
}
