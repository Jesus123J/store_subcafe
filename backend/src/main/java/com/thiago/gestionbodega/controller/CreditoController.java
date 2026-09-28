package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.dto.CierreMensualResultDto;
import com.thiago.gestionbodega.dto.DeudorMovimientoDto;
import com.thiago.gestionbodega.service.DeudorService;
import com.thiago.gestionbodega.service.CierreCreditosService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "Creditos", description = "Cierre mensual de creditos (deudas) y exportacion a FinantialTracker")
@RestController
@RequestMapping("/creditos")
@RequiredArgsConstructor
public class CreditoController {

    private final DeudorService deudorService;
    private final CierreCreditosService cierreService;

    /** Listado completo de consumos a credito (abiertos y cerrados). */
    @GetMapping
    public ApiResponse<List<DeudorMovimientoDto>> listar() {
        // Dentro de una transaccion (DeudorService) para poder leer cliente/venta/registradoPor (LAZY)
        return ApiResponse.ok(deudorService.listarConsumos());
    }

    /** Creditos pendientes del mes actual, agrupados por trabajador. */
    @GetMapping("/del-mes")
    public ApiResponse<List<Map<String, Object>>> creditosDelMes() {
        return ApiResponse.ok(cierreService.creditosDelMes());
    }

    /** Deuda acumulada (de meses cerrados) por trabajador. Va a planilla. */
    @GetMapping("/deuda-acumulada")
    public ApiResponse<List<Map<String, Object>>> deudaAcumulada() {
        return ApiResponse.ok(cierreService.deudaAcumulada());
    }

    /** Historico de cierres mensuales realizados. */
    @GetMapping("/cierres")
    public ApiResponse<List<Map<String, Object>>> historialCierres() {
        return ApiResponse.ok(cierreService.historialCierres());
    }

    /**
     * Dispara el cierre mensual: suma los creditos del mes por trabajador
     * y los traslada a la deuda acumulada. Solo admin/encargado.
     */
    @PostMapping("/cerrar-mes")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ResponseEntity<ApiResponse<CierreMensualResultDto>> cerrarMes(
            @AuthenticationPrincipal String username,
            @RequestParam(required = false) Integer anio,
            @RequestParam(required = false) Integer mes
    ) {
        CierreMensualResultDto result = cierreService.cerrarMes(username, anio, mes);
        return ResponseEntity.status(201).body(
                ApiResponse.ok(result,
                        "Mes cerrado: " + result.creditosCerrados() + " creditos migrados a deuda; "
                        + result.exportadosFinantial() + " abonos creados en FinantialTracker"
                        + (result.erroresFinantial() > 0 ? " (" + result.erroresFinantial() + " con error)" : "")));
    }
}
