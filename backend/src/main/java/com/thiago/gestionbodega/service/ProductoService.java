package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.ProductoDto;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProductoService {

    private final NamedParameterJdbcTemplate jdbc;

    /** Productos activos con su precio vigente (vista v_stock_actual). */
    public List<ProductoDto> listarActivos() {
        return jdbc.query("""
                SELECT id, codigo, descripcion, stock, stock_minimo, es_servicio, usa_contometro,
                       es_bazar, costo, precio_venta, bajo_minimo
                FROM v_stock_actual
                ORDER BY descripcion
                """, new MapSqlParameterSource(), (rs, i) -> ProductoDto.builder()
                .id(UUID.fromString(rs.getString("id")))
                .codigo(rs.getString("codigo"))
                .descripcion(rs.getString("descripcion"))
                .stock(rs.getBigDecimal("stock"))
                .stockMinimo(rs.getBigDecimal("stock_minimo"))
                .esServicio(rs.getBoolean("es_servicio"))
                .usaContometro(rs.getBoolean("usa_contometro"))
                .esBazar(rs.getBoolean("es_bazar"))
                .activo(true)
                .precioVenta(nz(rs.getBigDecimal("precio_venta")))
                .costo(nz(rs.getBigDecimal("costo")))
                .bajoMinimo(rs.getInt("bajo_minimo") != 0)
                .build());
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
