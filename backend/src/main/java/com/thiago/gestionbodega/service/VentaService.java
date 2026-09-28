package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.*;
import com.thiago.gestionbodega.entity.*;
import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import com.thiago.gestionbodega.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Ventas del POS.
 *
 * Regla de union con FinantialTracker:
 *  - Pago CREDITO  -> obligatorio un trabajador (cliente con es_trabajador).
 *                    Se registra la deuda en creditos_trabajadores; al cerrar el
 *                    mes se exporta a FinantialTracker como abono.
 *  - Cliente externo -> no puede usar CREDITO; solo se registra la venta.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VentaService {

    private final VentaRepository ventaRepo;
    private final CajaRepository cajaRepo;
    private final UsuarioRepository usuarioRepo;
    private final ProductoRepository productoRepo;
    private final ProductoPrecioRepository precioRepo;
    private final ClienteRepository clienteRepo;
    private final CreditoTrabajadorRepository creditoRepo;

    public List<VentaDto> listar(UUID cajaId) {
        List<Venta> ventas = cajaId != null
                ? ventaRepo.findByCajaIdOrderByFechaDesc(cajaId)
                : ventaRepo.findAllByOrderByFechaDesc();
        return ventas.stream().map(VentaDto::from).toList();
    }

    public VentaDto obtener(UUID id) {
        return VentaDto.from(getOrThrow(id));
    }

    @Transactional
    public VentaDto crear(String username, CrearVentaRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));
        Caja caja = cajaRepo.findFirstByUsuarioIdAndEstado(user.getId(), EstadoCaja.ABIERTA)
                .orElseThrow(() -> new BusinessException("No tienes una caja abierta. Abre caja antes de vender."));

        Venta venta = Venta.builder()
                .caja(caja)
                .usuario(user)
                .fecha(OffsetDateTime.now())
                .total(BigDecimal.ZERO)
                .anulada(false)
                .observacion(req.observacion())
                .build();

        // 1) Items: precio vigente, subtotal, descuento de stock
        BigDecimal total = BigDecimal.ZERO;
        for (VentaItemRequest it : req.items()) {
            Producto p = productoRepo.findById(it.productoId())
                    .orElseThrow(() -> new NotFoundException("Producto no encontrado: " + it.productoId()));
            if (!p.isActivo()) throw new BusinessException("Producto inactivo: " + p.getDescripcion());

            BigDecimal precio = it.precioUnitario() != null ? it.precioUnitario()
                    : precioRepo.findFirstByProductoIdOrderByVigenteDesdeDesc(p.getId())
                        .map(ProductoPrecio::getPrecioVenta)
                        .orElseThrow(() -> new BusinessException("El producto " + p.getDescripcion() + " no tiene precio"));
            BigDecimal subtotal = precio.multiply(it.cantidad());
            total = total.add(subtotal);

            if (!p.isEsServicio()) {
                if (p.getStock().compareTo(it.cantidad()) < 0) {
                    throw new BusinessException("Stock insuficiente de " + p.getDescripcion()
                            + " (hay " + p.getStock() + ", se pide " + it.cantidad() + ")");
                }
                p.setStock(p.getStock().subtract(it.cantidad()));
                productoRepo.save(p);
            }
            venta.agregarItem(VentaDetalle.builder()
                    .producto(p).cantidad(it.cantidad()).precioUnitario(precio).subtotal(subtotal).build());
        }
        total = total.setScale(2, java.math.RoundingMode.HALF_UP);
        venta.setTotal(total);

        // 2) Pagos: suma == total; CREDITO solo a trabajadores
        BigDecimal sumaPagos = BigDecimal.ZERO;
        for (VentaPagoDto pg : req.pagos()) {
            sumaPagos = sumaPagos.add(pg.monto());
            Cliente trabajador = null;
            if (pg.formaPago() == FormaPago.CREDITO) {
                if (pg.clienteId() == null) {
                    throw new BusinessException("El pago a CREDITO requiere elegir al trabajador que asume la deuda. "
                            + "Si es un cliente externo, registre la venta con otra forma de pago.");
                }
                trabajador = clienteRepo.findById(pg.clienteId())
                        .orElseThrow(() -> new NotFoundException("Trabajador no encontrado: " + pg.clienteId()));
                if (!trabajador.isEsTrabajador() || !trabajador.isActivo()) {
                    throw new BusinessException(trabajador.getNombreCompleto()
                            + " no es un trabajador activo: no puede comprar a credito.");
                }
            }
            venta.agregarPago(VentaPago.builder()
                    .formaPago(pg.formaPago())
                    .monto(pg.monto())
                    .codigoOperacion(pg.codigoOperacion())
                    .clienteCredito(trabajador)
                    .build());
        }
        if (sumaPagos.setScale(2, java.math.RoundingMode.HALF_UP).subtract(total).abs().compareTo(new BigDecimal("0.01")) > 0) {
            throw new BusinessException("La suma de pagos (" + sumaPagos + ") no coincide con el total (" + total + ")");
        }

        venta = ventaRepo.save(venta);

        // 3) Deuda del trabajador por cada pago a credito
        String resumen = venta.getItems().stream()
                .map(i -> i.getCantidad().stripTrailingZeros().toPlainString() + "x " + i.getProducto().getDescripcion())
                .collect(Collectors.joining(", "));
        if (resumen.length() > 200) resumen = resumen.substring(0, 197) + "...";
        for (VentaPago pg : venta.getPagos()) {
            if (pg.getClienteCredito() != null) {
                creditoRepo.save(CreditoTrabajador.builder()
                        .cliente(pg.getClienteCredito())
                        .venta(venta)
                        .monto(pg.getMonto())
                        .descripcion(resumen)
                        .registradoPor(user)
                        .fecha(venta.getFecha())
                        .cerrado(false)
                        .build());
                log.info("Deuda registrada: {} debe S/. {} por venta {}",
                        pg.getClienteCredito().getNombreCompleto(), pg.getMonto(), venta.getId());
            }
        }
        return VentaDto.from(venta);
    }

    @Transactional
    public VentaDto anular(UUID id, String username, AnularVentaRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));
        Venta v = getOrThrow(id);
        if (v.isAnulada()) throw new BusinessException("La venta ya esta anulada");

        List<CreditoTrabajador> creditos = creditoRepo.findByVentaId(id);
        if (creditos.stream().anyMatch(CreditoTrabajador::isCerrado)) {
            throw new BusinessException("No se puede anular: la deuda de esta venta ya fue incluida en un cierre mensual "
                    + "(y enviada a FinantialTracker). Corrijala alla o registre un ajuste.");
        }
        // devolver stock
        for (VentaDetalle d : v.getItems()) {
            Producto p = d.getProducto();
            if (!p.isEsServicio()) {
                p.setStock(p.getStock().add(d.getCantidad()));
                productoRepo.save(p);
            }
        }
        creditoRepo.deleteAll(creditos);
        v.setAnulada(true);
        v.setAnuladaPor(user);
        v.setMotivoAnulacion(req.motivo());
        return VentaDto.from(ventaRepo.save(v));
    }

    private Venta getOrThrow(UUID id) {
        return ventaRepo.findById(id).orElseThrow(() -> new NotFoundException("Venta no encontrada: " + id));
    }
}
