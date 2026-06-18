package com.thiago.gestionbodega.modules.creditos.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.creditos.dto.CierreMensualResultDto;
import com.thiago.gestionbodega.modules.creditos.entity.CreditoTrabajador;
import com.thiago.gestionbodega.modules.creditos.repository.CreditoTrabajadorRepository;
import com.thiago.gestionbodega.modules.creditos.service.CierreCreditosService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "Creditos", description = "Credito a trabajadores con ciclo mensual de cierre")
@RestController
@RequestMapping("/creditos")
@RequiredArgsConstructor
public class CreditoController {

    private final CreditoTrabajadorRepository repository;
    private final CierreCreditosService cierreService;

    /** Listado completo (legacy + nuevo). */
    @GetMapping
    public ApiResponse<List<CreditoTrabajador>> listar() {
        return ApiResponse.ok(repository.findAll());
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
                        "Mes cerrado: " + result.creditosCerrados() + " creditos migrados a deuda"));
    }
}
