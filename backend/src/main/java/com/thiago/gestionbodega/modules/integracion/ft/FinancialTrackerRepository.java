package com.thiago.gestionbodega.modules.integracion.ft;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Acceso directo a la BD financialtracker1 usando JDBC crudo (no JPA).
 * Refleja exactamente los INSERT / SELECT que hace el AbonoDao original de
 * FinantialTracker, para asegurar compatibilidad total con su UI existente.
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier} sobre
 * un campo con {@code @RequiredArgsConstructor} NO se propaga al constructor
 * generado — Spring termina inyectando el JdbcTemplate primario (bodega) en
 * vez del secundario (FT) y explota con "Table gestion_bodega.employees
 * doesn't exist".
 */
@Repository
@ConditionalOnBean(name = "ftJdbc")
public class FinancialTrackerRepository {

    private final NamedParameterJdbcTemplate ftJdbc;

    public FinancialTrackerRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc) {
        this.ftJdbc = ftJdbc;
    }

    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter FECHA_HORA =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    // ─── Employees ─────────────────────────────────────────────────────

    /**
     * Busca el employee_id por DNI (national_id en el schema del HSJ).
     * Devuelve Optional vacio si el trabajador no esta cargado en FT.
     */
    public Optional<Integer> findEmployeeIdByDni(String dni) {
        String sql = "SELECT employee_id FROM employees WHERE national_id = :dni LIMIT 1";
        List<Integer> ids = ftJdbc.queryForList(sql,
                new MapSqlParameterSource("dni", dni),
                Integer.class);
        return ids.isEmpty() ? Optional.empty() : Optional.of(ids.get(0));
    }

    /**
     * Lista todos los empleados del FT para importar a la bodega.
     * Devuelve solo campos que la bodega necesita (dni, nombre, estado).
     */
    public List<Map<String, Object>> listarEmpleados() {
        return ftJdbc.queryForList("""
                SELECT national_id AS dni,
                       fullName AS nombre_completo,
                       employment_status AS estado_empleo
                  FROM employees
                 WHERE national_id IS NOT NULL AND national_id != ''
                 ORDER BY fullName
                """, new MapSqlParameterSource());
    }

    // ─── Lote de carga ─────────────────────────────────────────────────

    public int crearLote(String nombreArchivo, int cantidadAbonos) {
        String sql = """
                INSERT INTO lote_carga_abono
                    (fecha_creacion, usuario_id, nombre_archivo, cantidad_abonos, state)
                VALUES (:fecha, NULL, :nombre, :cantidad, 'ACTIVO')
                """;
        KeyHolder kh = new GeneratedKeyHolder();
        ftJdbc.update(sql,
                new MapSqlParameterSource()
                        .addValue("fecha", LocalDateTime.now().format(FECHA_HORA))
                        .addValue("nombre", nombreArchivo)
                        .addValue("cantidad", cantidadAbonos),
                kh);
        Number key = kh.getKey();
        if (key == null) {
            throw new IllegalStateException("No se pudo obtener el id del lote generado");
        }
        return key.intValue();
    }

    public void marcarLoteRevertido(int loteId, String motivo) {
        String sql = """
                UPDATE lote_carga_abono
                   SET state = 'REVERTIDO',
                       motivo_reversion = :motivo,
                       fecha_reversion = :fecha
                 WHERE id = :id
                """;
        ftJdbc.update(sql,
                new MapSqlParameterSource()
                        .addValue("id", loteId)
                        .addValue("motivo", motivo)
                        .addValue("fecha", LocalDateTime.now().format(FECHA_HORA)));
    }

    // ─── Abono + AbonoDetail ───────────────────────────────────────────

    /**
     * Inserta un abono en FT. Replica el patron del AbonoDao original:
     * INSERT en abono, luego UPDATE SoliNum = LPAD(id, 8, '0').
     */
    public int insertarAbono(int employeeId, int serviceConceptId, int lotId,
                              BigDecimal monto, int dues, LocalDate paymentDate) {
        String insert = """
                INSERT INTO abono
                    (SoliNum, service_concept_id, Employee_id, dues, monthly,
                     paymentDate, status, discount_from, createdBy, createdAt,
                     modifiedBy, modifiedAt, lote_id)
                VALUES
                    ('', :sci, :eid, :dues, :monto,
                     :pdate, 'Pendiente', 'BODEGA', 0, :now,
                     0, :now, :lote)
                """;
        KeyHolder kh = new GeneratedKeyHolder();
        String now = LocalDateTime.now().format(FECHA_HORA);
        ftJdbc.update(insert,
                new MapSqlParameterSource()
                        .addValue("sci", String.valueOf(serviceConceptId))
                        .addValue("eid", String.valueOf(employeeId))
                        .addValue("dues", dues)
                        .addValue("monto", monto)
                        .addValue("pdate", paymentDate.format(FECHA))
                        .addValue("now", now)
                        .addValue("lote", lotId),
                kh);
        int abonoId = kh.getKey().intValue();

        // Actualizar SoliNum al padding-8 del id (igual que hace el DAO original)
        ftJdbc.update("UPDATE abono SET SoliNum = LPAD(:id, 8, '0') WHERE ID = :id",
                new MapSqlParameterSource("id", abonoId));

        return abonoId;
    }

    /**
     * Inserta las cuotas del abono. Para deuda de bodega usamos dues=1
     * (una sola cuota), pero se admite N cuotas para flexibilidad futura.
     */
    public void insertarAbonoDetails(int abonoId, int dues, BigDecimal montoMensual,
                                     LocalDate primerPaymentDate) {
        String insert = """
                INSERT INTO abonodetail
                    (AbonoID, dues, monthly, payment, paymentDate, state,
                     createdBy, createdAt, modifiedBy, modifiedAt)
                VALUES
                    (:aid, :dues, :monthly, 0, :pdate, 'Pendiente',
                     0, :now, 0, :now)
                """;
        String now = LocalDateTime.now().format(FECHA_HORA);
        LocalDate fecha = primerPaymentDate;
        for (int i = 1; i <= dues; i++) {
            ftJdbc.update(insert,
                    new MapSqlParameterSource()
                            .addValue("aid", abonoId)
                            .addValue("dues", i)
                            .addValue("monthly", montoMensual)
                            .addValue("pdate", fecha.format(FECHA))
                            .addValue("now", now));
            fecha = fecha.plusMonths(1);
        }
    }

    // ─── Reversion ─────────────────────────────────────────────────────

    /**
     * Borra los abonodetail + abono asociados a un lote, si aun no han
     * recibido pagos. Devuelve cuantos abonos borrados.
     * Replica el flujo del LoteCargaAbonoDao.revertirLote() original.
     */
    public int borrarAbonosDeLote(int loteId) {
        // 1. Separar del lote los abonos que ya tengan pagos (state Pagado o Parcial)
        String sepUsados = """
                UPDATE abono SET lote_id = NULL
                 WHERE lote_id = :id AND ID IN (
                    SELECT * FROM (
                        SELECT a.ID FROM abono a
                        JOIN abonodetail ad ON ad.AbonoID = a.ID
                        WHERE a.lote_id = :id
                          AND (ad.state = 'Pagado' OR ad.state = 'Parcial')
                    ) t
                 )
                """;
        ftJdbc.update(sepUsados, new MapSqlParameterSource("id", loteId));

        // 2. Borrar abonodetail de los que aun estan en el lote
        ftJdbc.update("""
                DELETE ad FROM abonodetail ad
                  JOIN abono a ON ad.AbonoID = a.ID
                 WHERE a.lote_id = :id
                """, new MapSqlParameterSource("id", loteId));

        // 3. Borrar los abonos del lote
        return ftJdbc.update("DELETE FROM abono WHERE lote_id = :id",
                new MapSqlParameterSource("id", loteId));
    }

    // ─── Health check ──────────────────────────────────────────────────

    /** Devuelve true si la BD responde. Util para el endpoint /health. */
    public boolean ping() {
        try {
            Integer one = ftJdbc.queryForObject("SELECT 1", new MapSqlParameterSource(), Integer.class);
            return one != null && one == 1;
        } catch (Exception e) {
            return false;
        }
    }

    /** Verifica que exista el service_concept_id configurado. */
    public boolean existeServiceConcept(int id) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM service_concept WHERE ID = :id",
                new MapSqlParameterSource("id", id), Integer.class);
        return count != null && count > 0;
    }
}
