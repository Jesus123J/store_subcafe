package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Puntos por consumo: regla activa, catalogo canjeable y acumulacion al vender.
 * Los saldos salen de la vista v_puntos_por_cliente (suma de movimientos).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PuntosService {

    private final NamedParameterJdbcTemplate jdbc;

    // ─── Regla ───

    public Map<String, Object> reglaActiva() {
        var rows = jdbc.queryForList("""
                SELECT id, descripcion, soles_por_punto, vigente_desde
                FROM reglas_puntos WHERE activa = TRUE
                ORDER BY vigente_desde DESC LIMIT 1
                """, new MapSqlParameterSource());
        return rows.isEmpty() ? null : rows.get(0);
    }

    /** Cierra la regla vigente y activa una nueva (queda historico). */
    @Transactional
    public Map<String, Object> cambiarRegla(String descripcion, BigDecimal solesPorPunto) {
        if (solesPorPunto == null || solesPorPunto.signum() <= 0) {
            throw new BusinessException("Los soles por punto deben ser mayores a 0");
        }
        jdbc.update("UPDATE reglas_puntos SET activa = FALSE, vigente_hasta = NOW(6) WHERE activa = TRUE",
                new MapSqlParameterSource());
        jdbc.update("""
                INSERT INTO reglas_puntos (id, descripcion, soles_por_punto, activa)
                VALUES (:id, :d, :s, TRUE)
                """, new MapSqlParameterSource()
                        .addValue("id", UUID.randomUUID().toString())
                        .addValue("d", (descripcion == null || descripcion.isBlank())
                                ? "1 punto por cada S/. " + solesPorPunto.setScale(2, RoundingMode.HALF_UP) : descripcion.trim())
                        .addValue("s", solesPorPunto));
        return reglaActiva();
    }

    // ─── Canjeables ───

    public List<Map<String, Object>> canjeables() {
        return jdbc.queryForList("""
                SELECT pc.id, pc.producto_id, p.codigo, p.descripcion, pc.puntos_requeridos, pc.activo,
                       (SELECT pp.precio_venta FROM producto_precios pp WHERE pp.producto_id = p.id
                         ORDER BY pp.vigente_desde DESC LIMIT 1) AS precio_venta
                FROM productos_canjeables pc
                JOIN productos p ON p.id = pc.producto_id
                WHERE pc.activo = TRUE
                ORDER BY pc.puntos_requeridos ASC
                """, new MapSqlParameterSource());
    }

    /** Agrega (o reactiva/actualiza) un producto del bazar al catalogo canjeable. */
    @Transactional
    public Map<String, Object> guardarCanjeable(UUID productoId, BigDecimal puntos) {
        if (puntos == null || puntos.signum() <= 0) {
            throw new BusinessException("Los puntos requeridos deben ser mayores a 0");
        }
        var prod = jdbc.queryForList("SELECT descripcion, es_bazar, activo FROM productos WHERE id = :id",
                new MapSqlParameterSource("id", productoId.toString()));
        if (prod.isEmpty()) throw new NotFoundException("Producto no encontrado");
        if (!truthy(prod.get(0).get("es_bazar"))) {
            throw new BusinessException("Solo los productos marcados como 'del bazar' se pueden canjear por puntos: "
                    + prod.get(0).get("descripcion"));
        }
        int n = jdbc.update("""
                UPDATE productos_canjeables SET puntos_requeridos = :p, activo = TRUE WHERE producto_id = :id
                """, new MapSqlParameterSource().addValue("p", puntos).addValue("id", productoId.toString()));
        if (n == 0) {
            jdbc.update("""
                    INSERT INTO productos_canjeables (id, producto_id, puntos_requeridos, activo)
                    VALUES (:cid, :id, :p, TRUE)
                    """, new MapSqlParameterSource()
                            .addValue("cid", UUID.randomUUID().toString())
                            .addValue("id", productoId.toString()).addValue("p", puntos));
        }
        return canjeables().stream()
                .filter(c -> productoId.toString().equals(String.valueOf(c.get("producto_id"))))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void quitarCanjeable(UUID canjeableId) {
        int n = jdbc.update("UPDATE productos_canjeables SET activo = FALSE WHERE id = :id",
                new MapSqlParameterSource("id", canjeableId.toString()));
        if (n == 0) throw new NotFoundException("Producto canjeable no encontrado");
    }

    // ─── Acumulacion ───

    /**
     * Acumula puntos por una venta segun la regla activa (piso de total / soles_por_punto).
     * Idempotente por venta (indice unico venta_id + tipo). Devuelve los puntos otorgados.
     */
    @Transactional
    public int acumularPorVenta(UUID clienteId, UUID ventaId, BigDecimal totalVenta) {
        Map<String, Object> regla = reglaActiva();
        if (regla == null || clienteId == null || totalVenta == null) return 0;
        BigDecimal soles = (BigDecimal) regla.get("soles_por_punto");
        int puntos = totalVenta.divide(soles, 0, RoundingMode.FLOOR).intValue();
        if (puntos <= 0) return 0;
        BigDecimal saldo = saldo(clienteId).add(BigDecimal.valueOf(puntos));
        try {
            jdbc.update("""
                    INSERT INTO movimientos_puntos (id, cliente_id, tipo, puntos, saldo_despues, venta_id, observacion)
                    VALUES (:id, :cid, 'ACUMULACION', :p, :s, :vid, :obs)
                    """, new MapSqlParameterSource()
                            .addValue("id", UUID.randomUUID().toString())
                            .addValue("cid", clienteId.toString())
                            .addValue("p", puntos).addValue("s", saldo)
                            .addValue("vid", ventaId.toString())
                            .addValue("obs", "Compra S/. " + totalVenta.setScale(2, RoundingMode.HALF_UP)
                                    + " (1 pto x S/. " + soles.stripTrailingZeros().toPlainString() + ")"));
        } catch (org.springframework.dao.DuplicateKeyException e) {
            return 0; // ya acumulado para esta venta
        }
        log.info("Puntos: +{} para cliente {} por venta {}", puntos, clienteId, ventaId);
        return puntos;
    }

    public BigDecimal saldo(UUID clienteId) {
        BigDecimal s = jdbc.queryForObject(
                "SELECT COALESCE(SUM(puntos), 0) FROM movimientos_puntos WHERE cliente_id = :id",
                new MapSqlParameterSource("id", clienteId.toString()), BigDecimal.class);
        return s == null ? BigDecimal.ZERO : s;
    }

    private static boolean truthy(Object o) {
        if (o instanceof Boolean b) return b;
        if (o instanceof Number n) return n.intValue() != 0;
        return false;
    }
}
