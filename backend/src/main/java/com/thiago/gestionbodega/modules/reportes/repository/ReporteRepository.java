package com.thiago.gestionbodega.modules.reportes.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Queries agregadas para los reportes. Usa JdbcTemplate para tener mas
 * control sobre las queries nativas con PostgreSQL.
 */
@Repository
@RequiredArgsConstructor
public class ReporteRepository {

    private final NamedParameterJdbcTemplate jdbc;

    // ─── Totales globales del periodo ──────────────────────────────────

    public BigDecimal totalVentasEnRango(LocalDate desde, LocalDate hasta) {
        var sql = """
                SELECT COALESCE(SUM(v.total), 0)
                FROM ventas v
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                """;
        return jdbc.queryForObject(sql, rangoParams(desde, hasta), BigDecimal.class);
    }

    public long cantidadTransacciones(LocalDate desde, LocalDate hasta) {
        var sql = """
                SELECT COUNT(*) FROM ventas v
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                """;
        Long count = jdbc.queryForObject(sql, rangoParams(desde, hasta), Long.class);
        return count == null ? 0 : count;
    }

    // ─── Desgloses agrupados ───────────────────────────────────────────

    public Map<String, BigDecimal> totalPorFormaPago(LocalDate desde, LocalDate hasta) {
        var sql = """
                SELECT vp.forma_pago::text AS forma, COALESCE(SUM(vp.monto), 0) AS total
                FROM venta_pagos vp
                JOIN ventas v ON v.id = vp.venta_id
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                GROUP BY vp.forma_pago
                """;
        return jdbc.query(sql, rangoParams(desde, hasta), rs -> {
            var map = new java.util.LinkedHashMap<String, BigDecimal>();
            while (rs.next()) {
                map.put(rs.getString("forma"), rs.getBigDecimal("total"));
            }
            return map;
        });
    }

    public Map<String, BigDecimal> totalPorTurno(LocalDate desde, LocalDate hasta) {
        var sql = """
                SELECT c.turno::text AS turno, COALESCE(SUM(v.total), 0) AS total
                FROM ventas v
                JOIN cajas c ON c.id = v.caja_id
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                GROUP BY c.turno
                """;
        return jdbc.query(sql, rangoParams(desde, hasta), rs -> {
            var map = new java.util.LinkedHashMap<String, BigDecimal>();
            while (rs.next()) {
                map.put(rs.getString("turno"), rs.getBigDecimal("total"));
            }
            return map;
        });
    }

    /** Serie temporal de ventas por dia, util para el grafico de linea. */
    public List<Map<String, Object>> serieDiaria(LocalDate desde, LocalDate hasta) {
        var sql = """
                SELECT DATE(v.fecha) AS dia, COALESCE(SUM(v.total), 0) AS total
                FROM ventas v
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                GROUP BY DATE(v.fecha)
                ORDER BY dia
                """;
        return jdbc.queryForList(sql, rangoParams(desde, hasta));
    }

    // ─── Stock ─────────────────────────────────────────────────────────

    public List<Map<String, Object>> stockActual() {
        // La vista v_stock_actual fue creada en V1__initial_schema.sql
        var sql = """
                SELECT id, codigo, descripcion, stock, stock_minimo,
                       costo, precio_venta, bajo_minimo,
                       (stock * COALESCE(costo, 0)) AS valoracion
                FROM v_stock_actual
                ORDER BY descripcion
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }

    public List<Map<String, Object>> stockBajo() {
        var sql = """
                SELECT id, codigo, descripcion, stock, stock_minimo,
                       costo, precio_venta, bajo_minimo,
                       (stock * COALESCE(costo, 0)) AS valoracion
                FROM v_stock_actual
                WHERE bajo_minimo = true
                ORDER BY descripcion
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }

    // ─── Top productos ─────────────────────────────────────────────────

    public List<Map<String, Object>> topProductos(LocalDate desde, LocalDate hasta, int limit) {
        var sql = """
                SELECT
                    p.id              AS producto_id,
                    p.descripcion     AS descripcion,
                    SUM(vd.cantidad)  AS cantidad_vendida,
                    SUM(vd.subtotal)  AS total_facturado
                FROM venta_detalle vd
                JOIN ventas v   ON v.id = vd.venta_id
                JOIN productos p ON p.id = vd.producto_id
                WHERE v.anulada = false
                  AND v.fecha >= :desde AND v.fecha < :hasta
                GROUP BY p.id, p.descripcion
                ORDER BY cantidad_vendida DESC
                LIMIT :limit
                """;
        var params = rangoParams(desde, hasta).addValue("limit", limit);
        return jdbc.queryForList(sql, params);
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private MapSqlParameterSource rangoParams(LocalDate desde, LocalDate hasta) {
        return new MapSqlParameterSource()
                .addValue("desde", desde)
                .addValue("hasta", hasta.plusDays(1)); // exclusivo
    }

    // Util si en el futuro necesitamos castear UUID en queries:
    @SuppressWarnings("unused")
    private static UUID asUuid(Object o) {
        if (o == null) return null;
        if (o instanceof UUID u) return u;
        return UUID.fromString(o.toString());
    }
}
