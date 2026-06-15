package com.thiago.gestionbodega.modules.cajas.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.cajas.dto.*;
import com.thiago.gestionbodega.modules.cajas.entity.AvanceEfectivo;
import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.entity.EstadoCaja;
import com.thiago.gestionbodega.modules.cajas.repository.AvanceEfectivoRepository;
import com.thiago.gestionbodega.modules.cajas.repository.CajaRepository;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CajaService {

    private final CajaRepository cajaRepository;
    private final AvanceEfectivoRepository avanceRepository;
    private final UsuarioRepository usuarioRepository;

    public List<CajaDto> listar() {
        return cajaRepository.findAll().stream().map(CajaDto::from).toList();
    }

    /**
     * Retorna la caja abierta del usuario actual, con totales agregados.
     */
    public CajaDetalleDto obtenerCajaAbiertaDelUsuario(String username) {
        Usuario user = getUsuario(username);
        Caja caja = cajaRepository
                .findFirstByUsuarioIdAndEstado(user.getId(), EstadoCaja.ABIERTA)
                .orElseThrow(() -> new NotFoundException(
                        "No tienes ninguna caja abierta. Abrela primero."));
        return armarDetalle(caja);
    }

    @Transactional
    public CajaDto abrirCaja(String username, AbrirCajaRequest req) {
        Usuario user = getUsuario(username);

        if (cajaRepository.existsByUsuarioIdAndEstado(user.getId(), EstadoCaja.ABIERTA)) {
            throw new BusinessException(
                    "Ya tienes una caja abierta. Cierrala antes de abrir otra.");
        }

        Caja caja = Caja.builder()
                .usuario(user)
                .turno(req.turno())
                .fechaApertura(OffsetDateTime.now())
                .montoApertura(req.montoApertura())
                .contometroInicio(req.contometroInicio())
                .estado(EstadoCaja.ABIERTA)
                .build();
        return CajaDto.from(cajaRepository.save(caja));
    }

    @Transactional
    public CajaDto cerrarCaja(UUID cajaId, String username, CerrarCajaRequest req) {
        Usuario user = getUsuario(username);
        Caja caja = cajaRepository.findById(cajaId)
                .orElseThrow(() -> new NotFoundException("Caja no encontrada: " + cajaId));

        if (caja.getEstado() != EstadoCaja.ABIERTA) {
            throw new BusinessException("La caja ya esta cerrada");
        }
        // Solo el propio usuario o admin/encargado pueden cerrar
        boolean esDueno = caja.getUsuario().getId().equals(user.getId());
        boolean puedeCorregir = user.getRol() != null
                && (user.getRol().name().equals("ADMINISTRADOR")
                || user.getRol().name().equals("ENCARGADO"));
        if (!esDueno && !puedeCorregir) {
            throw new BusinessException("No tienes permiso para cerrar esta caja");
        }

        caja.setMontoCierre(req.montoCierre());
        caja.setContometroFin(req.contometroFin());
        caja.setFechaCierre(OffsetDateTime.now());
        caja.setEstado(EstadoCaja.CERRADA);
        return CajaDto.from(cajaRepository.save(caja));
    }

    @Transactional
    public AvanceDto registrarAvance(UUID cajaId, String username, AvanceRequest req) {
        Usuario user = getUsuario(username);
        Caja caja = cajaRepository.findById(cajaId)
                .orElseThrow(() -> new NotFoundException("Caja no encontrada: " + cajaId));

        if (caja.getEstado() != EstadoCaja.ABIERTA) {
            throw new BusinessException(
                    "Solo se pueden registrar avances en una caja abierta");
        }
        if (!caja.getUsuario().getId().equals(user.getId())) {
            throw new BusinessException("Solo el vendedor de la caja puede registrar avances");
        }

        AvanceEfectivo a = AvanceEfectivo.builder()
                .caja(caja)
                .monto(req.monto())
                .observacion(req.observacion())
                .build();
        return AvanceDto.from(avanceRepository.save(a));
    }

    /**
     * Construye el detalle agregado de la caja: ventas por forma de pago,
     * avances y efectivo esperado.
     */
    private CajaDetalleDto armarDetalle(Caja caja) {
        // Totales por forma de pago
        Map<String, BigDecimal> ventasPorForma = new LinkedHashMap<>();
        for (FormaPago f : FormaPago.values()) {
            ventasPorForma.put(f.name(), BigDecimal.ZERO);
        }
        for (Object[] row : cajaRepository.totalesPorFormaPago(caja.getId())) {
            ventasPorForma.put((String) row[0], (BigDecimal) row[1]);
        }
        BigDecimal totalVentas = cajaRepository.totalVentasNoAnuladas(caja.getId());

        // Avances
        List<AvanceDto> avances = avanceRepository.findByCajaIdOrderByFechaDesc(caja.getId())
                .stream().map(AvanceDto::from).toList();
        BigDecimal totalAvances = avanceRepository.sumarMontosPorCaja(caja.getId())
                .orElse(BigDecimal.ZERO);

        // Efectivo esperado = monto_apertura + ventas_efectivo - total_avances
        BigDecimal ventasEfectivo = ventasPorForma.getOrDefault(
                FormaPago.EFECTIVO.name(), BigDecimal.ZERO);
        BigDecimal efectivoEsperado = caja.getMontoApertura()
                .add(ventasEfectivo)
                .subtract(totalAvances);

        return CajaDetalleDto.builder()
                .caja(CajaDto.from(caja))
                .totalVentas(totalVentas)
                .ventasPorFormaPago(ventasPorForma)
                .avances(avances)
                .totalAvances(totalAvances)
                .efectivoEsperadoEnCaja(efectivoEsperado)
                .build();
    }

    private Usuario getUsuario(String username) {
        return usuarioRepository.findByUsername(username)
                .orElseThrow(() -> new NotFoundException(
                        "Usuario no encontrado: " + username));
    }
}
