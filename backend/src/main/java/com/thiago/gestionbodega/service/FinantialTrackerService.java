package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.repository.ConfiguracionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * Puente hacia FinantialTracker (sistema de prestamos, misma base de datos).
 *
 * Una deuda de la tienda se refleja alla como un {@code abono} de 1 cuota
 * con el concepto configurado (por defecto 8 = "DESCUENTOS CREDITO BAZAR"),
 * exactamente como lo hace la pantalla "Abonos" de FinantialTracker
 * (ver AbonoDao.insertAbono / AbonoDetailsDao.insertAbonoDetail):
 *
 *   abono:       SoliNum = ID con 8 digitos, Employee_id = employees.employee_id,
 *                dues = 1, monthly = monto, paymentDate = ultimo dia del mes de
 *                descuento, status = 'Pendiente', discount_from = 'BOLETA DE HABERES'
 *   abonodetail: 1 cuota, payment = 0, state = 'Pendiente'
 *
 * FinantialTracker luego la cobra por planilla y la marca 'Pagado'.
 *
 * ESTADO ACTUAL: la union esta DESACTIVADA (configuracion
 * finantial.exportar_al_cerrar = false). El cierre mensual solo deja el
 * proceso registrado en cierre_creditos_detalle; nada se escribe en las
 * tablas de FinantialTracker hasta que se active la union.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FinantialTrackerService {

    public static final String CFG_CONCEPTO   = "finantial.concepto_abono_id";
    public static final String CFG_USUARIO    = "finantial.usuario_id";
    public static final String CFG_DESCUENTO  = "finantial.descuento_desde";
    public static final String CFG_AUTO       = "finantial.exportar_al_cerrar";

    private final NamedParameterJdbcTemplate jdbc;
    private final ConfiguracionRepository configRepo;

    public boolean exportarAlCerrar() {
        return Boolean.parseBoolean(cfg(CFG_AUTO, "false"));
    }

    /** Verifica que el empleado exista en FinantialTracker. */
    public boolean existeEmpleado(Integer empleadoId) {
        if (empleadoId == null) return false;
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM employees WHERE employee_id = :id",
                new MapSqlParameterSource("id", empleadoId), Long.class);
        return n != null && n > 0;
    }

    /**
     * Crea el abono (+ su cuota) en FinantialTracker y devuelve abono.ID.
     * Corre en su propia transaccion para que un fallo con un trabajador no
     * tumbe el cierre ni las exportaciones de los demas.
     *
     * @param empleadoId     employees.employee_id
     * @param monto          total de la deuda del periodo
     * @param mesDescuento   mes en cuya planilla se descuenta (paymentDate = su ultimo dia)
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int registrarAbono(Integer empleadoId, BigDecimal monto, LocalDate mesDescuento) {
        if (empleadoId == null) {
            throw new BusinessException("El trabajador no esta enlazado a FinantialTracker (sin empleado_id)");
        }
        if (!existeEmpleado(empleadoId)) {
            throw new BusinessException("El empleado " + empleadoId + " no existe en FinantialTracker");
        }
        if (monto == null || monto.signum() <= 0) {
            throw new BusinessException("Monto invalido para exportar: " + monto);
        }

        String concepto   = cfg(CFG_CONCEPTO, "8");
        int usuarioFt     = Integer.parseInt(cfg(CFG_USUARIO, "3"));
        String descuento  = cfg(CFG_DESCUENTO, "BOLETA DE HABERES");
        String hoy        = LocalDate.now().toString();
        String fechaPago  = mesDescuento.withDayOfMonth(mesDescuento.lengthOfMonth()).toString();

        KeyHolder keys = new GeneratedKeyHolder();
        jdbc.update("""
                INSERT INTO abono (SoliNum, service_concept_id, Employee_id, dues, monthly, paymentDate,
                                   status, discount_from, createdBy, createdAt, modifiedBy, modifiedAt, lote_id)
                VALUES ('', :concepto, :empleado, 1, :monto, :fechaPago,
                        'Pendiente', :descuento, :usuario, :hoy, 0, NULL, NULL)
                """,
                new MapSqlParameterSource()
                        .addValue("concepto", concepto)
                        .addValue("empleado", String.valueOf(empleadoId))
                        .addValue("monto", monto)
                        .addValue("fechaPago", fechaPago)
                        .addValue("descuento", descuento)
                        .addValue("usuario", usuarioFt)
                        .addValue("hoy", hoy),
                keys, new String[]{"ID"});
        int abonoId = keys.getKey().intValue();

        // FinantialTracker usa el propio ID (8 digitos) como numero de solicitud
        jdbc.update("UPDATE abono SET SoliNum = :soli WHERE ID = :id",
                new MapSqlParameterSource()
                        .addValue("soli", String.format("%08d", abonoId))
                        .addValue("id", abonoId));

        jdbc.update("""
                INSERT INTO abonodetail (AbonoID, dues, monthly, payment, paymentDate, state,
                                         createdBy, createdAt, modifiedBy, modifiedAt)
                VALUES (:id, 1, :monto, 0.00, :fechaPago, 'Pendiente', :usuario, :hoy, '', '')
                """,
                new MapSqlParameterSource()
                        .addValue("id", abonoId)
                        .addValue("monto", monto)
                        .addValue("fechaPago", fechaPago)
                        .addValue("usuario", String.valueOf(usuarioFt))
                        .addValue("hoy", hoy));

        log.info("FinantialTracker: abono {} creado para empleado {} por S/. {} (descuento {})",
                abonoId, empleadoId, monto, fechaPago);
        return abonoId;
    }

    /** Estado en FinantialTracker de los abonos generados por la tienda. */
    public List<Map<String, Object>> abonosDeLaTienda(int limite) {
        return jdbc.queryForList("""
                SELECT a.ID AS abono_id, a.SoliNum AS solicitud, a.Employee_id AS empleado_id,
                       e.fullName AS empleado, a.monthly AS monto, a.paymentDate AS fecha_descuento,
                       a.status AS estado, a.createdAt AS creado_en,
                       cd.cierre_id, cm.anio, cm.mes
                FROM abono a
                LEFT JOIN employees e ON e.employee_id = a.Employee_id
                JOIN cierre_creditos_detalle cd ON cd.ft_abono_id = a.ID
                JOIN cierres_mensuales_creditos cm ON cm.id = cd.cierre_id
                ORDER BY a.ID DESC
                LIMIT :lim
                """, new MapSqlParameterSource("lim", limite));
    }

    /** Conceptos disponibles en FinantialTracker (para elegir el de la tienda en Configuracion). */
    public List<Map<String, Object>> conceptos() {
        return jdbc.queryForList(
                "SELECT ID AS id, description AS descripcion, codigo FROM service_concept ORDER BY ID",
                new MapSqlParameterSource());
    }

    private String cfg(String clave, String porDefecto) {
        return configRepo.findById(clave)
                .map(c -> c.getValor() == null || c.getValor().isBlank() ? porDefecto : c.getValor().trim())
                .orElse(porDefecto);
    }
}
