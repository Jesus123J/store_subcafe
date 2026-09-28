package com.thiago.gestionbodega.controller;

import com.thiago.gestionbodega.dto.ApiResponse;
import com.thiago.gestionbodega.service.PuntosService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * API de puntos por consumo. Versión 1: consulta de saldo + reglas + catalogo
 * de productos canjeables. La acumulacion automatica se hace en VentaService
 * cuando se cree (cuando se confirme el modelo con Karina).
 */
@Tag(name = "Puntos")
@RestController
@RequestMapping("/puntos")
@RequiredArgsConstructor
public class PuntosController {

    private final NamedParameterJdbcTemplate jdbc;
    private final PuntosService puntosService;

    public record CanjeableRequest(@NotNull UUID productoId,
                                   @NotNull @DecimalMin("1") BigDecimal puntosRequeridos) {}

    public record ReglaRequest(String descripcion,
                               @NotNull @DecimalMin("0.01") BigDecimal solesPorPunto) {}

    /** Saldo de puntos de todos los clientes (vista agregada). */
    @GetMapping("/saldos")
    public ApiResponse<List<Map<String, Object>>> saldos() {
        var sql = """
                SELECT cliente_id, dni, nombres, apellidos, saldo_puntos
                FROM v_puntos_por_cliente
                WHERE saldo_puntos > 0
                ORDER BY saldo_puntos DESC
                """;
        return ApiResponse.ok(jdbc.queryForList(sql, new MapSqlParameterSource()));
    }

    /** Saldo de puntos de un cliente especifico. */
    @GetMapping("/saldo/{clienteId}")
    public ApiResponse<Map<String, Object>> saldoCliente(@PathVariable UUID clienteId) {
        var sql = """
                SELECT cliente_id, dni, nombres, apellidos, saldo_puntos
                FROM v_puntos_por_cliente
                WHERE cliente_id = :id
                """;
        var rows = jdbc.queryForList(sql,
                new MapSqlParameterSource("id", clienteId.toString()));
        if (rows.isEmpty()) {
            Map<String, Object> empty = new LinkedHashMap<>();
            empty.put("cliente_id", clienteId);
            empty.put("saldo_puntos", BigDecimal.ZERO);
            return ApiResponse.ok(empty);
        }
        return ApiResponse.ok(rows.get(0));
    }

    /** Movimientos de puntos de un cliente. */
    @GetMapping("/movimientos/{clienteId}")
    public ApiResponse<List<Map<String, Object>>> movimientos(@PathVariable UUID clienteId) {
        var sql = """
                SELECT id, tipo, puntos, saldo_despues, observacion, fecha
                FROM movimientos_puntos
                WHERE cliente_id = :id
                ORDER BY fecha DESC
                LIMIT 50
                """;
        return ApiResponse.ok(jdbc.queryForList(sql,
                new MapSqlParameterSource("id", clienteId.toString())));
    }

    /** Catalogo de productos canjeables (con precio vigente). */
    @GetMapping("/canjeables")
    public ApiResponse<List<Map<String, Object>>> canjeables() {
        return ApiResponse.ok(puntosService.canjeables());
    }

    /** Agrega o actualiza un producto del bazar como canjeable. */
    @PostMapping("/canjeables")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> guardarCanjeable(@Valid @RequestBody CanjeableRequest req) {
        return ResponseEntity.status(201).body(
                ApiResponse.ok(puntosService.guardarCanjeable(req.productoId(), req.puntosRequeridos()), "Producto canjeable guardado"));
    }

    @DeleteMapping("/canjeables/{id}")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<Void> quitarCanjeable(@PathVariable UUID id) {
        puntosService.quitarCanjeable(id);
        return ApiResponse.ok(null, "Producto quitado del catalogo canjeable");
    }

    /** Regla de puntos activa. */
    @GetMapping("/regla-activa")
    public ApiResponse<Map<String, Object>> reglaActiva() {
        return ApiResponse.ok(puntosService.reglaActiva());
    }

    /** Cambia la regla (la anterior queda en historico). */
    @PutMapping("/regla-activa")
    @PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
    public ApiResponse<Map<String, Object>> cambiarRegla(@Valid @RequestBody ReglaRequest req) {
        return ApiResponse.ok(puntosService.cambiarRegla(req.descripcion(), req.solesPorPunto()), "Regla de puntos actualizada");
    }
}
