package com.thiago.gestionbodega.modules.productos.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.productos.dto.ActualizarProductoRequest;
import com.thiago.gestionbodega.modules.productos.dto.CrearProductoRequest;
import com.thiago.gestionbodega.modules.productos.dto.ProductoDto;
import com.thiago.gestionbodega.modules.productos.entity.Producto;
import com.thiago.gestionbodega.modules.productos.entity.ProductoPrecio;
import com.thiago.gestionbodega.modules.productos.repository.ProductoPrecioRepository;
import com.thiago.gestionbodega.modules.productos.repository.ProductoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProductoService {

    private final ProductoRepository productoRepo;
    private final ProductoPrecioRepository precioRepo;

    public List<ProductoDto> listar(boolean soloActivos) {
        List<Producto> productos = soloActivos
                ? productoRepo.findByActivoTrue()
                : productoRepo.findAll();
        return productos.stream()
                .map(p -> ProductoDto.from(p, ultimoPrecio(p.getId())))
                .toList();
    }

    public ProductoDto obtener(UUID id) {
        Producto p = productoRepo.findById(id)
                .orElseThrow(() -> new NotFoundException("Producto no encontrado: " + id));
        return ProductoDto.from(p, ultimoPrecio(p.getId()));
    }

    /**
     * Crea un producto + su primer registro de precio (costo/precioVenta).
     * Si el codigo ya existe, lanza BusinessException.
     */
    @Transactional
    public ProductoDto crear(CrearProductoRequest req) {
        if (req.codigo() != null && !req.codigo().isBlank()) {
            productoRepo.findByCodigo(req.codigo()).ifPresent(p -> {
                throw new BusinessException("Ya existe un producto con codigo: " + req.codigo());
            });
        }

        // Un servicio no tiene stock pero la columna es NOT NULL
        BigDecimal stockInicial = req.esServicio() ? BigDecimal.ZERO : req.stockInicial();
        BigDecimal stockMin = req.esServicio() ? BigDecimal.ZERO : req.stockMinimo();
        // Un servicio nunca es del bazar (no es canjeable por puntos)
        boolean esBazar = !req.esServicio() && req.esBazar();

        Producto p = Producto.builder()
                .codigo(blankToNull(req.codigo()))
                .descripcion(req.descripcion().trim())
                .stock(stockInicial)
                .stockMinimo(stockMin)
                .esServicio(req.esServicio())
                .usaContometro(req.esServicio() && req.usaContometro())
                .esBazar(esBazar)
                .activo(true)
                .build();
        p = productoRepo.save(p);

        // Primer registro de precio
        ProductoPrecio precio = ProductoPrecio.builder()
                .producto(p)
                .costo(req.costo())
                .precioVenta(req.precioVenta())
                .vigenteDesde(OffsetDateTime.now())
                .build();
        precio = precioRepo.save(precio);

        log.info("Producto creado: {} ({})", p.getDescripcion(), p.getId());
        return ProductoDto.from(p, precio);
    }

    /**
     * Actualiza metadatos del producto. Si costo o precioVenta cambian, crea un
     * nuevo registro en producto_precios (historico, no se sobreescribe).
     * El stock NO se modifica aqui — eso solo via compras o ventas.
     */
    @Transactional
    public ProductoDto actualizar(UUID id, ActualizarProductoRequest req) {
        Producto p = productoRepo.findById(id)
                .orElseThrow(() -> new NotFoundException("Producto no encontrado: " + id));

        if (req.codigo() != null && !req.codigo().isBlank()
                && !req.codigo().equalsIgnoreCase(p.getCodigo())) {
            productoRepo.findByCodigo(req.codigo()).ifPresent(otro -> {
                if (!otro.getId().equals(id)) {
                    throw new BusinessException("Otro producto ya usa el codigo: " + req.codigo());
                }
            });
            p.setCodigo(req.codigo());
        }

        p.setDescripcion(req.descripcion().trim());
        if (!p.isEsServicio()) {
            p.setStockMinimo(req.stockMinimo());
            p.setEsBazar(req.esBazar());
        }
        p.setUsaContometro(p.isEsServicio() && req.usaContometro());
        p.setActivo(req.activo());
        p = productoRepo.save(p);

        // Si el costo o precio cambiaron, registramos nueva fila historica
        ProductoPrecio actual = ultimoPrecio(p.getId());
        boolean cambioCosto = actual == null || actual.getCosto().compareTo(req.costo()) != 0;
        boolean cambioPrecio = actual == null || actual.getPrecioVenta().compareTo(req.precioVenta()) != 0;
        if (cambioCosto || cambioPrecio) {
            actual = precioRepo.save(ProductoPrecio.builder()
                    .producto(p)
                    .costo(req.costo())
                    .precioVenta(req.precioVenta())
                    .vigenteDesde(OffsetDateTime.now())
                    .build());
        }

        log.info("Producto actualizado: {} ({})", p.getDescripcion(), p.getId());
        return ProductoDto.from(p, actual);
    }

    /**
     * Borrado logico: activo=false. No eliminamos fisicamente para preservar
     * referencias historicas en ventas y compras.
     */
    @Transactional
    public void desactivar(UUID id) {
        Producto p = productoRepo.findById(id)
                .orElseThrow(() -> new NotFoundException("Producto no encontrado: " + id));
        p.setActivo(false);
        productoRepo.save(p);
        log.info("Producto desactivado: {} ({})", p.getDescripcion(), p.getId());
    }

    private ProductoPrecio ultimoPrecio(UUID productoId) {
        return precioRepo.findFirstByProductoIdOrderByVigenteDesdeDesc(productoId)
                .orElse(null);
    }

    private static String blankToNull(String s) {
        if (s == null) return null;
        s = s.trim();
        return s.isEmpty() ? null : s;
    }
}
