package com.thiago.gestionbodega.modules.puntos.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
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
                new MapSqlParameterSource("id", clienteId));
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
                SELECT id, tipo::text AS tipo, puntos, saldo_despues, observacion, fecha
                FROM movimientos_puntos
                WHERE cliente_id = :id
                ORDER BY fecha DESC
                LIMIT 50
                """;
        return ApiResponse.ok(jdbc.queryForList(sql,
                new MapSqlParameterSource("id", clienteId)));
    }

    /** Catalogo de productos canjeables. */
    @GetMapping("/canjeables")
    public ApiResponse<List<Map<String, Object>>> canjeables() {
        var sql = """
                SELECT pc.id, pc.producto_id, p.descripcion, pc.puntos_requeridos, pc.activo
                FROM productos_canjeables pc
                JOIN productos p ON p.id = pc.producto_id
                WHERE pc.activo = true
                ORDER BY pc.puntos_requeridos ASC
                """;
        return ApiResponse.ok(jdbc.queryForList(sql, new MapSqlParameterSource()));
    }

    /** Regla de puntos activa. */
    @GetMapping("/regla-activa")
    public ApiResponse<Map<String, Object>> reglaActiva() {
        var sql = """
                SELECT id, descripcion, soles_por_punto, vigente_desde
                FROM reglas_puntos
                WHERE activa = true
                ORDER BY vigente_desde DESC
                LIMIT 1
                """;
        var rows = jdbc.queryForList(sql, new MapSqlParameterSource());
        return ApiResponse.ok(rows.isEmpty() ? null : rows.get(0));
    }
}
