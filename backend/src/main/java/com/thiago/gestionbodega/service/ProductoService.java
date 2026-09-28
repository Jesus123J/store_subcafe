package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.GuardarProductoRequest;
import com.thiago.gestionbodega.dto.ProductoDto;
import com.thiago.gestionbodega.entity.Producto;
import com.thiago.gestionbodega.entity.ProductoPrecio;
import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import com.thiago.gestionbodega.repository.ProductoPrecioRepository;
import com.thiago.gestionbodega.repository.ProductoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProductoService {

    private final NamedParameterJdbcTemplate jdbc;
    private final ProductoRepository productoRepo;
    private final ProductoPrecioRepository precioRepo;

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

    public ProductoDto obtener(UUID id) {
        return listarActivos().stream().filter(p -> p.id().equals(id)).findFirst()
                .orElseGet(() -> {
                    Producto p = productoRepo.findById(id)
                            .orElseThrow(() -> new NotFoundException("Producto no encontrado"));
                    return toDto(p);
                });
    }

    @Transactional
    public ProductoDto crear(GuardarProductoRequest req) {
        String codigo = blankToNull(req.codigo());
        if (codigo != null && productoRepo.findByCodigo(codigo).isPresent()) {
            throw new BusinessException("Ya existe un producto con codigo " + codigo);
        }
        Producto p = Producto.builder()
                .codigo(codigo)
                .descripcion(req.descripcion().trim())
                .stock(req.esServicio() ? BigDecimal.ZERO : nz(req.stock()))
                .stockMinimo(req.esServicio() ? BigDecimal.ZERO : nz(req.stockMinimo()))
                .esServicio(req.esServicio())
                .usaContometro(req.esServicio() && req.usaContometro())
                .esBazar(!req.esServicio() && req.esBazar())
                .activo(req.activo() == null || req.activo())
                .build();
        p = productoRepo.save(p);
        precioRepo.save(ProductoPrecio.builder()
                .producto(p).costo(nz(req.costo())).precioVenta(req.precioVenta())
                .vigenteDesde(OffsetDateTime.now()).build());
        return toDto(p);
    }

    /** Edita datos maestros; si cambia costo o precio registra un nuevo precio vigente. El stock no se toca aqui. */
    @Transactional
    public ProductoDto actualizar(UUID id, GuardarProductoRequest req) {
        Producto p = productoRepo.findById(id).orElseThrow(() -> new NotFoundException("Producto no encontrado"));
        String codigo = blankToNull(req.codigo());
        if (codigo != null) {
            productoRepo.findByCodigo(codigo).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
                throw new BusinessException("Ya existe otro producto con codigo " + codigo);
            });
        }
        p.setCodigo(codigo);
        p.setDescripcion(req.descripcion().trim());
        p.setStockMinimo(req.esServicio() ? BigDecimal.ZERO : nz(req.stockMinimo()));
        p.setEsServicio(req.esServicio());
        p.setUsaContometro(req.esServicio() && req.usaContometro());
        p.setEsBazar(!req.esServicio() && req.esBazar());
        if (req.activo() != null) p.setActivo(req.activo());
        p = productoRepo.save(p);

        ProductoPrecio vigente = precioRepo.findFirstByProductoIdOrderByVigenteDesdeDesc(id).orElse(null);
        boolean cambioPrecio = vigente == null
                || vigente.getPrecioVenta().compareTo(req.precioVenta()) != 0
                || vigente.getCosto().compareTo(nz(req.costo())) != 0;
        if (cambioPrecio) {
            precioRepo.save(ProductoPrecio.builder()
                    .producto(p).costo(nz(req.costo())).precioVenta(req.precioVenta())
                    .vigenteDesde(OffsetDateTime.now()).build());
        }
        return toDto(p);
    }

    private ProductoDto toDto(Producto p) {
        ProductoPrecio pr = precioRepo.findFirstByProductoIdOrderByVigenteDesdeDesc(p.getId()).orElse(null);
        return ProductoDto.builder()
                .id(p.getId()).codigo(p.getCodigo()).descripcion(p.getDescripcion())
                .stock(p.getStock()).stockMinimo(p.getStockMinimo())
                .esServicio(p.isEsServicio()).usaContometro(p.isUsaContometro()).esBazar(p.isEsBazar())
                .activo(p.isActivo())
                .precioVenta(pr == null ? BigDecimal.ZERO : pr.getPrecioVenta())
                .costo(pr == null ? BigDecimal.ZERO : pr.getCosto())
                .bajoMinimo(!p.isEsServicio() && p.getStock().compareTo(p.getStockMinimo()) <= 0)
                .build();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
