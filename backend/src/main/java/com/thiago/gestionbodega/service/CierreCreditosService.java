package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.CierreMensualResultDto;
import com.thiago.gestionbodega.entity.Usuario;
import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import com.thiago.gestionbodega.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Cierre mensual de creditos (deudas de trabajadores).
 *
 * Flujo:
 *   1. Los consumos a credito del mes se ACUMULAN por trabajador (clientes).
 *   2. Al cerrar, se suman por trabajador, se trasladan a deuda_trabajadores
 *      y se guarda una fila por trabajador en cierre_creditos_detalle.
 *   3. Cada fila del detalle se exporta a FinantialTracker como un `abono`
 *      (concepto "DESCUENTOS CREDITO BAZAR") para que se descuente por planilla.
 *      La exportacion corre fuera de la transaccion del cierre: si falla para
 *      un trabajador, queda registrado en ft_error y se puede reintentar.
 *
 * El cierre lo dispara MANUALMENTE el administrador desde la UI.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CierreCreditosService {

    private final NamedParameterJdbcTemplate jdbc;
    private final UsuarioRepository usuarioRepo;
    private final FinantialTrackerService finantial;
    private final TransactionTemplate tx;

    /** Cierra el periodo (anio, mes) actual o el indicado y exporta a FinantialTracker. */
    public CierreMensualResultDto cerrarMes(String username, Integer anio, Integer mes) {
        Usuario admin = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        LocalDate hoy = LocalDate.now();
        int periodoAnio = anio != null ? anio : hoy.getYear();
        int periodoMes = mes != null ? mes : hoy.getMonthValue();

        // Paso A (transaccional): cerrar y armar el detalle
        String cierreId = tx.execute(status -> cerrarPeriodo(admin, periodoAnio, periodoMes));

        // Paso B (fuera de la transaccion): exportar a FinantialTracker
        int exportados = 0, conError = 0;
        if (finantial.exportarAlCerrar()) {
            int[] r = exportarCierre(cierreId);
            exportados = r[0];
            conError = r[1];
        }

        Map<String, Object> c = jdbc.queryForMap(
                "SELECT trabajadores_afectados, monto_total, fecha_cierre FROM cierres_mensuales_creditos WHERE id = :id",
                new MapSqlParameterSource("id", cierreId));
        Long creditos = jdbc.queryForObject(
                "SELECT COUNT(*) FROM creditos_trabajadores WHERE cierre_id = :id",
                new MapSqlParameterSource("id", cierreId), Long.class);

        return CierreMensualResultDto.builder()
                .cierreId(cierreId)
                .anio(periodoAnio)
                .mes(periodoMes)
                .fechaCierre(OffsetDateTime.now())
                .trabajadoresAfectados(((Number) c.get("trabajadores_afectados")).intValue())
                .montoTotal((BigDecimal) c.get("monto_total"))
                .creditosCerrados(creditos == null ? 0 : creditos.intValue())
                .exportadosFinantial(exportados)
                .erroresFinantial(conError)
                .build();
    }

    private String cerrarPeriodo(Usuario admin, int periodoAnio, int periodoMes) {
        var params = new MapSqlParameterSource().addValue("a", periodoAnio).addValue("m", periodoMes);

        Long yaCerrado = jdbc.queryForObject(
                "SELECT COUNT(*) FROM cierres_mensuales_creditos WHERE anio = :a AND mes = :m", params, Long.class);
        if (yaCerrado != null && yaCerrado > 0) {
            throw new BusinessException("El periodo " + periodoMes + "/" + periodoAnio + " ya fue cerrado anteriormente");
        }

        List<Map<String, Object>> totales = jdbc.queryForList("""
                SELECT cliente_id, COUNT(*) AS consumos, COALESCE(SUM(monto), 0) AS total
                FROM creditos_trabajadores
                WHERE cerrado = FALSE AND cliente_id IS NOT NULL
                  AND periodo_anio = :a AND periodo_mes = :m
                GROUP BY cliente_id
                HAVING SUM(monto) > 0
                """, params);
        if (totales.isEmpty()) {
            throw new BusinessException("No hay creditos pendientes en " + periodoMes + "/" + periodoAnio + " para cerrar");
        }

        String cierreId = UUID.randomUUID().toString();
        BigDecimal montoTotal = BigDecimal.ZERO;
        for (var row : totales) montoTotal = montoTotal.add((BigDecimal) row.get("total"));

        // 1) cabecera del cierre
        jdbc.update("""
                INSERT INTO cierres_mensuales_creditos
                  (id, anio, mes, fecha_cierre, cerrado_por, trabajadores_afectados, monto_total)
                VALUES (:id, :a, :m, NOW(6), :userId, :trabajadores, :monto)
                """, new MapSqlParameterSource()
                        .addValue("id", cierreId).addValue("a", periodoAnio).addValue("m", periodoMes)
                        .addValue("userId", admin.getId().toString())
                        .addValue("trabajadores", totales.size()).addValue("monto", montoTotal));

        // 2) por trabajador: deuda acumulada (UPSERT) + detalle del cierre
        for (var row : totales) {
            String clienteId = String.valueOf(row.get("cliente_id"));
            BigDecimal monto = (BigDecimal) row.get("total");
            int consumos = ((Number) row.get("consumos")).intValue();

            jdbc.update("""
                    INSERT INTO deuda_trabajadores (id, cliente_id, monto_total, actualizada_en)
                    VALUES (:id, :cid, :monto, NOW(6)) AS nueva
                    ON DUPLICATE KEY UPDATE
                      monto_total = deuda_trabajadores.monto_total + nueva.monto_total,
                      actualizada_en = NOW(6)
                    """, new MapSqlParameterSource()
                            .addValue("id", UUID.randomUUID().toString())
                            .addValue("cid", clienteId).addValue("monto", monto));

            jdbc.update("""
                    INSERT INTO cierre_creditos_detalle (id, cierre_id, cliente_id, cantidad_consumos, monto)
                    VALUES (:id, :cierre, :cid, :n, :monto)
                    """, new MapSqlParameterSource()
                            .addValue("id", UUID.randomUUID().toString())
                            .addValue("cierre", cierreId).addValue("cid", clienteId)
                            .addValue("n", consumos).addValue("monto", monto));
        }

        // 3) marcar los creditos del periodo como cerrados
        int cerrados = jdbc.update("""
                UPDATE creditos_trabajadores
                   SET cerrado = TRUE, cerrado_en = NOW(6), cierre_id = :cierre
                 WHERE cerrado = FALSE AND cliente_id IS NOT NULL
                   AND periodo_anio = :a AND periodo_mes = :m
                """, params.addValue("cierre", cierreId));

        log.info("Cierre creditos {}/{}: {} trabajadores, S/. {}, {} creditos",
                periodoMes, periodoAnio, totales.size(), montoTotal, cerrados);
        return cierreId;
    }

    /**
     * Exporta a FinantialTracker las filas del cierre que aun no tienen abono.
     * Reintentable. Devuelve {exportados, conError}.
     */
    public int[] exportarCierre(String cierreId) {
        Map<String, Object> cierre = jdbc.queryForMap(
                "SELECT anio, mes FROM cierres_mensuales_creditos WHERE id = :id",
                new MapSqlParameterSource("id", cierreId));
        // Se descuenta en la planilla del mes SIGUIENTE al periodo cerrado
        LocalDate mesDescuento = LocalDate.of(((Number) cierre.get("anio")).intValue(),
                ((Number) cierre.get("mes")).intValue(), 1).plusMonths(1);

        List<Map<String, Object>> pendientes = jdbc.queryForList("""
                SELECT cd.id, cd.monto, c.empleado_id, CONCAT(c.apellidos, ' ', c.nombres) AS nombre
                FROM cierre_creditos_detalle cd
                JOIN clientes c ON c.id = cd.cliente_id
                WHERE cd.cierre_id = :id AND cd.ft_abono_id IS NULL
                """, new MapSqlParameterSource("id", cierreId));

        int ok = 0, err = 0;
        for (var d : pendientes) {
            String detalleId = String.valueOf(d.get("id"));
            Integer empleadoId = d.get("empleado_id") == null ? null : ((Number) d.get("empleado_id")).intValue();
            try {
                int abonoId = finantial.registrarAbono(empleadoId, (BigDecimal) d.get("monto"), mesDescuento);
                jdbc.update("""
                        UPDATE cierre_creditos_detalle
                           SET ft_abono_id = :abono, ft_exportado_en = NOW(6), ft_error = NULL
                         WHERE id = :id
                        """, new MapSqlParameterSource().addValue("abono", abonoId).addValue("id", detalleId));
                ok++;
            } catch (Exception ex) {
                err++;
                String msg = ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage();
                if (msg.length() > 490) msg = msg.substring(0, 490);
                jdbc.update("UPDATE cierre_creditos_detalle SET ft_error = :e WHERE id = :id",
                        new MapSqlParameterSource().addValue("e", msg).addValue("id", detalleId));
                log.warn("No se pudo exportar a FinantialTracker la deuda de {}: {}", d.get("nombre"), msg);
            }
        }
        return new int[]{ok, err};
    }

    /** Lista de creditos del mes actual agrupados por trabajador. */
    public List<Map<String, Object>> creditosDelMes() {
        return jdbc.queryForList("""
                SELECT cliente_id, dni, nombre_completo, empleado_id, condicion_laboral,
                       cantidad_consumos, monto_pendiente, ultimo_consumo, anio, mes
                FROM v_creditos_del_mes
                ORDER BY monto_pendiente DESC
                """, new MapSqlParameterSource());
    }

    /** Deuda acumulada (planilla) por trabajador. */
    public List<Map<String, Object>> deudaAcumulada() {
        return jdbc.queryForList("""
                SELECT cliente_id, dni, nombre_completo, empleado_id, deuda_acumulada, actualizada_en
                FROM v_deuda_trabajadores_acumulada
                ORDER BY deuda_acumulada DESC
                """, new MapSqlParameterSource());
    }

    /** Historico de cierres mensuales con el estado de exportacion a FinantialTracker. */
    public List<Map<String, Object>> historialCierres() {
        return jdbc.queryForList("""
                SELECT cm.id, cm.anio, cm.mes, cm.fecha_cierre, cm.trabajadores_afectados, cm.monto_total,
                       (SELECT COUNT(*) FROM cierre_creditos_detalle d WHERE d.cierre_id = cm.id AND d.ft_abono_id IS NOT NULL) AS exportados_finantial,
                       (SELECT COUNT(*) FROM cierre_creditos_detalle d WHERE d.cierre_id = cm.id AND d.ft_abono_id IS NULL)     AS pendientes_finantial
                FROM cierres_mensuales_creditos cm
                ORDER BY cm.anio DESC, cm.mes DESC
                """, new MapSqlParameterSource());
    }

    /** Detalle de un cierre: una fila por trabajador con su abono en FinantialTracker. */
    public List<Map<String, Object>> detalleCierre(String cierreId) {
        return jdbc.queryForList("""
                SELECT cd.id, cd.cliente_id, c.dni, CONCAT(c.apellidos, ' ', c.nombres) AS nombre_completo,
                       c.empleado_id, cd.cantidad_consumos, cd.monto,
                       cd.ft_abono_id, cd.ft_exportado_en, cd.ft_error,
                       a.SoliNum AS ft_solicitud, a.status AS ft_estado, a.paymentDate AS ft_fecha_descuento
                FROM cierre_creditos_detalle cd
                JOIN clientes c ON c.id = cd.cliente_id
                LEFT JOIN abono a ON a.ID = cd.ft_abono_id
                WHERE cd.cierre_id = :id
                ORDER BY cd.monto DESC
                """, new MapSqlParameterSource("id", cierreId));
    }
}
