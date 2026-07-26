package com.thiago.gestionbodega.modules.integracion.ft.abonos;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Acceso JDBC a la BD financialtracker1 para el modulo de ABONOS.
 *
 * Replica EXACTAMENTE el SQL de los DAOs originales de la app Swing
 * FinantialTracker (AbonoDao, AbonoDetailsDao, LoteCargaAbonoDao,
 * ServiceConceptDao) â€” mismos WHERE, mismos estados
 * 'Pendiente'/'Pagado'/'Parcial', mismo padding-8 del SoliNum â€” para que la
 * app pueda consumir estos endpoints o caer a su JDBC directo sin cambios de
 * comportamiento.
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier} sobre
 * un campo con {@code @RequiredArgsConstructor} NO se propaga al constructor
 * generado (ver FinancialTrackerRepository).
 */
@Repository
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true")
public class FtAbonosRepository {

    private final NamedParameterJdbcTemplate ftJdbc;
    private final DataSource ftDataSource;

    public FtAbonosRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc,
            @Qualifier("financialTrackerDataSource") DataSource ftDataSource) {
        this.ftJdbc = ftJdbc;
        this.ftDataSource = ftDataSource;
    }

    private static final DateTimeFormatter FECHA_HORA =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    // â”€â”€â”€ Columnas con alias deterministas (los labels llegan tal cual al JSON) â”€â”€

    private static String abonoCols(String t) {
        return t + ".ID AS id, " + t + ".SoliNum AS soliNum, "
                + t + ".service_concept_id AS serviceConceptId, "
                + t + ".Employee_id AS employeeId, " + t + ".dues AS dues, "
                + t + ".monthly AS monthly, " + t + ".paymentDate AS paymentDate, "
                + t + ".status AS status, " + t + ".discount_from AS discountFrom, "
                + t + ".createdBy AS createdBy, " + t + ".createdAt AS createdAt, "
                + t + ".modifiedBy AS modifiedBy, " + t + ".modifiedAt AS modifiedAt, "
                + t + ".lote_id AS loteId";
    }

    private static String detalleCols(String t) {
        return t + ".id AS id, " + t + ".AbonoID AS abonoId, " + t + ".dues AS dues, "
                + t + ".monthly AS monthly, " + t + ".payment AS payment, "
                + t + ".paymentDate AS paymentDate, " + t + ".state AS state, "
                + t + ".createdBy AS createdBy, " + t + ".createdAt AS createdAt, "
                + t + ".modifiedBy AS modifiedBy, " + t + ".modifiedAt AS modifiedAt";
    }

    private static String conceptoCols(String t) {
        return t + ".ID AS id, " + t + ".codigo AS codigo, "
                + t + ".description AS description, " + t + ".sale_price AS salePrice, "
                + t + ".cost_price AS costPrice, " + t + ".priority AS priority, "
                + t + ".unid AS unid, " + t + ".priority_concept AS priorityConcept, "
                + t + ".createdBy AS createdBy, " + t + ".createdAt AS createdAt, "
                + t + ".modifiedBy AS modifiedBy, " + t + ".modifiedAt AS modifiedAt";
    }

    private static String loteCols(String t) {
        return t + ".id AS id, " + t + ".fecha_creacion AS fechaCreacion, "
                + t + ".usuario_id AS usuarioId, " + t + ".nombre_archivo AS nombreArchivo, "
                + t + ".cantidad_abonos AS cantidadAbonos, " + t + ".state AS state, "
                + t + ".motivo_reversion AS motivoReversion, "
                + t + ".fecha_reversion AS fechaReversion, "
                + t + ".revertido_por AS revertidoPor";
    }

    // â•â•â• AbonoDao â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * Renuncia de abono. Empty = no existe el SoliNum; true = paso a REN;
     * false = no habia cuota 'Pendiente' (ya pagado).
     */
    public Optional<Boolean> renunciarAbono(String soliNum, int modifiedBy, String modifiedAt) {
        Integer existe = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM abono WHERE SoliNum = :soli",
                new MapSqlParameterSource("soli", soliNum), Integer.class);
        if (existe == null || existe == 0) {
            return Optional.empty();
        }
        int rows = ftJdbc.update(
                "UPDATE abono SET status = 'REN', modifiedBy = :mb, modifiedAt = :ma "
                        + "WHERE SoliNum = :soli AND status = 'Pendiente'",
                new MapSqlParameterSource()
                        .addValue("mb", modifiedBy)
                        .addValue("ma", modifiedAt)
                        .addValue("soli", soliNum));
        return Optional.of(rows > 0);
    }

    /**
     * Borra el abono si ninguna cuota esta 'Pagado'/'Parcial'.
     * Empty = SoliNum no existe. Map: {borrado, motivo?}.
     */
    public Optional<Map<String, Object>> eliminarAbonoSiNoUsado(String soliNum) {
        List<Integer> ids = ftJdbc.queryForList(
                "SELECT ID FROM abono WHERE SoliNum = :soli",
                new MapSqlParameterSource("soli", soliNum), Integer.class);
        if (ids.isEmpty()) {
            return Optional.empty();
        }
        int abonoId = ids.get(0);
        Integer usados = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM abonodetail WHERE AbonoID = :id AND state IN ('Pagado', 'Parcial')",
                new MapSqlParameterSource("id", abonoId), Integer.class);

        Map<String, Object> out = new LinkedHashMap<>();
        if (usados != null && usados == 0) {
            int rows = ftJdbc.update("DELETE FROM abono WHERE ID = :id",
                    new MapSqlParameterSource("id", abonoId));
            out.put("borrado", rows > 0);
        } else {
            out.put("borrado", false);
            out.put("motivo", "TIENE_PAGOS");
        }
        return Optional.of(out);
    }

    /** Mismo COUNT que AbonoDao.hasPendingAbono (params como String). */
    public boolean tienePendiente(String employeeId, String conceptoId) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM abono WHERE Employee_id = :eid AND status = 'Pendiente' "
                        + "AND service_concept_id = :sci",
                new MapSqlParameterSource()
                        .addValue("eid", employeeId)
                        .addValue("sci", conceptoId),
                Integer.class);
        return count != null && count > 0;
    }

    /**
     * INSERT del abono con los valores que manda la app + UPDATE del SoliNum
     * al padding-8 del id generado (String.format("%08d", id), igual que el
     * updateSoliNum privado del DAO original).
     */
    public Integer insertarAbono(Map<String, Object> a) {
        String sql = "INSERT INTO abono (SoliNum, service_concept_id, Employee_id, dues, monthly, paymentDate, "
                + "status, discount_from, createdBy, createdAt, modifiedBy, modifiedAt, lote_id) "
                + "VALUES (:soliNum, :sci, :eid, :dues, :monthly, :paymentDate, "
                + ":status, :discountFrom, :createdBy, :createdAt, :modifiedBy, :modifiedAt, :loteId)";
        KeyHolder kh = new GeneratedKeyHolder();
        ftJdbc.update(sql, new MapSqlParameterSource()
                .addValue("soliNum", s(a, "soliNum"))
                .addValue("sci", s(a, "serviceConceptId"))
                .addValue("eid", s(a, "employeeId"))
                .addValue("dues", i(a, "dues"))
                .addValue("monthly", d(a, "monthly"))
                .addValue("paymentDate", s(a, "paymentDate"))
                .addValue("status", s(a, "status"))
                .addValue("discountFrom", s(a, "discountFrom"))
                .addValue("createdBy", i(a, "createdBy"))
                .addValue("createdAt", s(a, "createdAt"))
                .addValue("modifiedBy", i(a, "modifiedBy"))
                .addValue("modifiedAt", s(a, "modifiedAt"))
                .addValue("loteId", i(a, "loteId"), java.sql.Types.INTEGER),
                kh);
        Number key = kh.getKey();
        if (key == null) {
            throw new IllegalStateException("No se pudo obtener la clave primaria generada.");
        }
        int newId = key.intValue();
        ftJdbc.update("UPDATE abono SET SoliNum = :soli WHERE ID = :id",
                new MapSqlParameterSource()
                        .addValue("soli", String.format("%08d", newId))
                        .addValue("id", newId));
        return newId;
    }

    public boolean actualizarAbono(int id, Map<String, Object> a) {
        String sql = "UPDATE abono SET SoliNum = :soliNum, service_concept_id = :sci, Employee_id = :eid, "
                + "dues = :dues, monthly = :monthly, paymentDate = :paymentDate, status = :status, "
                + "discount_from = :discountFrom, createdBy = :createdBy, createdAt = :createdAt, "
                + "modifiedBy = :modifiedBy, modifiedAt = :modifiedAt WHERE ID = :id";
        int rows = ftJdbc.update(sql, new MapSqlParameterSource()
                .addValue("soliNum", s(a, "soliNum"))
                .addValue("sci", s(a, "serviceConceptId"))
                .addValue("eid", s(a, "employeeId"))
                .addValue("dues", i(a, "dues"))
                .addValue("monthly", d(a, "monthly"))
                .addValue("paymentDate", s(a, "paymentDate"))
                .addValue("status", s(a, "status"))
                .addValue("discountFrom", s(a, "discountFrom"))
                .addValue("createdBy", i(a, "createdBy"))
                .addValue("createdAt", s(a, "createdAt"))
                .addValue("modifiedBy", i(a, "modifiedBy"))
                .addValue("modifiedAt", s(a, "modifiedAt"))
                .addValue("id", id));
        return rows > 0;
    }

    public boolean eliminarAbono(int id) {
        return ftJdbc.update("DELETE FROM abono WHERE ID = :id",
                new MapSqlParameterSource("id", id)) > 0;
    }

    public Optional<Map<String, Object>> buscarAbonoPorId(int id) {
        List<Map<String, Object>> rows = ftJdbc.queryForList(
                "SELECT " + abonoCols("a") + " FROM abono a WHERE a.ID = :id",
                new MapSqlParameterSource("id", id));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    public List<Map<String, Object>> listarAbonos() {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + abonoCols("a") + " FROM abono a",
                new MapSqlParameterSource()));
    }

    /** Buckets aÃ±o/mes con total, para el combo de fechas disponibles. */
    public List<Map<String, Object>> fechasDisponibles(int conceptoId, String codigoEmpleado) {
        String sql = "SELECT YEAR(ab.CreatedAt) AS anio, MONTH(ab.CreatedAt) AS mes, COUNT(*) AS total "
                + "FROM financialtracker1.abono ab "
                + "LEFT JOIN financialtracker1.employees em ON em.employee_id = ab.Employee_id "
                + "WHERE ab.service_concept_id = :concepto "
                + "AND em.employment_status_code = :codigo "
                + "GROUP BY YEAR(ab.CreatedAt), MONTH(ab.CreatedAt) "
                + "ORDER BY anio DESC, mes DESC";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("concepto", conceptoId)
                .addValue("codigo", codigoEmpleado)));
    }

    public List<Map<String, Object>> abonosPorConceptoRango(int conceptoId, String codigoEmpleado,
                                                            String inicio, String fin) {
        String sql = "SELECT " + abonoCols("ab") + " FROM financialtracker1.abono ab "
                + "LEFT JOIN financialtracker1.employees em ON em.employee_id = ab.Employee_id "
                + "WHERE ab.service_concept_id = :concepto "
                + "AND em.employment_status_code = :codigo "
                + "AND DATE(ab.CreatedAt) BETWEEN :inicio AND :fin "
                + "ORDER BY ab.CreatedAt ASC";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("concepto", conceptoId)
                .addValue("codigo", codigoEmpleado)
                .addValue("inicio", inicio)
                .addValue("fin", fin)));
    }

    /** fecha nullable: con fecha filtra por YEAR/MONTH; sin fecha trae todos. */
    public List<Map<String, Object>> abonosPorConcepto(int conceptoId, String codigoEmpleado,
                                                       String fecha) {
        String sql;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("concepto", conceptoId)
                .addValue("codigo", codigoEmpleado);
        if (fecha != null) {
            sql = "SELECT " + abonoCols("ab") + " FROM financialtracker1.abono ab "
                    + "LEFT JOIN financialtracker1.employees em ON em.employee_id = ab.Employee_id "
                    + "WHERE ab.service_concept_id = :concepto "
                    + "AND em.employment_status_code = :codigo "
                    + "AND YEAR(ab.CreatedAt) = YEAR(:fecha) "
                    + "AND MONTH(ab.CreatedAt) = MONTH(:fecha) "
                    + "ORDER BY ab.CreatedAt ASC";
            params.addValue("fecha", fecha);
        } else {
            sql = "SELECT " + abonoCols("ab") + " FROM financialtracker1.abono ab "
                    + "LEFT JOIN financialtracker1.employees em ON em.employee_id = ab.Employee_id "
                    + "WHERE ab.service_concept_id = :concepto "
                    + "AND em.employment_status_code = :codigo "
                    + "ORDER BY ab.CreatedAt ASC";
        }
        return normalizar(ftJdbc.queryForList(sql, params));
    }

    public List<Map<String, Object>> abonosPorRango(String inicio, String fin) {
        String sql = "SELECT " + abonoCols("a") + " FROM abono a "
                + "WHERE DATE(a.CreatedAt) BETWEEN :inicio AND :fin ORDER BY a.CreatedAt ASC";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("inicio", inicio)
                .addValue("fin", fin)));
    }

    public List<Map<String, Object>> detallesPorSoliNum(String soliNum) {
        String sql = "SELECT " + detalleCols("abDe") + " FROM financialtracker1.abonodetail abDe "
                + "LEFT JOIN financialtracker1.abono bon ON abDe.AbonoID = bon.ID "
                + "WHERE bon.SoliNum = :soli";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("soli", soliNum)));
    }

    /** Mismo WHERE que findAbonosByEmployeeAndCurrentYear: status='Pendiente'. */
    public List<Map<String, Object>> abonosPendientesPorEmpleado(String employeeId) {
        String sql = "SELECT " + abonoCols("a") + " FROM abono a "
                + "WHERE a.Employee_id = :eid AND a.status = 'Pendiente'";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("eid", employeeId)));
    }

    public List<Map<String, Object>> ultimosAbonos(int limite) {
        String sql = "SELECT " + abonoCols("a") + " FROM abono a ORDER BY a.ID DESC LIMIT :lim";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("lim", limite)));
    }

    public List<String> listarSoliNums() {
        List<String> soliNums = ftJdbc.queryForList(
                "SELECT SoliNum FROM abono WHERE SoliNum IS NOT NULL ORDER BY ID DESC",
                new MapSqlParameterSource(), String.class);
        // El DAO original tambien descarta los blank en Java
        return soliNums.stream()
                .filter(sn -> sn != null && !sn.isBlank())
                .toList();
    }

    // â•â•â• AbonoDetailsDao â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * Aplica un pago (parcial o total) a una cuota y, si todas quedan
     * 'Pagado', marca el abono 'Pagado'. Multi-paso: transaccion manual
     * sobre el DataSource de FT. Replica updateLoanStateByLoandetailId.
     */
    public void aplicarPagoDetalle(long detalleId, double monthlyFeeValue, double newPayment) {
        String findLoanIdQuery = "SELECT AbonoID , payment FROM abonodetail WHERE id = ?";
        String updateLoandetailStateQuery = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
        String findLoandetailsStateQuery = "SELECT state FROM abonodetail WHERE AbonoID = ?";
        String updateLoanStateQuery = "UPDATE abono SET status = ? WHERE ID = ?";

        try (Connection connection = ftDataSource.getConnection()) {
            boolean prevAuto = connection.getAutoCommit();
            try {
                connection.setAutoCommit(false);
                try (PreparedStatement stmtFindLoanId = connection.prepareStatement(findLoanIdQuery);
                     PreparedStatement stmtUpdateLoandetail = connection.prepareStatement(updateLoandetailStateQuery);
                     PreparedStatement stmtFindLoandetailsState = connection.prepareStatement(findLoandetailsStateQuery);
                     PreparedStatement stmtUpdateLoan = connection.prepareStatement(updateLoanStateQuery)) {

                    stmtFindLoanId.setLong(1, detalleId);
                    ResultSet rsLoanId = stmtFindLoanId.executeQuery();

                    if (rsLoanId.next()) {
                        int loanId = rsLoanId.getInt("AbonoID");
                        double currentPayment = rsLoanId.getDouble("payment");

                        double totalPayment = currentPayment + newPayment;
                        String loandetailState = totalPayment == monthlyFeeValue ? "Pagado" : "Parcial";

                        stmtUpdateLoandetail.setDouble(1, totalPayment);
                        stmtUpdateLoandetail.setString(2, loandetailState);
                        stmtUpdateLoandetail.setLong(3, detalleId);
                        stmtUpdateLoandetail.executeUpdate();

                        stmtFindLoandetailsState.setInt(1, loanId);
                        ResultSet rsLoandetailsState = stmtFindLoandetailsState.executeQuery();

                        boolean allPaid = true;
                        while (rsLoandetailsState.next()) {
                            if (!"Pagado".equals(rsLoandetailsState.getString("state"))) {
                                allPaid = false;
                                break;
                            }
                        }

                        if (allPaid) {
                            stmtUpdateLoan.setString(1, "Pagado");
                            stmtUpdateLoan.setInt(2, loanId);
                            stmtUpdateLoan.executeUpdate();
                        }
                    }
                }
                connection.commit();
            } catch (SQLException ex) {
                connection.rollback();
                throw ex;
            } finally {
                connection.setAutoCommit(prevAuto);
            }
        } catch (SQLException ex) {
            throw new IllegalStateException(
                    "Error aplicando pago en FinantialTracker: " + ex.getMessage(), ex);
        }
    }

    public List<Map<String, Object>> listarDetalles() {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + detalleCols("d") + " FROM abonodetail d",
                new MapSqlParameterSource()));
    }

    /**
     * Genera las N cuotas de un abono. Replica insertAbonoDetail del DAO:
     * paymentDate = ultimo dia del mes, avanzando mes a mes; payment=0;
     * state='Pendiente'; createdAt = LocalDate.now(); modified vacios.
     */
    public void insertarDetalles(int abonoId, int dues, double monthly,
                                 String paymentDate, int usuario) {
        String sql = "INSERT INTO abonodetail (AbonoID, dues, monthly, payment, paymentDate, state, "
                + "createdBy, createdAt, modifiedBy, modifiedAt) "
                + "VALUES (:aid, :dues, :monthly, :payment, :pdate, :state, :cb, :ca, :mb, :ma)";

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        LocalDate currentDate = LocalDate.parse(paymentDate, formatter);

        for (int i = 0; i < dues; i++) {
            LocalDate lastDayOfMonth = currentDate.withDayOfMonth(currentDate.lengthOfMonth());
            ftJdbc.update(sql, new MapSqlParameterSource()
                    .addValue("aid", abonoId)
                    .addValue("dues", i + 1)
                    .addValue("monthly", monthly)
                    .addValue("payment", 0.0)
                    .addValue("pdate", lastDayOfMonth.toString())
                    .addValue("state", "Pendiente")
                    .addValue("cb", String.valueOf(usuario))
                    .addValue("ca", LocalDate.now().toString())
                    .addValue("mb", "")
                    .addValue("ma", ""));
            currentDate = currentDate.plusMonths(1);
        }
    }

    /** Historial de una cuota con la descripcion del concepto (join). */
    public List<Map<String, Object>> historialDetalle(int detalleId) {
        String sql = "SELECT serv.description AS description, abDet.payment AS payment, "
                + "ab.dues AS abonoDues, abDet.dues AS abonodetailDues, "
                + "abDet.monthly AS monthly, abDet.paymentDate AS paymentDate "
                + "FROM financialtracker1.abonodetail abDet "
                + "LEFT JOIN financialtracker1.abono ab ON ab.ID = abDet.AbonoID "
                + "LEFT JOIN financialtracker1.service_concept serv ON serv.ID = ab.service_concept_id "
                + "WHERE abDet.id = :id";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("id", detalleId)));
    }

    public List<Map<String, Object>> detallesPorAbonoId(int abonoId) {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + detalleCols("d") + " FROM abonodetail d WHERE d.AbonoID = :aid",
                new MapSqlParameterSource("aid", abonoId)));
    }

    // â•â•â• LoteCargaAbonoDao â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /** Crea un lote ACTIVO con la fecha/usuario que manda la app. */
    public Integer crearLote(String fechaCreacion, Integer usuarioId,
                             String nombreArchivo, int cantidadAbonos) {
        String sql = "INSERT INTO lote_carga_abono "
                + "(fecha_creacion, usuario_id, nombre_archivo, cantidad_abonos, state) "
                + "VALUES (:fecha, :usuario, :nombre, :cantidad, 'ACTIVO')";
        String fecha = fechaCreacion;
        if (fecha == null || fecha.isBlank()) {
            fecha = LocalDateTime.now().format(FECHA_HORA);
        }
        KeyHolder kh = new GeneratedKeyHolder();
        int rows = ftJdbc.update(sql, new MapSqlParameterSource()
                .addValue("fecha", fecha)
                .addValue("usuario", usuarioId, java.sql.Types.INTEGER)
                .addValue("nombre", nombreArchivo)
                .addValue("cantidad", cantidadAbonos),
                kh);
        if (rows == 0) {
            return null;
        }
        Number key = kh.getKey();
        return key == null ? null : key.intValue();
    }

    public void actualizarCantidadLote(int loteId, int cantidad) {
        ftJdbc.update("UPDATE lote_carga_abono SET cantidad_abonos = :cantidad WHERE id = :id",
                new MapSqlParameterSource()
                        .addValue("cantidad", cantidad)
                        .addValue("id", loteId));
    }

    public List<Map<String, Object>> lotesActivos() {
        String sql = "SELECT " + loteCols("l") + " FROM lote_carga_abono l "
                + "WHERE l.state = 'ACTIVO' "
                + "ORDER BY l.fecha_creacion DESC "
                + "LIMIT 50";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()));
    }

    /**
     * Cuenta abonos del lote con pagos ('Pagado'/'Parcial').
     * OJO: se replica el join con ad.Abono_id tal cual el DAO original
     * (LoteCargaAbonoDao.countAbonosUsados) para mantener paridad exacta.
     */
    public int contarAbonosUsados(int loteId) {
        String sql = "SELECT COUNT(DISTINCT a.id) "
                + "FROM abono a "
                + "JOIN abonodetail ad ON ad.Abono_id = a.id "
                + "WHERE a.lote_id = :id "
                + "AND (ad.state = 'Pagado' OR ad.state = 'Parcial')";
        Integer count = ftJdbc.queryForObject(sql,
                new MapSqlParameterSource("id", loteId), Integer.class);
        return count == null ? 0 : count;
    }

    /**
     * Revierte un lote completo en una transaccion manual (mismo flujo y
     * mismo SQL que LoteCargaAbonoDao.revertirLote): libera abonos con
     * pagos, borra detalles y abonos restantes, marca lote REVERTIDO.
     * Devuelve cuantos abonos se borraron.
     */
    public int revertirLote(int loteId, int usuarioId, String motivo) {
        try (Connection connection = ftDataSource.getConnection()) {
            boolean prevAuto = connection.getAutoCommit();
            try {
                connection.setAutoCommit(false);

                // 1. Liberar abonos del lote que ya tengan pagos: poner lote_id = NULL
                String sqlSepararUsados =
                        "UPDATE abono SET lote_id = NULL "
                        + "WHERE lote_id = ? AND id IN ("
                        + "  SELECT * FROM (SELECT a.id FROM abono a "
                        + "    JOIN abonodetail ad ON ad.Abono_id = a.id "
                        + "    WHERE a.lote_id = ? AND (ad.state = 'Pagado' OR ad.state = 'Parcial')"
                        + "  ) t)";
                try (PreparedStatement stmt = connection.prepareStatement(sqlSepararUsados)) {
                    stmt.setInt(1, loteId);
                    stmt.setInt(2, loteId);
                    stmt.executeUpdate();
                }

                // 2. Borrar abonodetails de los abonos que aun pertenecen al lote
                String sqlDeleteDetails =
                        "DELETE ad FROM abonodetail ad "
                        + "JOIN abono a ON ad.Abono_id = a.id "
                        + "WHERE a.lote_id = ?";
                try (PreparedStatement stmt = connection.prepareStatement(sqlDeleteDetails)) {
                    stmt.setInt(1, loteId);
                    stmt.executeUpdate();
                }

                // 3. Borrar los abonos del lote
                int abonosBorrados;
                String sqlDeleteAbonos = "DELETE FROM abono WHERE lote_id = ?";
                try (PreparedStatement stmt = connection.prepareStatement(sqlDeleteAbonos)) {
                    stmt.setInt(1, loteId);
                    abonosBorrados = stmt.executeUpdate();
                }

                // 4. Marcar el lote como REVERTIDO
                String sqlUpdateLote =
                        "UPDATE lote_carga_abono SET state = 'REVERTIDO', "
                        + "motivo_reversion = ?, fecha_reversion = ?, revertido_por = ? "
                        + "WHERE id = ?";
                try (PreparedStatement stmt = connection.prepareStatement(sqlUpdateLote)) {
                    stmt.setString(1, motivo);
                    stmt.setTimestamp(2, Timestamp.valueOf(LocalDateTime.now()));
                    stmt.setInt(3, usuarioId);
                    stmt.setInt(4, loteId);
                    stmt.executeUpdate();
                }

                connection.commit();
                return abonosBorrados;
            } catch (SQLException ex) {
                connection.rollback();
                throw ex;
            } finally {
                connection.setAutoCommit(prevAuto);
            }
        } catch (SQLException ex) {
            throw new IllegalStateException(
                    "Error revirtiendo lote en FinantialTracker: " + ex.getMessage(), ex);
        }
    }

    // â•â•â• ServiceConceptDao â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * INSERT del concepto con ID explicito, igual que ServiceConceptDao.insert
     * (el DAO original NO inserta la columna codigo).
     */
    public void insertarConcepto(Map<String, Object> c) {
        String sql = "INSERT INTO service_concept (ID, description, sale_price, cost_price, priority, unid, "
                + "priority_concept, createdBy, createdAt, modifiedBy, modifiedAt) "
                + "VALUES (:id, :description, :salePrice, :costPrice, :priority, :unid, "
                + ":priorityConcept, :createdBy, :createdAt, :modifiedBy, :modifiedAt)";
        ftJdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", i(c, "id"))
                .addValue("description", s(c, "description"))
                .addValue("salePrice", d(c, "salePrice"))
                .addValue("costPrice", d(c, "costPrice"))
                .addValue("priority", i(c, "priority"))
                .addValue("unid", i(c, "unid"))
                .addValue("priorityConcept", s(c, "priorityConcept"))
                .addValue("createdBy", i(c, "createdBy"))
                .addValue("createdAt", s(c, "createdAt"))
                .addValue("modifiedBy", i(c, "modifiedBy"))
                .addValue("modifiedAt", s(c, "modifiedAt")));
    }

    /**
     * Borra el concepto si no esta referenciado en abono.
     * Empty = codigo no existe. Map: {borrado, motivo?}.
     */
    public Optional<Map<String, Object>> eliminarConceptoSiNoUsado(String codigo) {
        List<Integer> ids = ftJdbc.queryForList(
                "SELECT ID FROM service_concept WHERE codigo = :codigo",
                new MapSqlParameterSource("codigo", codigo), Integer.class);
        if (ids.isEmpty()) {
            return Optional.empty();
        }
        int conceptoId = ids.get(0);
        Integer usados = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM abono WHERE service_concept_id = :id",
                new MapSqlParameterSource("id", conceptoId), Integer.class);

        Map<String, Object> out = new LinkedHashMap<>();
        if (usados != null && usados == 0) {
            int rows = ftJdbc.update("DELETE FROM service_concept WHERE ID = :id",
                    new MapSqlParameterSource("id", conceptoId));
            out.put("borrado", rows > 0);
        } else {
            out.put("borrado", false);
            out.put("motivo", "REFERENCIADO");
        }
        return Optional.of(out);
    }

    public Optional<Map<String, Object>> buscarConceptoPorCodigo(String codigo) {
        String sql = "SELECT " + conceptoCols("c") + " FROM service_concept c "
                + "WHERE c.codigo = :codigo ORDER BY c.ID ASC LIMIT 1";
        List<Map<String, Object>> rows = ftJdbc.queryForList(sql,
                new MapSqlParameterSource("codigo", codigo));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    /** Catalogo completo (todas las columnas), a diferencia del GET resumido. */
    public List<Map<String, Object>> listarConceptosCompletos() {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + conceptoCols("c") + " FROM service_concept c",
                new MapSqlParameterSource()));
    }

    /**
     * codigo + description de todos los conceptos, para el autocompletado
     * (SQL exacto de ServiceConceptDao.getAllConceptDescriptions; el filtro
     * de blancos y el formato "codigo - descripcion" quedan en la app).
     */
    public List<Map<String, Object>> codigosYDescripciones() {
        return normalizar(ftJdbc.queryForList(
                "SELECT codigo, description FROM service_concept ORDER BY codigo ASC",
                new MapSqlParameterSource()));
    }

    // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    private static String s(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v == null ? null : String.valueOf(v);
    }

    private static Integer i(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return null;
        if (v instanceof Number n) return n.intValue();
        return Integer.valueOf(v.toString());
    }

    private static Double d(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return null;
        if (v instanceof Number n) return n.doubleValue();
        return Double.valueOf(v.toString());
    }

    /**
     * Las fechas en FT son varchar "yyyy-MM-dd...", pero por si alguna
     * columna llega como DATE/TIMESTAMP se normaliza a texto plano para que
     * el JSON conserve el mismo formato que veia el rs.getString() del DAO.
     */
    private static Object valorPlano(Object v) {
        if (v instanceof Timestamp t) return t.toLocalDateTime().format(FECHA_HORA);
        if (v instanceof java.sql.Date d) return d.toLocalDate().toString();
        if (v instanceof LocalDateTime ldt) return ldt.format(FECHA_HORA);
        if (v instanceof LocalDate ld) return ld.toString();
        return v;
    }

    private static Map<String, Object> normalizarFila(Map<String, Object> fila) {
        fila.replaceAll((k, v) -> valorPlano(v));
        return fila;
    }

    private static List<Map<String, Object>> normalizar(List<Map<String, Object>> filas) {
        for (Map<String, Object> fila : filas) {
            normalizarFila(fila);
        }
        return filas;
    }
}
