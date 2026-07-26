package com.thiago.gestionbodega.modules.integracion.ft.prestamos;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Acceso JDBC a la BD financialtracker1 para el modulo de PRESTAMOS.
 *
 * Replica EXACTAMENTE el SQL de los DAOs originales de la app Swing
 * FinantialTracker (LoanDao y LoanDetailsDao) â€” mismos WHERE, mismos estados
 * 'Pendiente'/'Aceptado'/'Refinanciado'/'Pagado'/'pendiente'/'parcial', mismo
 * padding-8 del SoliNum (String.format("%08d", id)) â€” para que la app pueda
 * consumir estos endpoints o caer a su JDBC directo sin cambios de
 * comportamiento. Los SELECT * del DAO se materializan con alias camelCase
 * deterministas (mismo precedente que FtAbonosRepository) para que los labels
 * del JSON sean estables.
 *
 * OJO: loan.EmployeeID guarda el DNI (employees.national_id), NO el id
 * numerico (asi lo inserta ModelManageLoan en la app Swing).
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier} sobre
 * un campo con {@code @RequiredArgsConstructor} NO se propaga al constructor
 * generado (ver FinancialTrackerRepository).
 */
@Repository
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true")
public class FtPrestamosRepository {

    private final NamedParameterJdbcTemplate ftJdbc;
    private final DataSource ftDataSource;

    public FtPrestamosRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc,
            @Qualifier("financialTrackerDataSource") DataSource ftDataSource) {
        this.ftJdbc = ftJdbc;
        this.ftDataSource = ftDataSource;
    }

    private static final DateTimeFormatter FECHA_HORA =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    // â”€â”€â”€ Columnas con alias deterministas (los labels llegan tal cual al JSON) â”€â”€

    /** Equivalente al SELECT * FROM loan de los DAOs, con alias estables. */
    private static String loanCols() {
        return "ID AS id, SoliNum AS soliNum, EmployeeID AS employeeId, "
                + "GuarantorId AS guarantorId, RequestedAmount AS requestedAmount, "
                + "AmountWithdrawn AS amountWithdrawn, Dues AS dues, "
                + "PaymentDate AS paymentDate, State AS state, StateLoan AS stateLoan, "
                + "RefinanceParentID AS refinanceParentId, CreatedBy AS createdBy, "
                + "CreatedAt AS createdAt, ModifiedAt AS modifiedAt, "
                + "ModifiedBy AS modifiedBy, Type AS type, "
                + "PaymentResponsibility AS paymentResponsibility";
    }

    /** Columnas de loandetail (misma lista que getAllLoanDetails). */
    private static String detalleCols() {
        return "ID AS id, LoanID AS loanId, Dues AS dues, TotalInterest AS totalInterest, "
                + "TotalIntangibleFund AS totalIntangibleFund, "
                + "MonthlyCapitalInstallment AS monthlyCapitalInstallment, "
                + "MonthlyInterestFee AS monthlyInterestFee, "
                + "MonthlyIntangibleFundFee AS monthlyIntangibleFundFee, "
                + "MonthlyFeeValue AS monthlyFeeValue, payment AS payment, "
                + "PaymentDate AS paymentDate, State AS state, CreatedBy AS createdBy, "
                + "CreatedAt AS createdAt, ModifiedBy AS modifiedBy, ModifiedAt AS modifiedAt";
    }

    /**
     * SELECT del "resumen" de prestamos (searchLoan / getLastLoans /
     * getAllLoanss del LoanDao): joins a employees por DNI y a la primera
     * cuota (MIN(ID)) de loandetail, mas el subquery de monto refinanciado.
     */
    private static final String RESUMEN_SELECT = "SELECT \n"
            + "    l.ID AS id, l.ModifiedAt AS modifiedAt, l.SoliNum AS soliNum, \n"
            + "    e1.fullName AS solicitorName, \n"
            + "    e2.fullName AS guarantorName, \n"
            + "    (SELECT SUM(MonthlyFeeValue - IFNULL(payment, 0)) \n"
            + "     FROM loandetail \n"
            + "     WHERE LoanID = l.RefinanceParentID AND State IN ('pendiente', 'parcial') \n"
            + "     GROUP BY LoanID) AS refinanciado,\n"
            + "    l.RequestedAmount AS requestedAmount, l.AmountWithdrawn AS amountWithdrawn,\n"
            + "    l.Dues AS dues,\n"
            + "    dd.TotalInterest AS totalInterest,\n"
            + "    dd.TotalIntangibleFund AS totalIntangibleFund,\n"
            + "    dd.MonthlyCapitalInstallment AS monthlyCapitalInstallment,\n"
            + "    dd.MonthlyInterestFee AS monthlyInterestFee,\n"
            + "    dd.MonthlyIntangibleFundFee AS monthlyIntangibleFundFee,\n"
            + "    dd.MonthlyFeeValue AS monthlyFeeValue,\n"
            + "    l.State AS state, l.PaymentResponsibility AS paymentResponsibility \n"
            + "FROM loan l \n"
            + "LEFT JOIN employees e1 ON l.EmployeeID = e1.national_id \n"
            + "LEFT JOIN employees e2 ON l.GuarantorId = e2.national_id\n"
            + "LEFT JOIN (\n"
            + "    SELECT ld.* \n"
            + "    FROM loandetail ld \n"
            + "    WHERE ld.ID = (SELECT MIN(ID) FROM loandetail WHERE LoanID = ld.LoanID) \n"
            + ") dd ON dd.LoanID = l.ID \n";

    // â•â•â• LoanDao â€” lecturas â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /** LoanDao.getAllSoliNums: mismo ORDER y mismo filtro null/empty en Java. */
    public List<String> listarSoliNums() {
        List<String> soliNums = ftJdbc.queryForList(
                "SELECT SoliNum FROM loan ORDER BY SoliNum DESC",
                new MapSqlParameterSource(), String.class);
        List<String> out = new ArrayList<>();
        for (String num : soliNums) {
            if (num != null && !num.isEmpty()) {
                out.add(num);
            }
        }
        return out;
    }

    /** LoanDao.findLoansByEmployeeId: solicitante o garante, Aceptado+Pendiente. */
    public List<Map<String, Object>> prestamosPorEmpleado(String employeeId) {
        String sql = "SELECT " + loanCols() + " FROM loan WHERE State = 'Aceptado' AND StateLoan = 'Pendiente' "
                + "AND ( (PaymentResponsibility = 'EMPLOYEE' AND EmployeeID = :eid) "
                + "OR (PaymentResponsibility = 'GUARANTOR' AND GuarantorId = :eid) )";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("eid", employeeId)));
    }

    /** LoanDao.getAllLoans: SELECT * FROM loan. */
    public List<Map<String, Object>> listarPrestamos() {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + loanCols() + " FROM loan",
                new MapSqlParameterSource()));
    }

    /** LoanDao.getLoansByDateRange: CreatedAt BETWEEN, orden ASC. */
    public List<Map<String, Object>> prestamosPorRango(String inicio, String fin) {
        String sql = "SELECT " + loanCols()
                + " FROM loan WHERE CreatedAt BETWEEN :inicio AND :fin ORDER BY CreatedAt ASC";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("inicio", inicio)
                .addValue("fin", fin)));
    }

    /** LoanDao.searchLoan: resumen por numero de solicitud. */
    public List<Map<String, Object>> resumenPorSoli(String soliNum) {
        String sql = RESUMEN_SELECT + "WHERE l.SoliNum = :soli";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("soli", soliNum)));
    }

    /** LoanDao.getLastLoans: ultimos N sin filtro de fecha. */
    public List<Map<String, Object>> resumenUltimos(int limite) {
        String sql = RESUMEN_SELECT + "ORDER BY l.ID DESC LIMIT :lim";
        return normalizar(ftJdbc.queryForList(sql,
                new MapSqlParameterSource("lim", limite)));
    }

    /** LoanDao.getAllLoanss: resumen con DATE(l.CreatedAt) BETWEEN. */
    public List<Map<String, Object>> resumenPorRango(String inicio, String fin) {
        String sql = RESUMEN_SELECT + "WHERE DATE(l.CreatedAt) BETWEEN :inicio AND :fin ORDER BY l.ID DESC";
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("inicio", inicio)
                .addValue("fin", fin)));
    }

    /** LoanDao.fillLoanTable: filas para la JTable de listado. */
    public List<Map<String, Object>> tablaPrestamos() {
        String sql = """
             SELECT
                 l.ID AS id,
                 l.SoliNum AS soliNum,
                 e1.fullName AS solicitorName,
                 e2.fullName AS guarantorName,
                 l.RequestedAmount AS requestedAmount,
                 l.AmountWithdrawn AS amountWithdrawn,
                 l.State AS state,
                 l.PaymentResponsibility AS paymentResponsibility
             FROM loan l
             LEFT JOIN employees e1 ON l.EmployeeID = e1.national_id
             LEFT JOIN employees e2 ON l.GuarantorId = e2.national_id
         """;
        return normalizar(ftJdbc.queryForList(sql, new MapSqlParameterSource()));
    }

    /** LoanDao.hasLoanInState (helper de createLoanWithStateValidation). */
    public boolean tienePrestamoEnEstado(String employeeId, String state) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM loan WHERE StateLoan = 'Pendiente' AND PaymentResponsibility = 'EMPLOYEE' "
                        + "AND EmployeeID = :eid AND State = :state",
                new MapSqlParameterSource()
                        .addValue("eid", employeeId)
                        .addValue("state", state),
                Integer.class);
        return count != null && count > 0;
    }

    /** LoanDao.findLatestLoanByState (helper de createLoanWithStateValidation). */
    public Optional<Map<String, Object>> prestamoActivo(String employeeId, String state) {
        String sql = "SELECT " + loanCols() + " \n"
                + "FROM `loan` \n"
                + "WHERE `EmployeeID` = :eid \n"
                + "  AND `State` = :state \n"
                + "  AND `StateLoan` = 'Pendiente' \n"
                + "AND  `RefinanceParentID` IS NULL AND PaymentResponsibility = 'EMPLOYEE'\n"
                + "ORDER BY `CreatedAt` DESC LIMIT 1";
        List<Map<String, Object>> rows = ftJdbc.queryForList(sql, new MapSqlParameterSource()
                .addValue("eid", employeeId)
                .addValue("state", state));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    /** LoanDao.findLoan(int idLoan). */
    public Optional<Map<String, Object>> buscarPorId(int idLoan) {
        String sql = "SELECT " + loanCols()
                + " FROM loan WHERE ID = :id  ORDER BY CreatedAt DESC LIMIT 1";
        List<Map<String, Object>> rows = ftJdbc.queryForList(sql,
                new MapSqlParameterSource("id", idLoan));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    /** LoanDao.findLoan(String numSoli). */
    public Optional<Map<String, Object>> buscarPorSoli(String numSoli) {
        String sql = "SELECT " + loanCols()
                + " FROM loan WHERE SoliNum = :soli  ORDER BY CreatedAt DESC LIMIT 1";
        List<Map<String, Object>> rows = ftJdbc.queryForList(sql,
                new MapSqlParameterSource("soli", numSoli));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    // â•â•â• LoanDao â€” escrituras â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * LoanDao.updatePaymentResponsibility: valida aval y estados, y solo
     * entonces pasa PaymentResponsibility a 'GUARANTOR'. Empty = el SoliNum
     * no existe. Map: {resultado: SIN_AVAL|NO_CUMPLE|ACTUALIZADO,
     * actualizado: bool} â€” los dialogos los muestra la app Swing.
     */
    public Optional<Map<String, Object>> cambiarResponsabilidadPago(String soliNum) {
        List<Map<String, Object>> rows = ftJdbc.queryForList(
                "SELECT GuarantorId AS guarantorId, State AS state, StateLoan AS stateLoan "
                        + "FROM loan WHERE SoliNum = :soli",
                new MapSqlParameterSource("soli", soliNum));
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        Map<String, Object> fila = rows.get(0);
        String guarantorId = fila.get("guarantorId") == null ? null : fila.get("guarantorId").toString();
        String state = fila.get("state") == null ? null : fila.get("state").toString();
        String stateLoan = fila.get("stateLoan") == null ? null : fila.get("stateLoan").toString();

        Map<String, Object> out = new LinkedHashMap<>();
        if (guarantorId == null || guarantorId.trim().isEmpty()) {
            out.put("resultado", "SIN_AVAL");
            out.put("actualizado", false);
            return Optional.of(out);
        }
        if (!"Aceptado".equals(state) || !"Pendiente".equals(stateLoan)) {
            out.put("resultado", "NO_CUMPLE");
            out.put("actualizado", false);
            return Optional.of(out);
        }
        int rowsUpdated = ftJdbc.update(
                "UPDATE loan SET PaymentResponsibility = 'GUARANTOR' WHERE SoliNum = :soli",
                new MapSqlParameterSource("soli", soliNum));
        out.put("resultado", "ACTUALIZADO");
        out.put("actualizado", rowsUpdated > 0);
        return Optional.of(out);
    }

    /**
     * LoanDetailsDao.updatePaymentResponsibilityToGuarantor: pase directo (sin
     * validaciones) a 'GUARANTOR' con ModifiedAt = NOW().
     */
    public int pasarResponsabilidadAval(String soli) {
        return ftJdbc.update(
                "UPDATE loan SET PaymentResponsibility = 'GUARANTOR', ModifiedAt = NOW() WHERE SoliNum = :soli",
                new MapSqlParameterSource("soli", soli));
    }

    /**
     * Flujo de insercion de LoanDao.createLoanWithStateValidation ya resuelto
     * por la app (dialogos y montos son client-side): en UNA transaccion
     * replica handleRefinancing (UPDATE del prestamo padre a
     * Refinanciado/Pagado, solo si refinanciarLoanId != null) + insertNewLoan
     * (INSERT con StateLoan='Pendiente') + updateSoliNum (SoliNum = %08d del
     * id generado). Devuelve {id, soliNum}.
     */
    public Map<String, Object> crearPrestamo(String employeeId, String guarantorId,
            Double requestedAmount, Double amountWithdrawn, int dues, String paymentDate,
            String state, Integer refinanceParentId, int createdBy, String createdAt,
            String modifiedAt, Integer modifiedBy, String type, String paymentResponsibility,
            Integer refinanciarLoanId) {

        String updateParentSql = "UPDATE loan SET State = 'Refinanciado' , StateLoan = 'Pagado' WHERE ID = ?";
        String insertSql = "INSERT INTO loan ("
                + "EmployeeID, GuarantorId, RequestedAmount, AmountWithdrawn, Dues, PaymentDate, "
                + "State, StateLoan, RefinanceParentID, CreatedBy, CreatedAt, ModifiedAt, ModifiedBy, Type, PaymentResponsibility"
                + ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        String updateSoliSql = "UPDATE loan SET SoliNum = ? WHERE ID = ?";

        try (Connection connection = ftDataSource.getConnection()) {
            boolean prevAuto = connection.getAutoCommit();
            try {
                connection.setAutoCommit(false);

                Integer refinanceId = refinanceParentId;
                if (refinanciarLoanId != null) {
                    try (PreparedStatement stmt = connection.prepareStatement(updateParentSql)) {
                        stmt.setInt(1, refinanciarLoanId);
                        stmt.executeUpdate();
                    }
                    refinanceId = refinanciarLoanId;
                }

                int newId;
                try (PreparedStatement stmt = connection.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS)) {
                    // mismos valores/defaults que LoanDao.setInsertParameters
                    stmt.setString(1, employeeId);
                    stmt.setString(2, guarantorId);
                    stmt.setDouble(3, requestedAmount != null ? requestedAmount : 0.0);
                    stmt.setDouble(4, amountWithdrawn != null ? amountWithdrawn : 0.0);
                    stmt.setInt(5, dues);
                    stmt.setDate(6, Date.valueOf(paymentDate));
                    stmt.setString(7, state);
                    stmt.setString(8, "Pendiente");
                    stmt.setObject(9, refinanceId, Types.INTEGER);
                    stmt.setInt(10, createdBy);
                    stmt.setDate(11, Date.valueOf(createdAt));
                    stmt.setTimestamp(12, modifiedAt != null
                            ? Timestamp.valueOf(LocalDateTime.parse(modifiedAt, FECHA_HORA))
                            : null);
                    stmt.setObject(13, modifiedBy, Types.INTEGER);
                    stmt.setString(14, type);
                    stmt.setString(15, paymentResponsibility != null ? paymentResponsibility : "EMPLOYEE");
                    stmt.executeUpdate();
                    try (ResultSet generatedKeys = stmt.getGeneratedKeys()) {
                        if (!generatedKeys.next()) {
                            throw new SQLException("Error al obtener ID generado");
                        }
                        newId = generatedKeys.getInt(1);
                    }
                }

                String soliNum = String.format("%08d", newId);
                try (PreparedStatement stmt = connection.prepareStatement(updateSoliSql)) {
                    stmt.setString(1, soliNum);
                    stmt.setInt(2, newId);
                    stmt.executeUpdate();
                }

                connection.commit();
                Map<String, Object> out = new LinkedHashMap<>();
                out.put("id", newId);
                out.put("soliNum", soliNum);
                return out;
            } catch (SQLException ex) {
                connection.rollback();
                throw ex;
            } finally {
                connection.setAutoCommit(prevAuto);
            }
        } catch (SQLException ex) {
            throw new IllegalStateException(
                    "Error creando prestamo en FinantialTracker: " + ex.getMessage(), ex);
        }
    }

    /**
     * LoanDao.updateSoliNumStatus: transaccion padre/hijo de refinanciamiento.
     * Actualiza el prestamo del SoliNum y, si el estado es 'Denegado',
     * regresa el prestamo refinanciado (RefinanceParentId) a
     * Aceptado/Pendiente. Devuelve false si el SoliNum no existe.
     */
    public boolean actualizarEstadoPrestamo(String soliNum, String status, int userModifi) {
        String selectSql = "SELECT RefinanceParentId FROM loan WHERE SoliNum = ?";
        String updateParentSql = "UPDATE loan SET State = ?, ModifiedAt = ?, ModifiedBy = ? WHERE SoliNum = ?";
        String updateChildSql = "UPDATE loan SET State = ?, StateLoan = ?, ModifiedAt = ?, ModifiedBy = ? WHERE Id = ?";

        try (Connection connection = ftDataSource.getConnection()) {
            boolean prevAuto = connection.getAutoCommit();
            try {
                connection.setAutoCommit(false);
                try (PreparedStatement stmtSelect = connection.prepareStatement(selectSql);
                     PreparedStatement stmtUpdateParent = connection.prepareStatement(updateParentSql);
                     PreparedStatement stmtUpdateChild = connection.prepareStatement(updateChildSql)) {

                    // 1. Buscar el prestamo principal
                    stmtSelect.setString(1, soliNum);
                    ResultSet rs = stmtSelect.executeQuery();
                    if (!rs.next()) {
                        connection.rollback();
                        return false;
                    }
                    int parentId = rs.getInt("RefinanceParentId");

                    // 2. Actualizar prestamo principal
                    stmtUpdateParent.setString(1, status);
                    stmtUpdateParent.setTimestamp(2, Timestamp.valueOf(LocalDateTime.now()));
                    stmtUpdateParent.setInt(3, userModifi);
                    stmtUpdateParent.setString(4, soliNum);
                    stmtUpdateParent.executeUpdate();

                    // 3. Si es 'Denegado', reactivar el prestamo refinanciado
                    if (status.equalsIgnoreCase("Denegado")) {
                        stmtUpdateChild.setString(1, "Aceptado");
                        stmtUpdateChild.setString(2, "Pendiente");
                        stmtUpdateChild.setTimestamp(3, Timestamp.valueOf(LocalDateTime.now()));
                        stmtUpdateChild.setInt(4, userModifi);
                        stmtUpdateChild.setInt(5, parentId);
                        stmtUpdateChild.executeUpdate();
                    }
                }
                connection.commit();
                return true;
            } catch (SQLException ex) {
                connection.rollback();
                throw ex;
            } finally {
                connection.setAutoCommit(prevAuto);
            }
        } catch (SQLException ex) {
            throw new IllegalStateException(
                    "Error actualizando estado del prestamo en FinantialTracker: " + ex.getMessage(), ex);
        }
    }

    // â•â•â• LoanDetailsDao â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * LoanDetailsDao.updateLoanStateByLoandetailId: aplica un pago (parcial o
     * total) a la cuota y, si todas quedan 'Pagado', marca el loan 'Pagado'.
     * Multi-paso: transaccion manual sobre el DataSource de FT.
     */
    public void aplicarPagoDetalle(long loandetailId, double monthlyFeeValue, double newPayment) {
        String findLoanIdQuery = "SELECT LoanID, payment FROM loandetail WHERE ID = ?";
        String updateLoandetailStateQuery = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
        String findLoandetailsStateQuery = "SELECT State FROM loandetail WHERE LoanID = ?";
        String updateLoanStateQuery = "UPDATE loan SET StateLoan = ? WHERE ID = ?";

        try (Connection connection = ftDataSource.getConnection()) {
            boolean prevAuto = connection.getAutoCommit();
            try {
                connection.setAutoCommit(false);
                try (PreparedStatement stmtFindLoanId = connection.prepareStatement(findLoanIdQuery);
                     PreparedStatement stmtUpdateLoandetail = connection.prepareStatement(updateLoandetailStateQuery);
                     PreparedStatement stmtFindLoandetailsState = connection.prepareStatement(findLoandetailsStateQuery);
                     PreparedStatement stmtUpdateLoan = connection.prepareStatement(updateLoanStateQuery)) {

                    stmtFindLoanId.setLong(1, loandetailId);
                    ResultSet rsLoanId = stmtFindLoanId.executeQuery();

                    if (rsLoanId.next()) {
                        int loanId = rsLoanId.getInt("LoanID");
                        double currentPayment = rsLoanId.getDouble("payment");

                        double totalPayment = currentPayment + newPayment;
                        String loandetailState = totalPayment == monthlyFeeValue ? "Pagado" : "Parcial";

                        stmtUpdateLoandetail.setDouble(1, totalPayment);
                        stmtUpdateLoandetail.setString(2, loandetailState);
                        stmtUpdateLoandetail.setLong(3, loandetailId);
                        stmtUpdateLoandetail.executeUpdate();

                        stmtFindLoandetailsState.setInt(1, loanId);
                        ResultSet rsLoandetailsState = stmtFindLoandetailsState.executeQuery();

                        boolean allPaid = true;
                        while (rsLoandetailsState.next()) {
                            if (!"Pagado".equals(rsLoandetailsState.getString("State"))) {
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
                    "Error aplicando pago de cuota en FinantialTracker: " + ex.getMessage(), ex);
        }
    }

    /** LoanDetailsDao.findLoanDetailsByLoanId: SELECT * FROM loandetail WHERE LoanID. */
    public List<Map<String, Object>> detallesPorPrestamo(int loanId) {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + detalleCols() + " FROM loandetail WHERE LoanID = :loanId",
                new MapSqlParameterSource("loanId", loanId)));
    }

    /** LoanDetailsDao.getAllLoanDetails. */
    public List<Map<String, Object>> listarDetalles() {
        return normalizar(ftJdbc.queryForList(
                "SELECT " + detalleCols() + " FROM loandetail",
                new MapSqlParameterSource()));
    }

    /**
     * LoanDetailsDao.insertMultipleLoanDetails: genera las N cuotas del
     * prestamo. paymentDate de cada cuota = ultimo dia del mes, avanzando mes
     * a mes desde el PaymentDate del loan; State='Pendiente';
     * CreatedAt = ahora (igual que Timestamp.valueOf(LocalDateTime.now())).
     */
    public void insertarDetalles(int loanId, int dues, String paymentDate,
            double totalInterest, double totalIntangibleFund,
            double monthlyCapitalInstallment, double monthlyInterestFee,
            double monthlyIntangibleFundFee, double monthlyFeeValue, int usuario) {

        String insertSql = "INSERT INTO loandetail (LoanID, Dues, TotalInterest, TotalIntangibleFund, "
                + "MonthlyCapitalInstallment, MonthlyInterestFee, MonthlyIntangibleFundFee, MonthlyFeeValue,"
                + " PaymentDate, State, CreatedBy, CreatedAt) "
                + "VALUES (:loanId, :dues, :totalInterest, :totalIntangibleFund, "
                + ":monthlyCapitalInstallment, :monthlyInterestFee, :monthlyIntangibleFundFee, :monthlyFeeValue, "
                + ":paymentDate, :state, :createdBy, :createdAt)";

        LocalDate currentDate = LocalDate.parse(paymentDate);
        for (int i = 0; i < dues; i++) {
            LocalDate lastDayOfMonth = currentDate.withDayOfMonth(currentDate.lengthOfMonth());
            ftJdbc.update(insertSql, new MapSqlParameterSource()
                    .addValue("loanId", loanId)
                    .addValue("dues", i + 1)
                    .addValue("totalInterest", totalInterest)
                    .addValue("totalIntangibleFund", totalIntangibleFund)
                    .addValue("monthlyCapitalInstallment", monthlyCapitalInstallment)
                    .addValue("monthlyInterestFee", monthlyInterestFee)
                    .addValue("monthlyIntangibleFundFee", monthlyIntangibleFundFee)
                    .addValue("monthlyFeeValue", monthlyFeeValue)
                    .addValue("paymentDate", lastDayOfMonth.toString())
                    .addValue("state", "Pendiente")
                    .addValue("createdBy", usuario)
                    .addValue("createdAt", LocalDateTime.now().format(FECHA_HORA)));
            currentDate = currentDate.plusMonths(1);
        }
    }

    /** LoanDetailsDao.calcularMontoPendientePorLoanId: deuda viva de un loan. */
    public double montoPendiente(int loanId) {
        Double total = ftJdbc.queryForObject(
                "SELECT SUM(MonthlyFeeValue - IFNULL(payment, 0)) AS TotalPendingAmount "
                        + "FROM loandetail "
                        + "WHERE LoanID = :loanId AND State IN ('pendiente', 'parcial')",
                new MapSqlParameterSource("loanId", loanId), Double.class);
        return total == null ? 0.0 : total;
    }

    /** LoanDetailsDao.getLoanDetailById: historial de una cuota con su loan. */
    public Optional<Map<String, Object>> historialDetalle(int id) {
        String sql = "SELECT loa.SoliNum AS soliNum ,loaDet.payment AS payment ,  "
                + "loa.dues AS loanDues, loaDet.dues AS loandetailDues, "
                + "loaDet.MonthlyFeeValue AS monthlyFeeValue , loaDet.PaymentDate AS paymentDate "
                + "FROM financialtracker1.loandetail loaDet "
                + "LEFT JOIN financialtracker1.loan loa ON loaDet.LoanID = loa.ID "
                + "WHERE loaDet.ID = :id";
        List<Map<String, Object>> rows = ftJdbc.queryForList(sql,
                new MapSqlParameterSource("id", id));
        return rows.isEmpty() ? Optional.empty() : Optional.of(normalizarFila(rows.get(0)));
    }

    // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Normaliza fechas a texto plano para que el JSON conserve un formato
     * estable que la app Swing pueda re-parsear a java.sql.Date /
     * LocalDateTime igual que hacia con rs.getDate()/rs.getTimestamp():
     * DATE -> "yyyy-MM-dd", DATETIME/TIMESTAMP -> "yyyy-MM-dd HH:mm:ss".
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
