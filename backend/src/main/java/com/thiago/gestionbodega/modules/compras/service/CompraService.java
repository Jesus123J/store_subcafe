package com.thiago.gestionbodega.modules.compras.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.compras.dto.*;
import com.thiago.gestionbodega.modules.compras.entity.Compra;
import com.thiago.gestionbodega.modules.compras.entity.CompraDetalle;
import com.thiago.gestionbodega.modules.compras.repository.CompraDetalleRepository;
import com.thiago.gestionbodega.modules.compras.repository.CompraRepository;
import com.thiago.gestionbodega.modules.productos.entity.Producto;
import com.thiago.gestionbodega.modules.productos.entity.ProductoPrecio;
import com.thiago.gestionbodega.modules.productos.repository.ProductoPrecioRepository;
import com.thiago.gestionbodega.modules.productos.repository.ProductoRepository;
import com.thiago.gestionbodega.modules.proveedores.entity.Proveedor;
import com.thiago.gestionbodega.modules.proveedores.repository.ProveedorRepository;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CompraService {

    private final CompraRepository compraRepo;
    private final CompraDetalleRepository detalleRepo;
    private final ProveedorRepository proveedorRepo;
    private final ProductoRepository productoRepo;
    private final ProductoPrecioRepository precioRepo;
    private final UsuarioRepository usuarioRepo;

    public List<CompraDto> listar() {
        return compraRepo.findAll().stream()
                .sorted((a, b) -> b.getFecha().compareTo(a.getFecha()))
                .map(CompraDto::sinDetalle)
                .toList();
    }

    public CompraDto obtenerConDetalle(UUID id) {
        Compra c = compraRepo.findById(id)
                .orElseThrow(() -> new NotFoundException("Compra no encontrada: " + id));
        List<CompraDetalleDto> items = detalleRepo
                .findByCompraIdOrderByIdAsc(id)
                .stream()
                .map(CompraDetalleDto::from)
                .toList();
        return CompraDto.conDetalle(c, items);
    }

    /**
     * Crea una compra con su detalle aplicando logica de negocio:
     * 1. Inserta la compra (sin total aun)
     * 2. Por cada item:
     *    - Inserta compra_detalle (subtotal = cantidad * costoUnitario)
     *    - Aumenta stock del producto
     *    - Crea nuevo producto_precio con el costo y el precio_venta actual del producto
     * 3. Calcula y guarda el total de la compra
     *
     * Todo en una sola transaccion: si algo falla, rollback completo.
     */
    @Transactional
    public CompraDto crear(String username, CrearCompraRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));

        Proveedor proveedor = proveedorRepo.findById(req.proveedorId())
                .orElseThrow(() -> new NotFoundException(
                        "Proveedor no encontrado: " + req.proveedorId()));

        if (!proveedor.isActivo()) {
            throw new BusinessException("El proveedor esta inactivo");
        }

        // 1) Crear compra con total temporal en 0 (se actualiza al final)
        Compra compra = Compra.builder()
                .proveedor(proveedor)
                .usuario(user)
                .fecha(OffsetDateTime.now())
                .total(BigDecimal.ZERO)
                .nroDocumento(req.nroDocumento())
                .observaciones(req.observaciones())
                .creadoEn(OffsetDateTime.now())
                .build();
        compra = compraRepo.save(compra);

        // 2) Procesar items
        BigDecimal total = BigDecimal.ZERO;
        List<CompraDetalleDto> itemsDto = new ArrayList<>();
        for (CompraDetalleRequest it : req.items()) {
            Producto p = productoRepo.findById(it.productoId())
                    .orElseThrow(() -> new NotFoundException(
                            "Producto no encontrado: " + it.productoId()));
            if (!p.isActivo()) {
                throw new BusinessException("Producto inactivo: " + p.getDescripcion());
            }

            BigDecimal subtotal = it.cantidad().multiply(it.costoUnitario());
            total = total.add(subtotal);

            CompraDetalle d = CompraDetalle.builder()
                    .compra(compra)
                    .producto(p)
                    .cantidad(it.cantidad())
                    .costoUnitario(it.costoUnitario())
                    .subtotal(subtotal)
                    .build();
            d = detalleRepo.save(d);
            itemsDto.add(CompraDetalleDto.from(d));

            // 2a) Aumentar stock (excepto si es servicio)
            if (!p.isEsServicio()) {
                p.setStock(p.getStock().add(it.cantidad()));
                productoRepo.save(p);
            }

            // 2b) Registrar nuevo precio historico con el nuevo costo
            // Mantenemos el precio de venta del ultimo registro (no cambia automaticamente)
            BigDecimal precioVentaActual = precioRepo
                    .findFirstByProductoIdOrderByVigenteDesdeDesc(p.getId())
                    .map(ProductoPrecio::getPrecioVenta)
                    .orElse(it.costoUnitario());

            precioRepo.save(ProductoPrecio.builder()
                    .producto(p)
                    .costo(it.costoUnitario())
                    .precioVenta(precioVentaActual)
                    .vigenteDesde(OffsetDateTime.now())
                    .build());
        }

        // 3) Actualizar total final de la compra
        compra.setTotal(total);
        compra = compraRepo.save(compra);

        log.info("Compra creada: {} items, total {} por usuario {}",
                req.items().size(), total, username);

        return CompraDto.conDetalle(compra, itemsDto);
    }
}
