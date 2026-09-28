package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.DeudorMovimientoDto;
import com.thiago.gestionbodega.dto.RegistrarConsumoCreditoRequest;
import com.thiago.gestionbodega.entity.Cliente;
import com.thiago.gestionbodega.entity.CreditoTrabajador;
import com.thiago.gestionbodega.entity.Usuario;
import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import com.thiago.gestionbodega.repository.ClienteRepository;
import com.thiago.gestionbodega.repository.CreditoTrabajadorRepository;
import com.thiago.gestionbodega.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Deudores = trabajadores (clientes sincronizados desde FinantialTracker)
 * con deuda viva en la tienda: consumos a credito del mes en curso y/o
 * deuda acumulada de meses cerrados.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DeudorService {

    private final NamedParameterJdbcTemplate jdbc;
    private final ClienteRepository clienteRepo;
    private final CreditoTrabajadorRepository creditoRepo;
    private final UsuarioRepository usuarioRepo;

    public List<Map<String, Object>> listar(String q) {
        String filtro = (q == null || q.isBlank()) ? "" :
                " WHERE dni LIKE :q OR nombre_completo LIKE :q ";
        return jdbc.queryForList("""
                SELECT cliente_id, dni, apellidos, nombres, nombre_completo, empleado_id, condicion_laboral,
                       pendiente_mes, consumos_mes, ultimo_consumo, deuda_acumulada, deuda_total,
                       exportaciones_pendientes
                FROM v_deudores
                """ + filtro + " ORDER BY deuda_total DESC",
                new MapSqlParameterSource("q", "%" + (q == null ? "" : q.trim()) + "%"));
    }

    public Map<String, Object> resumen() {
        Map<String, Object> r = jdbc.queryForMap("""
                SELECT COUNT(*)                          AS deudores,
                       COALESCE(SUM(pendiente_mes), 0)   AS pendiente_mes,
                       COALESCE(SUM(deuda_acumulada), 0) AS deuda_acumulada,
                       COALESCE(SUM(deuda_total), 0)     AS deuda_total,
                       COALESCE(SUM(consumos_mes), 0)    AS consumos_mes
                FROM v_deudores
                """, new MapSqlParameterSource());
        Map<String, Object> out = new LinkedHashMap<>(r);
        out.put("abonos_pendientes_finantial", jdbc.queryForObject(
                "SELECT COUNT(*) FROM cierre_creditos_detalle WHERE ft_abono_id IS NULL",
                new MapSqlParameterSource(), Long.class));
        return out;
    }

    public Map<String, Object> detalle(UUID clienteId) {
        Cliente c = clienteRepo.findById(clienteId)
                .orElseThrow(() -> new NotFoundException("Trabajador no encontrado"));
        List<DeudorMovimientoDto> movs = creditoRepo.findByClienteIdOrderByFechaDesc(clienteId)
                .stream().map(DeudorMovimientoDto::from).toList();
        BigDecimal pendiente = movs.stream().filter(m -> !m.cerrado())
                .map(DeudorMovimientoDto::monto).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal acumulada = jdbc.query(
                "SELECT monto_total FROM deuda_trabajadores WHERE cliente_id = :id",
                new MapSqlParameterSource("id", clienteId.toString()),
                rs -> rs.next() ? rs.getBigDecimal(1) : BigDecimal.ZERO);
        List<Map<String, Object>> abonos = jdbc.queryForList("""
                SELECT cd.ft_abono_id, cd.monto, cd.ft_exportado_en, cd.ft_error, cm.anio, cm.mes,
                       a.SoliNum AS ft_solicitud, a.status AS ft_estado, a.paymentDate AS ft_fecha_descuento
                FROM cierre_creditos_detalle cd
                JOIN cierres_mensuales_creditos cm ON cm.id = cd.cierre_id
                LEFT JOIN abono a ON a.ID = cd.ft_abono_id
                WHERE cd.cliente_id = :id
                ORDER BY cm.anio DESC, cm.mes DESC
                """, new MapSqlParameterSource("id", clienteId.toString()));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("clienteId", c.getId());
        out.put("dni", c.getDni());
        out.put("nombreCompleto", c.getNombreCompleto());
        out.put("empleadoId", c.getEmpleadoId());
        out.put("condicionLaboral", c.getCondicionLaboral());
        out.put("enlazadoFinantial", c.getEmpleadoId() != null);
        out.put("pendienteMes", pendiente);
        out.put("deudaAcumulada", acumulada);
        out.put("deudaTotal", pendiente.add(acumulada));
        out.put("movimientos", movs);
        out.put("abonosFinantial", abonos);
        return out;
    }

    /** Deuda anotada a mano (sin venta del POS). */
    @Transactional
    public DeudorMovimientoDto registrarConsumo(String username, RegistrarConsumoCreditoRequest req) {
        Usuario user = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));
        Cliente c = clienteRepo.findById(req.clienteId())
                .orElseThrow(() -> new NotFoundException("Trabajador no encontrado"));
        if (!c.isEsTrabajador() || !c.isActivo()) {
            throw new BusinessException(c.getNombreCompleto() + " no es un trabajador activo: no puede tener deuda. "
                    + "Para un cliente externo solo se registra la venta.");
        }
        CreditoTrabajador cr = creditoRepo.save(CreditoTrabajador.builder()
                .cliente(c)
                .monto(req.monto())
                .descripcion(req.descripcion())
                .registradoPor(user)
                .fecha(OffsetDateTime.now())
                .cerrado(false)
                .build());
        return DeudorMovimientoDto.from(cr);
    }

    /** Quita un consumo aun no cerrado (error de digitacion). */
    @Transactional
    public void eliminarConsumo(UUID creditoId) {
        CreditoTrabajador cr = creditoRepo.findById(creditoId)
                .orElseThrow(() -> new NotFoundException("Consumo no encontrado"));
        if (cr.isCerrado()) {
            throw new BusinessException("El consumo ya fue incluido en un cierre mensual; no se puede eliminar.");
        }
        if (cr.getVenta() != null) {
            throw new BusinessException("Este consumo viene de una venta del POS: anule la venta en su lugar.");
        }
        creditoRepo.delete(cr);
    }
}
