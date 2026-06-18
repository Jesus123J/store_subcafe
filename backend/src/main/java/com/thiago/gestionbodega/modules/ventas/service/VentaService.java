package com.thiago.gestionbodega.modules.ventas.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.entity.EstadoCaja;
import com.thiago.gestionbodega.modules.cajas.repository.CajaRepository;
import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import com.thiago.gestionbodega.modules.clientes.repository.ClienteRepository;
import com.thiago.gestionbodega.modules.creditos.entity.CreditoTrabajador;
import com.thiago.gestionbodega.modules.creditos.repository.CreditoTrabajadorRepository;
import com.thiago.gestionbodega.modules.productos.entity.Producto;
import com.thiago.gestionbodega.modules.productos.repository.ProductoRepository;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import com.thiago.gestionbodega.modules.ventas.dto.*;
import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import com.thiago.gestionbodega.modules.ventas.entity.Venta;
import com.thiago.gestionbodega.modules.ventas.entity.VentaDetalle;
import com.thiago.gestionbodega.modules.ventas.entity.VentaPago;
import com.thiago.gestionbodega.modules.ventas.repository.VentaDetalleRepository;
import com.thiago.gestionbodega.modules.ventas.repository.VentaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Registra ventas conectadas a la caja abierta del cajero:
 *   1) Crea Venta + VentaDetalle (descuenta stock de productos no-servicio)
 *   2) Crea VentaPago[] (pago mixto: una venta puede tener varios pagos)
 *   3) Si un pago es CREDITO, registra un CreditoTrabajador asociado
 *   4) Valida que suma(items.subtotal) == suma(pagos.monto)
 *
 * Todo en una sola transaccion: si algo falla, rollback completo.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VentaService {

    private final VentaRepository ventaRepo;
    private final VentaDetalleRepository detalleRepo;
    private final CajaRepository cajaRepo;
    private final ProductoRepository productoRepo;
    private final UsuarioRepository usuarioRepo;
    private final ClienteRepository clienteRepo;
    private final CreditoTrabajadorRepository creditoRepo;

    public List<VentaDto> listar() {
        return ventaRepo.findAll().stream()
                .sorted((a, b) -> b.getFecha().compareTo(a.getFecha()))
                .map(VentaDto::sinDetalle)
                .toList();
    }

    public VentaDto obtener(UUID id) {
        Venta v = ventaRepo.findById(id)
                .orElseThrow(() -> new NotFoundException("Venta no encontrada: " + id));
        List<VentaDetalleDto> items = detalleRepo.findByVentaIdOrderByIdAsc(id)
                .stream().map(VentaDetalleDto::from).toList();
        List<VentaPagoDto> pagos = v.getPagos().stream().map(VentaPagoDto::from).toList();
        return VentaDto.conDetalle(v, items, pagos);
    }

    @Transactional
    public VentaDto crear(String username, CrearVentaRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));

        // 1) Caja abierta del cajero
        Caja caja = cajaRepo
                .findFirstByUsuarioIdAndEstado(user.getId(), EstadoCaja.ABIERTA)
                .orElseThrow(() -> new BusinessException(
                        "No tienes ninguna caja abierta. Abre una caja antes de vender."));

        // 2) Validar pagos consistentes
        validarPagos(req);

        // 3) Crear venta (total temporal en 0, se actualiza al final)
        Venta venta = Venta.builder()
                .caja(caja)
                .usuario(user)
                .fecha(OffsetDateTime.now())
                .total(BigDecimal.ZERO)
                .anulada(false)
                .pagos(new ArrayList<>())
                .build();
        venta = ventaRepo.save(venta);

        // 4) Procesar items: crear detalle + descontar stock
        BigDecimal totalItems = BigDecimal.ZERO;
        List<VentaDetalleDto> itemsDto = new ArrayList<>();
        for (VentaDetalleRequest it : req.items()) {
            Producto p = productoRepo.findById(it.productoId())
                    .orElseThrow(() -> new NotFoundException(
                            "Producto no encontrado: " + it.productoId()));
            if (!p.isActivo()) {
                throw new BusinessException("Producto inactivo: " + p.getDescripcion());
            }
            if (!p.isEsServicio() && p.getStock().compareTo(it.cantidad()) < 0) {
                throw new BusinessException(
                        "Stock insuficiente para " + p.getDescripcion()
                                + " (disponible: " + p.getStock() + ")");
            }

            BigDecimal subtotal = it.cantidad().multiply(it.precioUnitario())
                    .setScale(2, RoundingMode.HALF_UP);
            totalItems = totalItems.add(subtotal);

            VentaDetalle d = VentaDetalle.builder()
                    .venta(venta)
                    .producto(p)
                    .cantidad(it.cantidad())
                    .precioUnitario(it.precioUnitario())
                    .subtotal(subtotal)
                    .build();
            d = detalleRepo.save(d);
            itemsDto.add(VentaDetalleDto.from(d));

            // Descontar stock solo si no es servicio
            if (!p.isEsServicio()) {
                p.setStock(p.getStock().subtract(it.cantidad()));
                productoRepo.save(p);
            }
        }

        // 5) Procesar pagos (uno o varios — pago mixto)
        int orden = 0;
        FormaPago formaPrimaria = null;
        Cliente trabajadorPrimario = null;
        for (VentaPagoRequest pp : req.pagos()) {
            VentaPago pago = VentaPago.builder()
                    .formaPago(pp.formaPago())
                    .monto(pp.monto())
                    .codigoOperacion(blankToNull(pp.codigoOperacion()))
                    .orden(orden)
                    .build();

            // Si es credito, asociar el cliente-trabajador y crear el registro
            if (pp.formaPago() == FormaPago.CREDITO) {
                Cliente trab = clienteRepo.findById(pp.trabajadorCreditoId())
                        .orElseThrow(() -> new NotFoundException(
                                "Trabajador no encontrado: " + pp.trabajadorCreditoId()));
                if (!trab.isEsTrabajador() || !trab.isActivo()) {
                    throw new BusinessException(
                            "El cliente seleccionado no es un trabajador activo");
                }
                pago.setTrabajadorCredito(trab);
                if (trabajadorPrimario == null) trabajadorPrimario = trab;

                creditoRepo.save(CreditoTrabajador.builder()
                        .trabajador(trab)
                        .venta(venta)
                        .monto(pp.monto())
                        .fecha(OffsetDateTime.now())
                        .cerrado(false)
                        .build());
            }

            venta.agregarPago(pago);
            if (orden == 0) formaPrimaria = pp.formaPago();
            orden++;
        }

        // 6) Actualizar total y compatibilidad legacy (forma_pago)
        venta.setTotal(totalItems);
        venta.setFormaPago(formaPrimaria);
        venta.setTrabajadorCredito(trabajadorPrimario);
        venta = ventaRepo.save(venta);

        log.info("Venta {} registrada: {} items, total {} en caja {} ({} pagos)",
                venta.getId(), req.items().size(), totalItems,
                caja.getId(), req.pagos().size());

        List<VentaPagoDto> pagosDto = venta.getPagos().stream()
                .map(VentaPagoDto::from).toList();
        return VentaDto.conDetalle(venta, itemsDto, pagosDto);
    }

    /** Suma items == suma pagos, y credito requiere trabajadorId. */
    private void validarPagos(CrearVentaRequest req) {
        BigDecimal totalItems = req.items().stream()
                .map(it -> it.cantidad().multiply(it.precioUnitario()))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);

        BigDecimal totalPagos = req.pagos().stream()
                .map(VentaPagoRequest::monto)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);

        if (totalItems.compareTo(totalPagos) != 0) {
            throw new BusinessException(
                    "El total de pagos (" + totalPagos
                            + ") no coincide con el total de items (" + totalItems + ")");
        }

        for (VentaPagoRequest pp : req.pagos()) {
            if (pp.formaPago() == FormaPago.CREDITO && pp.trabajadorCreditoId() == null) {
                throw new BusinessException(
                        "Pago a credito requiere el id del trabajador");
            }
        }
    }

    private static String blankToNull(String s) {
        if (s == null) return null;
        s = s.trim();
        return s.isEmpty() ? null : s;
    }
}
