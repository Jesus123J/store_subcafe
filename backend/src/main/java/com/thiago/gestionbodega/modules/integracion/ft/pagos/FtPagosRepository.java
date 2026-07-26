package com.thiago.gestionbodega.modules.integracion.ft.pagos;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * REGISTRO DE PAGOS de FinantialTracker (planilla del HSJ) sobre la BD
 * financialtracker1. Replica EXACTAMENTE el SQL que ejecuta RegistroDao
 * (app Swing) con JDBC directo: mismos estados ('Pendiente'/'Parcial'/
 * 'Pagado'), mismos updates encadenados y mismos inserts de historial
 * (historial_reversiones / historial_correcciones), para que la UI
 * existente pase por el backend sin cambiar de comportamiento.
 *
 * Los flujos multi-paso (registro + registerdetails + abonodetail/
 * loandetail) se ejecutan en UNA transaccion server-side sobre una
 * Connection cruda del DataSource secundario.
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier}
 * sobre un campo con {@code @RequiredArgsConstructor} NO se propaga al
 * constructor generado â€” Spring inyectaria el DataSource/JdbcTemplate
 * primario (bodega) en vez del secundario (FT).
 */
@Repository
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true")
public class FtPagosRepository {

    private final NamedParameterJdbcTemplate ftJdbc;
    private final DataSource ftDataSource;

    public FtPagosRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc,
            @Qualifier("financialTrackerDataSource") DataSource ftDataSource) {
        this.ftJdbc = ftJdbc;
        this.ftDataSource = ftDataSource;
    }

    /** Cuota (loandetail/abonodetail) con el monto a aplicar en un pago. */
    public record DetalleCuota(Long id, Double monto) {
    }

    // â”€â”€â”€ Helpers JDBC crudo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @FunctionalInterface
    private interface RowFn<T> {
        T map(ResultSet rs) throws SQLException;
    }

    /** SELECT con placeholders '?' identicos a los del DAO original. */
    private <T> List<T> queryList(String sql, RowFn<T> fn, Object... params) {
        List<T> out = new ArrayList<>();
        try (Connection c = ftDataSource.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    out.add(fn.map(rs));
                }
            }
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error consultando pagos FT: " + e.getMessage(), e);
        }
        return out;
    }

    private static String ts(java.sql.Timestamp t) {
        return t == null ? null : t.toString();
    }

    private static String dt(java.sql.Date d) {
        return d == null ? null : d.toString();
    }

    private static void rollbackQuieto(Connection conn) {
        if (conn != null) {
            try {
                conn.rollback();
            } catch (SQLException ignored) {
            }
        }
    }

    private static void cerrarQuieto(Connection conn) {
        if (conn != null) {
            try {
                conn.setAutoCommit(true);
            } catch (SQLException ignored) {
            }
            try {
                conn.close();
            } catch (SQLException ignored) {
            }
        }
    }

    // â”€â”€â”€ insertRegisterDetail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica RegistroDao.insertRegisterDetail(): INSERT suelto en
     * registerdetails. Devuelve true si inserto una fila.
     */
    public boolean insertRegisterDetail(Integer idRegistro, Long idBondDetails,
                                        Long idLoanDetails, Double amountPar) {
        try (Connection conn = ftDataSource.getConnection()) {
            return insertRegisterDetail(conn, idRegistro, idBondDetails,
                    idLoanDetails, amountPar) > 0;
        } catch (SQLException e) {
            System.out.println("Error -< " + e.getMessage());
            return false;
        }
    }

    /** Version transaccional (misma Connection) reutilizada por los flujos de pago. */
    private int insertRegisterDetail(Connection conn, Integer idRegistro,
                                     Long idBondDetails, Long idLoanDetails,
                                     Double amountPar) throws SQLException {
        String sql = "INSERT INTO registerdetails (idRegistro, idBondDetails, idLoanDetails, amountPar) VALUES (?, ?, ?, ?)";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idRegistro);
            if (idBondDetails != null) {
                stmt.setLong(2, idBondDetails);
            } else {
                stmt.setNull(2, java.sql.Types.INTEGER);
            }
            if (idLoanDetails != null) {
                stmt.setLong(3, idLoanDetails);
            } else {
                stmt.setNull(3, java.sql.Types.INTEGER);
            }
            stmt.setDouble(4, amountPar);
            return stmt.executeUpdate();
        }
    }

    // â”€â”€â”€ Lecturas de registros â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.findRegisterDetailsByEmployeeId(). */
    public List<Map<String, Object>> findRegisterDetailsByEmployeeId(String employeeId) {
        String sql = "SELECT DATE_FORMAT(rs.fecha_registro, '%Y-%m-%d') AS fecha_registro, rs.codigo, rs.amount, "
                + "CONCAT('PrÃ©stamo', '-', loan.SoliNum, ' ', loan.Dues, '/', ld.Dues) AS conceptLoan, "
                + "CONCAT(ser.description, '-', bon.SoliNum, ' ', bon.dues, '/', abDe.dues) AS conceptBond, "
                + "ld.PaymentDate AS fechaVLoan, abDe.paymentDate AS fechaVBond, "
                + "rsDe.amountPar, ld.MonthlyFeeValue AS montoLoan, abDe.monthly AS montoBond "
                + "FROM financialtracker1.registro rs "
                + "LEFT JOIN financialtracker1.registerdetails rsDe ON rsDe.idRegistro = rs.id "
                + "LEFT JOIN financialtracker1.loandetail ld ON ld.ID = rsDe.idLoanDetails "
                + "LEFT JOIN financialtracker1.loan loan ON loan.ID = ld.LoanID "
                + "LEFT JOIN financialtracker1.abonodetail abDe ON abDe.id = rsDe.idBondDetails "
                + "LEFT JOIN financialtracker1.abono bon ON bon.id = abDe.AbonoID "
                + "LEFT JOIN financialtracker1.service_concept ser ON ser.id = bon.service_concept_id "
                + "WHERE rs.empleado_id = ? ORDER BY rs.fecha_registro DESC";

        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("fechaRegistro", rs.getString("fecha_registro"));
            m.put("codigo", rs.getString("codigo"));
            m.put("amount", rs.getBigDecimal("amount"));
            m.put("conceptLoan", rs.getString("conceptLoan"));
            m.put("conceptBond", rs.getString("conceptBond"));
            m.put("fechaVLoan", rs.getString("fechaVLoan"));
            m.put("fechaVBond", rs.getString("fechaVBond"));
            m.put("amountPar", rs.getBigDecimal("amountPar"));
            m.put("montoLoan", rs.getBigDecimal("montoLoan"));
            m.put("montoBond", rs.getBigDecimal("montoBond"));
            return m;
        }, employeeId);
    }

    /** Replica RegistroDao.obtenerRegistrosPorEmpleado(). */
    public List<Map<String, Object>> obtenerRegistrosPorEmpleado(int empleadoId) {
        String sql = "SELECT r.id, r.codigo, r.fecha_registro, r.amount, "
                + " GROUP_CONCAT(DISTINCT p.id_prestamoDetails ORDER BY p.id_prestamoDetails SEPARATOR ', ') AS prestamos, "
                + " GROUP_CONCAT(DISTINCT b.id_abonoDetails ORDER BY b.id_abonoDetails SEPARATOR ', ') AS bonos "
                + "FROM registro r "
                + "LEFT JOIN soli_prestamo p ON r.id = p.registro_id "
                + "LEFT JOIN soli_bonus b ON r.id = b.registro_id "
                + "WHERE r.empleado_id = ? "
                + "GROUP BY r.codigo "
                + "ORDER BY r.fecha_registro DESC";

        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getInt("id"));
            m.put("codigo", rs.getString("codigo"));
            m.put("fechaRegistro", ts(rs.getTimestamp("fecha_registro")));
            m.put("amount", rs.getDouble("amount"));
            m.put("prestamos", rs.getString("prestamos"));
            m.put("bonos", rs.getString("bonos"));
            return m;
        }, empleadoId);
    }

    /** Replica RegistroDao.findByCodigo(). */
    public Optional<Map<String, Object>> findByCodigo(String codigo) {
        String sql = "SELECT id, codigo, empleado_id, fecha_registro, amount FROM registro WHERE codigo = ?";
        List<Map<String, Object>> rows = queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getInt("id"));
            m.put("codigo", rs.getString("codigo"));
            m.put("empleadoId", rs.getInt("empleado_id"));
            m.put("fechaRegistro", ts(rs.getTimestamp("fecha_registro")));
            m.put("amount", rs.getDouble("amount"));
            return m;
        }, codigo.trim());
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    // â”€â”€â”€ Insertar registro completo (transaccional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica ambos overloads de RegistroDao.insertarRegistroCompleto():
     * CALL InsertarRegistro + LAST_INSERT_ID + INSERTs en registerdetails,
     * en UNA transaccion. Devuelve el idRegistro generado, o -1 si hubo
     * error SQL (el DAO original devolvia 3 / false en ese caso).
     */
    public int insertarRegistroCompleto(int empleadoId, double amount,
                                        List<DetalleCuota> prestamos,
                                        List<DetalleCuota> bonos) {
        String sqlRegistro = "CALL InsertarRegistro(?,?);";
        String sqlObtenerID = "SELECT LAST_INSERT_ID()";

        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement stmtRegistro =
                         conn.prepareStatement(sqlRegistro, Statement.RETURN_GENERATED_KEYS)) {
                stmtRegistro.setInt(1, empleadoId);
                stmtRegistro.setDouble(2, amount);
                stmtRegistro.executeUpdate();
            }

            int idRegistro = 0;
            try (PreparedStatement stmtID = conn.prepareStatement(sqlObtenerID);
                 ResultSet rs = stmtID.executeQuery()) {
                if (rs.next()) {
                    idRegistro = rs.getInt(1);
                }
            }

            if (prestamos != null) {
                for (DetalleCuota p : prestamos) {
                    insertRegisterDetail(conn, idRegistro, null, p.id(), p.monto());
                }
            }
            if (bonos != null) {
                for (DetalleCuota b : bonos) {
                    insertRegisterDetail(conn, idRegistro, b.id(), null, b.monto());
                }
            }

            conn.commit();
            return idRegistro;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("error  -> " + e.getMessage());
            return -1;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /**
     * Replica RegistroDao.insertarRegistroCompletoConLote(): INSERT directo
     * en registro con lote_id + UPDATE del codigo P/xxxx-xxxxxxxx +
     * registerdetails, transaccional. Devuelve idRegistro o -1 si error.
     */
    public int insertarRegistroCompletoConLote(int empleadoId, double amount, int loteId,
                                               List<DetalleCuota> prestamos,
                                               List<DetalleCuota> bonos) {
        String sqlRegistro = "INSERT INTO registro (empleado_id, amount, lote_id) VALUES (?, ?, ?)";
        String sqlObtenerID = "SELECT LAST_INSERT_ID()";
        String sqlActualizarCodigo = "UPDATE registro SET codigo = CONCAT('P/', LPAD(?, 4, '0'), '-', LPAD(id, 8, '0')) WHERE id = ?";

        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            int idRegistro = 0;
            try (PreparedStatement stmtRegistro = conn.prepareStatement(sqlRegistro)) {
                stmtRegistro.setInt(1, empleadoId);
                stmtRegistro.setDouble(2, amount);
                stmtRegistro.setInt(3, loteId);
                stmtRegistro.executeUpdate();
            }

            try (PreparedStatement stmtID = conn.prepareStatement(sqlObtenerID);
                 ResultSet rs = stmtID.executeQuery()) {
                if (rs.next()) {
                    idRegistro = rs.getInt(1);
                }
            }

            try (PreparedStatement stmtCodigo = conn.prepareStatement(sqlActualizarCodigo)) {
                stmtCodigo.setInt(1, loteId);
                stmtCodigo.setInt(2, idRegistro);
                stmtCodigo.executeUpdate();
            }

            if (prestamos != null) {
                for (DetalleCuota p : prestamos) {
                    insertRegisterDetail(conn, idRegistro, null, p.id(), p.monto());
                }
            }
            if (bonos != null) {
                for (DetalleCuota b : bonos) {
                    insertRegisterDetail(conn, idRegistro, b.id(), null, b.monto());
                }
            }

            conn.commit();
            return idRegistro;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error insertando registro con lote: " + e.getMessage());
            return -1;
        } finally {
            cerrarQuieto(conn);
        }
    }

    // â”€â”€â”€ Revertir pago â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica RegistroDao.obtenerDetallesPagoParaRevertir(): arma el MISMO
     * HTML que muestra la app Swing antes de confirmar la reversion.
     */
    public String obtenerDetallesPagoParaRevertir(int registroId) {
        StringBuilder detalles = new StringBuilder();
        detalles.append("<html><body style='width: 350px;'>");

        String sqlRegistro = "SELECT r.codigo, r.fecha_registro, r.amount, " +
                "e.fullName as empleado, " +
                "e.national_id as dni " +
                "FROM registro r " +
                "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                "WHERE r.id = ?";

        try (Connection conn = ftDataSource.getConnection()) {
            try (PreparedStatement stmt = conn.prepareStatement(sqlRegistro)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        detalles.append("<h3 style='color:#c0392b;'>INFORMACIÃ“N DEL PAGO</h3>");
                        detalles.append("<b>CÃ³digo:</b> ").append(rs.getString("codigo")).append("<br>");
                        detalles.append("<b>Fecha:</b> ").append(rs.getTimestamp("fecha_registro")).append("<br>");
                        detalles.append("<b>Monto Total:</b> S/ ").append(String.format("%.2f", rs.getDouble("amount"))).append("<br>");
                        detalles.append("<b>Empleado:</b> ").append(rs.getString("empleado")).append("<br>");
                        detalles.append("<b>DNI:</b> ").append(rs.getString("dni")).append("<br><br>");
                    }
                }
            }

            String sqlPrestamos = "SELECT rd.id, rd.amountPar, ld.ID as cuotaId, ld.Dues, " +
                    "l.SoliNum, ld.MonthlyFeeValue, ld.payment " +
                    "FROM registerdetails rd " +
                    "INNER JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE rd.idRegistro = ?";

            boolean hayPrestamos = false;
            try (PreparedStatement stmt = conn.prepareStatement(sqlPrestamos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        if (!hayPrestamos) {
                            detalles.append("<h4 style='color:#2980b9;'>PRÃ‰STAMOS AFECTADOS:</h4>");
                            detalles.append("<table border='1' cellpadding='3'>");
                            detalles.append("<tr><th>Solicitud</th><th>Cuota</th><th>Pagado</th></tr>");
                            hayPrestamos = true;
                        }
                        detalles.append("<tr>");
                        detalles.append("<td>").append(rs.getString("SoliNum")).append("</td>");
                        detalles.append("<td>").append(rs.getInt("Dues")).append("</td>");
                        detalles.append("<td>S/ ").append(String.format("%.2f", rs.getDouble("amountPar"))).append("</td>");
                        detalles.append("</tr>");
                    }
                    if (hayPrestamos) {
                        detalles.append("</table><br>");
                    }
                }
            }

            String sqlAbonos = "SELECT rd.id, rd.amountPar, ad.id as cuotaId, ad.dues, " +
                    "a.SoliNum, sc.description, ad.monthly, ad.payment " +
                    "FROM registerdetails rd " +
                    "INNER JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "INNER JOIN service_concept sc ON a.service_concept_id = sc.id " +
                    "WHERE rd.idRegistro = ?";

            boolean hayAbonos = false;
            try (PreparedStatement stmt = conn.prepareStatement(sqlAbonos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        if (!hayAbonos) {
                            detalles.append("<h4 style='color:#27ae60;'>ABONOS AFECTADOS:</h4>");
                            detalles.append("<table border='1' cellpadding='3'>");
                            detalles.append("<tr><th>Concepto</th><th>Cuota</th><th>Pagado</th></tr>");
                            hayAbonos = true;
                        }
                        detalles.append("<tr>");
                        detalles.append("<td>").append(rs.getString("description")).append("</td>");
                        detalles.append("<td>").append(rs.getInt("dues")).append("</td>");
                        detalles.append("<td>S/ ").append(String.format("%.2f", rs.getDouble("amountPar"))).append("</td>");
                        detalles.append("</tr>");
                    }
                    if (hayAbonos) {
                        detalles.append("</table><br>");
                    }
                }
            }

            if (!hayPrestamos && !hayAbonos) {
                detalles.append("<p style='color:orange;'>âš  No se encontraron detalles de pago asociados.</p>");
            }
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error obteniendo detalles del pago: " + e.getMessage(), e);
        }

        detalles.append("</body></html>");
        return detalles.toString();
    }

    /**
     * Replica RegistroDao.revertirPago(): resta payment de las cuotas
     * (mismo CASE Pendiente/Parcial), guarda historial_reversiones,
     * actualiza estado general y borra registerdetails + registro, en UNA
     * transaccion. Devuelve false si hubo error SQL (igual que el DAO).
     */
    public boolean revertirPago(int registroId, String usuarioReversion, String motivoReversion) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String codigoRegistro = "";
            java.sql.Timestamp fechaRegistroOriginal = null;
            double montoTotal = 0.0;
            int empleadoIdVal = 0;
            String empleadoDni = "";
            String empleadoNombre = "";

            String sqlInfoRegistro = "SELECT r.codigo, r.fecha_registro, r.amount, r.empleado_id, " +
                    "e.national_id, e.fullName " +
                    "FROM registro r " +
                    "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                    "WHERE r.id = ?";

            try (PreparedStatement stmt = conn.prepareStatement(sqlInfoRegistro)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        codigoRegistro = rs.getString("codigo");
                        fechaRegistroOriginal = rs.getTimestamp("fecha_registro");
                        montoTotal = rs.getDouble("amount");
                        empleadoIdVal = rs.getInt("empleado_id");
                        empleadoDni = rs.getString("national_id");
                        empleadoNombre = rs.getString("fullName");
                    }
                }
            }

            StringBuilder detallesPrestamosJson = new StringBuilder("[");
            boolean primerPrestamo = true;
            Set<Long> loanIdsAfectados = new HashSet<>();

            String sqlGetPrestamos = "SELECT rd.id, rd.idLoanDetails, rd.amountPar, " +
                    "ld.Dues, ld.LoanID, l.SoliNum, ld.MonthlyFeeValue " +
                    "FROM registerdetails rd " +
                    "INNER JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE rd.idRegistro = ? AND rd.idLoanDetails IS NOT NULL";

            try (PreparedStatement stmt = conn.prepareStatement(sqlGetPrestamos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        long loanDetailId = rs.getLong("idLoanDetails");
                        long loanId = rs.getLong("LoanID");
                        double amountPar = rs.getDouble("amountPar");
                        String soliNum = rs.getString("SoliNum");
                        int dues = rs.getInt("Dues");

                        loanIdsAfectados.add(loanId);

                        if (!primerPrestamo) detallesPrestamosJson.append(",");
                        detallesPrestamosJson.append("{")
                            .append("\"solicitud\":\"").append(soliNum).append("\",")
                            .append("\"cuota\":").append(dues).append(",")
                            .append("\"monto\":").append(amountPar)
                            .append("}");
                        primerPrestamo = false;

                        String sqlUpdateLoan = "UPDATE loandetail SET payment = payment - ?, " +
                                "State = CASE " +
                                "  WHEN (payment - ?) <= 0 THEN 'Pendiente' " +
                                "  WHEN (payment - ?) < MonthlyFeeValue THEN 'Parcial' " +
                                "  ELSE State " +
                                "END " +
                                "WHERE ID = ?";

                        try (PreparedStatement updateStmt = conn.prepareStatement(sqlUpdateLoan)) {
                            updateStmt.setDouble(1, amountPar);
                            updateStmt.setDouble(2, amountPar);
                            updateStmt.setDouble(3, amountPar);
                            updateStmt.setLong(4, loanDetailId);
                            updateStmt.executeUpdate();
                        }
                    }
                }
            }
            detallesPrestamosJson.append("]");

            StringBuilder detallesAbonosJson = new StringBuilder("[");
            boolean primerAbono = true;
            Set<Long> abonoIdsAfectados = new HashSet<>();

            String sqlGetAbonos = "SELECT rd.id, rd.idBondDetails, rd.amountPar, " +
                    "ad.dues, ad.AbonoID, a.SoliNum, sc.description " +
                    "FROM registerdetails rd " +
                    "INNER JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "INNER JOIN service_concept sc ON a.service_concept_id = sc.id " +
                    "WHERE rd.idRegistro = ? AND rd.idBondDetails IS NOT NULL";

            try (PreparedStatement stmt = conn.prepareStatement(sqlGetAbonos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        long bondDetailId = rs.getLong("idBondDetails");
                        long abonoId = rs.getLong("AbonoID");
                        double amountPar = rs.getDouble("amountPar");
                        String soliNum = rs.getString("SoliNum");
                        int dues = rs.getInt("dues");
                        String concepto = rs.getString("description");

                        abonoIdsAfectados.add(abonoId);

                        if (!primerAbono) detallesAbonosJson.append(",");
                        detallesAbonosJson.append("{")
                            .append("\"concepto\":\"").append(concepto != null ? concepto.replace("\"", "'") : "").append("\",")
                            .append("\"solicitud\":\"").append(soliNum).append("\",")
                            .append("\"cuota\":").append(dues).append(",")
                            .append("\"monto\":").append(amountPar)
                            .append("}");
                        primerAbono = false;

                        String sqlUpdateAbono = "UPDATE abonodetail SET payment = payment - ?, " +
                                "state = CASE " +
                                "  WHEN (payment - ?) <= 0 THEN 'Pendiente' " +
                                "  WHEN (payment - ?) < monthly THEN 'Parcial' " +
                                "  ELSE state " +
                                "END " +
                                "WHERE id = ?";

                        try (PreparedStatement updateStmt = conn.prepareStatement(sqlUpdateAbono)) {
                            updateStmt.setDouble(1, amountPar);
                            updateStmt.setDouble(2, amountPar);
                            updateStmt.setDouble(3, amountPar);
                            updateStmt.setLong(4, bondDetailId);
                            updateStmt.executeUpdate();
                        }
                    }
                }
            }
            detallesAbonosJson.append("]");

            String sqlInsertHistorial = "INSERT INTO historial_reversiones " +
                    "(registro_id, codigo_registro, fecha_registro_original, monto_total, " +
                    "empleado_id, empleado_dni, empleado_nombre, " +
                    "detalles_prestamos, detalles_abonos, usuario_reversion, motivo_reversion) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

            try (PreparedStatement stmt = conn.prepareStatement(sqlInsertHistorial)) {
                stmt.setInt(1, registroId);
                stmt.setString(2, codigoRegistro);
                stmt.setTimestamp(3, fechaRegistroOriginal);
                stmt.setDouble(4, montoTotal);
                stmt.setInt(5, empleadoIdVal);
                stmt.setString(6, empleadoDni);
                stmt.setString(7, empleadoNombre);
                stmt.setString(8, detallesPrestamosJson.toString());
                stmt.setString(9, detallesAbonosJson.toString());
                stmt.setString(10, usuarioReversion != null ? usuarioReversion : "SISTEMA");
                stmt.setString(11, motivoReversion);
                stmt.executeUpdate();
            }

            for (Long loanId : loanIdsAfectados) {
                actualizarEstadoGeneralLoan(conn, loanId);
            }
            for (Long abonoId : abonoIdsAfectados) {
                actualizarEstadoGeneralAbono(conn, abonoId);
            }

            String sqlDeleteDetails = "DELETE FROM registerdetails WHERE idRegistro = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteDetails)) {
                stmt.setInt(1, registroId);
                stmt.executeUpdate();
            }

            String sqlDeleteRegistro = "DELETE FROM registro WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRegistro)) {
                stmt.setInt(1, registroId);
                stmt.executeUpdate();
            }

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error al revertir pago: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    // â”€â”€â”€ Lotes de carga masiva â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.crearLoteCarga(). Devuelve id del lote o -1. */
    public int crearLoteCarga(String nombreArchivo, String mes, String anio, String usuarioCarga) {
        String sql = "INSERT INTO lote_carga (nombre_archivo, mes_proceso, anio_proceso, usuario_carga) VALUES (?, ?, ?, ?)";
        try (Connection conn = ftDataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            stmt.setString(1, nombreArchivo);
            stmt.setString(2, mes);
            stmt.setString(3, anio);
            stmt.setString(4, usuarioCarga);
            int affectedRows = stmt.executeUpdate();
            if (affectedRows > 0) {
                try (ResultSet rs = stmt.getGeneratedKeys()) {
                    if (rs.next()) {
                        return rs.getInt(1);
                    }
                }
            }
        } catch (SQLException e) {
            System.out.println("Error creando lote de carga: " + e.getMessage());
        }
        return -1;
    }

    /** Replica RegistroDao.actualizarEstadisticasLote(). */
    public void actualizarEstadisticasLote(int loteId, int cantidadRegistros, double montoTotal) {
        String sql = "UPDATE lote_carga SET cantidad_registros = ?, monto_total = ? WHERE id = ?";
        try (Connection conn = ftDataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, cantidadRegistros);
            stmt.setDouble(2, montoTotal);
            stmt.setInt(3, loteId);
            stmt.executeUpdate();
        } catch (SQLException e) {
            System.out.println("Error actualizando estadÃ­sticas del lote: " + e.getMessage());
        }
    }

    /** Replica RegistroDao.insertarRegistroConLote(). Devuelve id o -1. */
    public int insertarRegistroConLote(int empleadoId, double amount, int loteId) {
        String sql = "INSERT INTO registro (empleado_id, amount, lote_id) VALUES (?, ?, ?)";
        try (Connection conn = ftDataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            stmt.setInt(1, empleadoId);
            stmt.setDouble(2, amount);
            stmt.setInt(3, loteId);
            int affectedRows = stmt.executeUpdate();
            if (affectedRows > 0) {
                try (ResultSet rs = stmt.getGeneratedKeys()) {
                    if (rs.next()) {
                        return rs.getInt(1);
                    }
                }
            }
        } catch (SQLException e) {
            System.out.println("Error insertando registro con lote: " + e.getMessage());
        }
        return -1;
    }

    /** Replica RegistroDao.obtenerLotesActivos(). */
    public List<Map<String, Object>> obtenerLotesActivos() {
        String sql = "SELECT id, nombre_archivo, mes_proceso, anio_proceso, cantidad_registros, " +
                "monto_total, fecha_carga, usuario_carga " +
                "FROM lote_carga WHERE estado = 'ACTIVO' ORDER BY fecha_carga DESC LIMIT 50";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getInt("id"));
            m.put("nombreArchivo", rs.getString("nombre_archivo"));
            m.put("mesProceso", rs.getString("mes_proceso"));
            m.put("anioProceso", rs.getString("anio_proceso"));
            m.put("cantidadRegistros", rs.getInt("cantidad_registros"));
            m.put("montoTotal", rs.getDouble("monto_total"));
            m.put("fechaCarga", ts(rs.getTimestamp("fecha_carga")));
            m.put("usuarioCarga", rs.getString("usuario_carga"));
            return m;
        });
    }

    /** Replica RegistroDao.obtenerDetalleLoteParaRevertir(): mismo HTML. */
    public String obtenerDetalleLoteParaRevertir(int loteId) {
        StringBuilder detalles = new StringBuilder();
        detalles.append("<html><body style='width: 450px;'>");

        try (Connection conn = ftDataSource.getConnection()) {
            String sqlLote = "SELECT * FROM lote_carga WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlLote)) {
                stmt.setInt(1, loteId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        detalles.append("<h3 style='color:#c0392b;'>INFORMACIÃ“N DEL LOTE</h3>");
                        detalles.append("<b>ID Lote:</b> ").append(rs.getInt("id")).append("<br>");
                        detalles.append("<b>Archivo:</b> ").append(rs.getString("nombre_archivo")).append("<br>");
                        detalles.append("<b>PerÃ­odo:</b> ").append(rs.getString("mes_proceso")).append("/").append(rs.getString("anio_proceso")).append("<br>");
                        detalles.append("<b>Fecha Carga:</b> ").append(rs.getTimestamp("fecha_carga")).append("<br>");
                        detalles.append("<b>Usuario:</b> ").append(rs.getString("usuario_carga")).append("<br>");
                        detalles.append("<b>Registros:</b> ").append(rs.getInt("cantidad_registros")).append("<br>");
                        detalles.append("<b>Monto Total:</b> S/ ").append(String.format("%.2f", rs.getDouble("monto_total"))).append("<br><br>");
                    }
                }
            }

            String sqlEmpleados = "SELECT e.national_id, e.fullName, r.amount, r.codigo " +
                    "FROM registro r " +
                    "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                    "WHERE r.lote_id = ? ORDER BY e.fullName LIMIT 20";

            try (PreparedStatement stmt = conn.prepareStatement(sqlEmpleados)) {
                stmt.setInt(1, loteId);
                try (ResultSet rs = stmt.executeQuery()) {
                    detalles.append("<h4 style='color:#2980b9;'>EMPLEADOS AFECTADOS (mÃ¡x. 20):</h4>");
                    detalles.append("<table border='1' cellpadding='3'>");
                    detalles.append("<tr><th>DNI</th><th>Nombre</th><th>Monto</th></tr>");
                    while (rs.next()) {
                        detalles.append("<tr>");
                        detalles.append("<td>").append(rs.getString("national_id")).append("</td>");
                        detalles.append("<td>").append(rs.getString("fullName")).append("</td>");
                        detalles.append("<td>S/ ").append(String.format("%.2f", rs.getDouble("amount"))).append("</td>");
                        detalles.append("</tr>");
                    }
                    detalles.append("</table>");
                }
            }
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error obteniendo detalle del lote: " + e.getMessage(), e);
        }

        detalles.append("</body></html>");
        return detalles.toString();
    }

    /**
     * Replica RegistroDao.revertirLoteCarga(): revierte cada registro del
     * lote (cuotas + historial_reversiones con sufijo [LOTE #n]) y marca el
     * lote como REVERTIDO, en UNA transaccion. false si no hay registros
     * o si hubo error SQL.
     */
    public boolean revertirLoteCarga(int loteId, String usuarioReversion, String motivoReversion) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String sqlRegistros = "SELECT r.id, r.codigo, r.fecha_registro, r.amount, r.empleado_id, " +
                    "e.national_id, e.fullName " +
                    "FROM registro r " +
                    "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                    "WHERE r.lote_id = ?";

            List<Object[]> registrosInfo = new ArrayList<>();
            try (PreparedStatement stmt = conn.prepareStatement(sqlRegistros)) {
                stmt.setInt(1, loteId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Object[] info = new Object[7];
                        info[0] = rs.getInt("id");
                        info[1] = rs.getString("codigo");
                        info[2] = rs.getTimestamp("fecha_registro");
                        info[3] = rs.getDouble("amount");
                        info[4] = rs.getInt("empleado_id");
                        info[5] = rs.getString("national_id");
                        info[6] = rs.getString("fullName");
                        registrosInfo.add(info);
                    }
                }
            }

            if (registrosInfo.isEmpty()) {
                conn.rollback();
                return false;
            }

            for (Object[] regInfo : registrosInfo) {
                int registroId = (int) regInfo[0];
                String codigoRegistro = (String) regInfo[1];
                java.sql.Timestamp fechaRegistroOriginal = (java.sql.Timestamp) regInfo[2];
                double montoTotal = (double) regInfo[3];
                int empleadoIdVal = (int) regInfo[4];
                String empleadoDni = (String) regInfo[5];
                String empleadoNombre = (String) regInfo[6];

                StringBuilder detallesPrestamosJson = new StringBuilder("[");
                boolean primerPrestamo = true;

                String sqlGetPrestamos = "SELECT rd.idLoanDetails, rd.amountPar, " +
                        "ld.Dues, l.SoliNum " +
                        "FROM registerdetails rd " +
                        "LEFT JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                        "LEFT JOIN loan l ON ld.LoanID = l.ID " +
                        "WHERE rd.idRegistro = ? AND rd.idLoanDetails IS NOT NULL";

                try (PreparedStatement stmt = conn.prepareStatement(sqlGetPrestamos)) {
                    stmt.setInt(1, registroId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        while (rs.next()) {
                            long loanDetailId = rs.getLong("idLoanDetails");
                            double amountPar = rs.getDouble("amountPar");
                            String soliNum = rs.getString("SoliNum");
                            int dues = rs.getInt("Dues");

                            if (!primerPrestamo) detallesPrestamosJson.append(",");
                            detallesPrestamosJson.append("{")
                                .append("\"solicitud\":\"").append(soliNum != null ? soliNum : "").append("\",")
                                .append("\"cuota\":").append(dues).append(",")
                                .append("\"monto\":").append(amountPar)
                                .append("}");
                            primerPrestamo = false;

                            String sqlUpdateLoan = "UPDATE loandetail SET payment = payment - ?, " +
                                    "State = CASE " +
                                    "  WHEN (payment - ?) <= 0 THEN 'Pendiente' " +
                                    "  WHEN (payment - ?) < MonthlyFeeValue THEN 'Parcial' " +
                                    "  ELSE State " +
                                    "END " +
                                    "WHERE ID = ?";

                            try (PreparedStatement updateStmt = conn.prepareStatement(sqlUpdateLoan)) {
                                updateStmt.setDouble(1, amountPar);
                                updateStmt.setDouble(2, amountPar);
                                updateStmt.setDouble(3, amountPar);
                                updateStmt.setLong(4, loanDetailId);
                                updateStmt.executeUpdate();
                            }
                        }
                    }
                }
                detallesPrestamosJson.append("]");

                StringBuilder detallesAbonosJson = new StringBuilder("[");
                boolean primerAbono = true;

                String sqlGetAbonos = "SELECT rd.idBondDetails, rd.amountPar, " +
                        "ad.dues, a.SoliNum, sc.description " +
                        "FROM registerdetails rd " +
                        "LEFT JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                        "LEFT JOIN abono a ON ad.AbonoID = a.ID " +
                        "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                        "WHERE rd.idRegistro = ? AND rd.idBondDetails IS NOT NULL";

                try (PreparedStatement stmt = conn.prepareStatement(sqlGetAbonos)) {
                    stmt.setInt(1, registroId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        while (rs.next()) {
                            long bondDetailId = rs.getLong("idBondDetails");
                            double amountPar = rs.getDouble("amountPar");
                            String soliNum = rs.getString("SoliNum");
                            int dues = rs.getInt("dues");
                            String concepto = rs.getString("description");

                            if (!primerAbono) detallesAbonosJson.append(",");
                            detallesAbonosJson.append("{")
                                .append("\"concepto\":\"").append(concepto != null ? concepto.replace("\"", "'") : "").append("\",")
                                .append("\"solicitud\":\"").append(soliNum != null ? soliNum : "").append("\",")
                                .append("\"cuota\":").append(dues).append(",")
                                .append("\"monto\":").append(amountPar)
                                .append("}");
                            primerAbono = false;

                            String sqlUpdateAbono = "UPDATE abonodetail SET payment = payment - ?, " +
                                    "state = CASE " +
                                    "  WHEN (payment - ?) <= 0 THEN 'Pendiente' " +
                                    "  WHEN (payment - ?) < monthly THEN 'Parcial' " +
                                    "  ELSE state " +
                                    "END " +
                                    "WHERE id = ?";

                            try (PreparedStatement updateStmt = conn.prepareStatement(sqlUpdateAbono)) {
                                updateStmt.setDouble(1, amountPar);
                                updateStmt.setDouble(2, amountPar);
                                updateStmt.setDouble(3, amountPar);
                                updateStmt.setLong(4, bondDetailId);
                                updateStmt.executeUpdate();
                            }
                        }
                    }
                }
                detallesAbonosJson.append("]");

                String sqlHistorial = "INSERT INTO historial_reversiones " +
                        "(registro_id, codigo_registro, fecha_registro_original, monto_total, " +
                        "empleado_id, empleado_dni, empleado_nombre, " +
                        "detalles_prestamos, detalles_abonos, " +
                        "usuario_reversion, motivo_reversion) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

                try (PreparedStatement stmt = conn.prepareStatement(sqlHistorial)) {
                    stmt.setInt(1, registroId);
                    stmt.setString(2, codigoRegistro);
                    stmt.setTimestamp(3, fechaRegistroOriginal);
                    stmt.setDouble(4, montoTotal);
                    stmt.setInt(5, empleadoIdVal);
                    stmt.setString(6, empleadoDni);
                    stmt.setString(7, empleadoNombre);
                    stmt.setString(8, detallesPrestamosJson.toString());
                    stmt.setString(9, detallesAbonosJson.toString());
                    stmt.setString(10, usuarioReversion != null ? usuarioReversion : "SISTEMA");
                    stmt.setString(11, motivoReversion + " [LOTE #" + loteId + "]");
                    stmt.executeUpdate();
                }

                String sqlDeleteDetails = "DELETE FROM registerdetails WHERE idRegistro = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteDetails)) {
                    stmt.setInt(1, registroId);
                    stmt.executeUpdate();
                }

                String sqlDeleteRegistro = "DELETE FROM registro WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRegistro)) {
                    stmt.setInt(1, registroId);
                    stmt.executeUpdate();
                }
            }

            String sqlUpdateLote = "UPDATE lote_carga SET estado = 'REVERTIDO', " +
                    "fecha_reversion = CURRENT_TIMESTAMP, " +
                    "usuario_reversion = ?, " +
                    "motivo_reversion = ? " +
                    "WHERE id = ?";

            try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateLote)) {
                stmt.setString(1, usuarioReversion != null ? usuarioReversion : "SISTEMA");
                stmt.setString(2, motivoReversion);
                stmt.setInt(3, loteId);
                stmt.executeUpdate();
            }

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error al revertir lote: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    // â”€â”€â”€ Pagos duplicados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.buscarPagosDuplicadosPrestamos(). */
    public List<Map<String, Object>> buscarPagosDuplicadosPrestamos() {
        List<Map<String, Object>> duplicados = new ArrayList<>();

        String sql1 = "SELECT l.SoliNum, ld.Dues, ld.payment, ld.MonthlyFeeValue, ld.ID, " +
                "'EXCESO' as TipoDuplicado, 0 as CantRegistros " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE ld.payment > ld.MonthlyFeeValue " +
                "AND ld.State = 'Pagado' " +
                "ORDER BY l.SoliNum, ld.Dues";

        duplicados.addAll(queryList(sql1, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("pagado", rs.getDouble("payment"));
            m.put("monto", rs.getDouble("MonthlyFeeValue"));
            m.put("id", rs.getLong("ID"));
            m.put("tipoDuplicado", rs.getString("TipoDuplicado"));
            m.put("cantRegistros", rs.getInt("CantRegistros"));
            return m;
        }));

        String sql2 = "SELECT l.SoliNum, ld.Dues, ld.payment, ld.MonthlyFeeValue, ld.ID, " +
                "'REGISTRO_MULTIPLE' as TipoDuplicado, COUNT(rd.id) as CantRegistros, " +
                "SUM(rd.amountPar) as TotalPagado " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "INNER JOIN registerdetails rd ON rd.idLoanDetails = ld.ID " +
                "GROUP BY ld.ID, l.SoliNum, ld.Dues, ld.payment, ld.MonthlyFeeValue " +
                "HAVING COUNT(rd.id) > 1 " +
                "ORDER BY l.SoliNum, ld.Dues";

        duplicados.addAll(queryList(sql2, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("pagado", rs.getDouble("TotalPagado"));
            m.put("monto", rs.getDouble("MonthlyFeeValue"));
            m.put("id", rs.getLong("ID"));
            m.put("tipoDuplicado", rs.getString("TipoDuplicado"));
            m.put("cantRegistros", rs.getInt("CantRegistros"));
            return m;
        }));

        return duplicados;
    }

    /** Replica RegistroDao.buscarPagosDuplicadosAbonos(). */
    public List<Map<String, Object>> buscarPagosDuplicadosAbonos() {
        List<Map<String, Object>> duplicados = new ArrayList<>();

        String sql1 = "SELECT a.SoliNum, ad.dues, ad.payment, ad.monthly, ad.id, " +
                "'EXCESO' as TipoDuplicado, 0 as CantRegistros " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "WHERE ad.payment > ad.monthly " +
                "AND ad.state = 'Pagado' " +
                "ORDER BY a.SoliNum, ad.dues";

        duplicados.addAll(queryList(sql1, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("dues"));
            m.put("pagado", rs.getDouble("payment"));
            m.put("monto", rs.getDouble("monthly"));
            m.put("id", rs.getLong("id"));
            m.put("tipoDuplicado", rs.getString("TipoDuplicado"));
            m.put("cantRegistros", rs.getInt("CantRegistros"));
            return m;
        }));

        String sql2 = "SELECT a.SoliNum, ad.dues, ad.payment, ad.monthly, ad.id, " +
                "'REGISTRO_MULTIPLE' as TipoDuplicado, COUNT(rd.id) as CantRegistros, " +
                "SUM(rd.amountPar) as TotalPagado " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "INNER JOIN registerdetails rd ON rd.idBondDetails = ad.id " +
                "GROUP BY ad.id, a.SoliNum, ad.dues, ad.payment, ad.monthly " +
                "HAVING COUNT(rd.id) > 1 " +
                "ORDER BY a.SoliNum, ad.dues";

        duplicados.addAll(queryList(sql2, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("dues"));
            m.put("pagado", rs.getDouble("TotalPagado"));
            m.put("monto", rs.getDouble("monthly"));
            m.put("id", rs.getLong("id"));
            m.put("tipoDuplicado", rs.getString("TipoDuplicado"));
            m.put("cantRegistros", rs.getInt("CantRegistros"));
            return m;
        }));

        return duplicados;
    }

    /** Replica RegistroDao.corregirPagosDuplicadosPrestamos(). */
    public int corregirPagosDuplicadosPrestamos(String usuario, String motivo) {
        int corregidos = 0;
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            crearTablaHistorialCorrecciones(conn);

            String sqlSelectExceso = "SELECT ld.ID, l.SoliNum, ld.Dues, ld.payment, ld.MonthlyFeeValue " +
                    "FROM loandetail ld " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE ld.payment > ld.MonthlyFeeValue " +
                    "AND ld.State = 'Pagado'";

            String sqlUpdateExceso = "UPDATE loandetail SET payment = MonthlyFeeValue WHERE ID = ?";

            try (PreparedStatement stmtSelect = conn.prepareStatement(sqlSelectExceso);
                 ResultSet rs = stmtSelect.executeQuery()) {
                while (rs.next()) {
                    long id = rs.getLong("ID");
                    String soliNum = rs.getString("SoliNum");
                    int cuota = rs.getInt("Dues");
                    double pagoAnterior = rs.getDouble("payment");
                    double pagoNuevo = rs.getDouble("MonthlyFeeValue");

                    try (PreparedStatement stmtUpdate = conn.prepareStatement(sqlUpdateExceso)) {
                        stmtUpdate.setLong(1, id);
                        stmtUpdate.executeUpdate();
                    }

                    guardarHistorialCorreccion(conn, "PRESTAMO_EXCESO", soliNum, cuota, pagoAnterior, pagoNuevo, usuario, motivo);
                    corregidos++;
                }
            }

            String sqlSelectDuplicados = "SELECT ld.ID, l.SoliNum, ld.Dues, GROUP_CONCAT(rd.id ORDER BY rd.id) as registros " +
                    "FROM loandetail ld " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "INNER JOIN registerdetails rd ON rd.idLoanDetails = ld.ID " +
                    "GROUP BY ld.ID, l.SoliNum, ld.Dues " +
                    "HAVING COUNT(rd.id) > 1";

            try (PreparedStatement stmtSelect = conn.prepareStatement(sqlSelectDuplicados);
                 ResultSet rs = stmtSelect.executeQuery()) {
                while (rs.next()) {
                    String soliNum = rs.getString("SoliNum");
                    int cuota = rs.getInt("Dues");
                    String registrosStr = rs.getString("registros");

                    String[] ids = registrosStr.split(",");
                    if (ids.length > 1) {
                        for (int i = 1; i < ids.length; i++) {
                            String sqlDelete = "DELETE FROM registerdetails WHERE id = ?";
                            try (PreparedStatement stmtDelete = conn.prepareStatement(sqlDelete)) {
                                stmtDelete.setInt(1, Integer.parseInt(ids[i].trim()));
                                stmtDelete.executeUpdate();
                            }
                        }
                        guardarHistorialCorreccion(conn, "PRESTAMO_REG_DUP", soliNum, cuota, ids.length, 1, usuario,
                                motivo + " - Eliminados " + (ids.length - 1) + " registros duplicados");
                        corregidos++;
                    }
                }
            }

            conn.commit();
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error corrigiendo duplicados de prÃ©stamos: " + e.getMessage());
        } finally {
            cerrarQuieto(conn);
        }
        return corregidos;
    }

    /** Replica RegistroDao.corregirPagosDuplicadosAbonos(). */
    public int corregirPagosDuplicadosAbonos(String usuario, String motivo) {
        int corregidos = 0;
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String sqlSelectExceso = "SELECT ad.id, a.SoliNum, ad.dues, ad.payment, ad.monthly " +
                    "FROM abonodetail ad " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "WHERE ad.payment > ad.monthly " +
                    "AND ad.state = 'Pagado'";

            String sqlUpdateExceso = "UPDATE abonodetail SET payment = monthly WHERE id = ?";

            try (PreparedStatement stmtSelect = conn.prepareStatement(sqlSelectExceso);
                 ResultSet rs = stmtSelect.executeQuery()) {
                while (rs.next()) {
                    long id = rs.getLong("id");
                    String soliNum = rs.getString("SoliNum");
                    int cuota = rs.getInt("dues");
                    double pagoAnterior = rs.getDouble("payment");
                    double pagoNuevo = rs.getDouble("monthly");

                    try (PreparedStatement stmtUpdate = conn.prepareStatement(sqlUpdateExceso)) {
                        stmtUpdate.setLong(1, id);
                        stmtUpdate.executeUpdate();
                    }

                    guardarHistorialCorreccion(conn, "ABONO_EXCESO", soliNum, cuota, pagoAnterior, pagoNuevo, usuario, motivo);
                    corregidos++;
                }
            }

            String sqlSelectDuplicados = "SELECT ad.id, a.SoliNum, ad.dues, GROUP_CONCAT(rd.id ORDER BY rd.id) as registros " +
                    "FROM abonodetail ad " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "INNER JOIN registerdetails rd ON rd.idBondDetails = ad.id " +
                    "GROUP BY ad.id, a.SoliNum, ad.dues " +
                    "HAVING COUNT(rd.id) > 1";

            try (PreparedStatement stmtSelect = conn.prepareStatement(sqlSelectDuplicados);
                 ResultSet rs = stmtSelect.executeQuery()) {
                while (rs.next()) {
                    String soliNum = rs.getString("SoliNum");
                    int cuota = rs.getInt("dues");
                    String registrosStr = rs.getString("registros");

                    String[] ids = registrosStr.split(",");
                    if (ids.length > 1) {
                        for (int i = 1; i < ids.length; i++) {
                            String sqlDelete = "DELETE FROM registerdetails WHERE id = ?";
                            try (PreparedStatement stmtDelete = conn.prepareStatement(sqlDelete)) {
                                stmtDelete.setInt(1, Integer.parseInt(ids[i].trim()));
                                stmtDelete.executeUpdate();
                            }
                        }
                        guardarHistorialCorreccion(conn, "ABONO_REG_DUP", soliNum, cuota, ids.length, 1, usuario,
                                motivo + " - Eliminados " + (ids.length - 1) + " registros duplicados");
                        corregidos++;
                    }
                }
            }

            conn.commit();
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error corrigiendo duplicados de abonos: " + e.getMessage());
        } finally {
            cerrarQuieto(conn);
        }
        return corregidos;
    }

    private void crearTablaHistorialCorrecciones(Connection conn) {
        try {
            String createTable = "CREATE TABLE IF NOT EXISTS historial_correcciones (" +
                    "id INT AUTO_INCREMENT PRIMARY KEY, " +
                    "tipo VARCHAR(30), " +
                    "solicitud VARCHAR(50), " +
                    "cuota INT, " +
                    "pago_anterior DECIMAL(10,2), " +
                    "pago_nuevo DECIMAL(10,2), " +
                    "usuario VARCHAR(100), " +
                    "motivo TEXT, " +
                    "fecha_correccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
                    ")";
            try (PreparedStatement stmt = conn.prepareStatement(createTable)) {
                stmt.executeUpdate();
            }
        } catch (SQLException e) {
            // Tabla ya existe, continuar
        }
    }

    private void guardarHistorialCorreccion(Connection conn, String tipo, String solicitud, int cuota,
                                            double pagoAnterior, double pagoNuevo,
                                            String usuario, String motivo) {
        String sql = "INSERT INTO historial_correcciones " +
                "(tipo, solicitud, cuota, pago_anterior, pago_nuevo, usuario, motivo) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, tipo);
            stmt.setString(2, solicitud);
            stmt.setInt(3, cuota);
            stmt.setDouble(4, pagoAnterior);
            stmt.setDouble(5, pagoNuevo);
            stmt.setString(6, usuario);
            stmt.setString(7, motivo);
            stmt.executeUpdate();
        } catch (SQLException e) {
            System.out.println("Error guardando historial: " + e.getMessage());
        }
    }

    // â”€â”€â”€ Registros huerfanos / reorganizacion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.buscarEmpleadosConRegistrosHuerfanos(). */
    public List<Map<String, Object>> buscarEmpleadosConRegistrosHuerfanos() {
        String sql = "SELECT r.empleado_id, e.national_id, e.fullName, " +
                "COUNT(r.id) as cantidad_huerfanos, SUM(r.amount) as monto_huerfano " +
                "FROM registro r " +
                "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                "LEFT JOIN registerdetails rd ON rd.idRegistro = r.id " +
                "WHERE rd.id IS NULL " +
                "GROUP BY r.empleado_id, e.national_id, e.fullName " +
                "ORDER BY e.fullName";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("empleadoId", rs.getInt("empleado_id"));
            m.put("nationalId", rs.getString("national_id"));
            m.put("fullName", rs.getString("fullName"));
            m.put("cantidadHuerfanos", rs.getInt("cantidad_huerfanos"));
            m.put("montoHuerfano", rs.getDouble("monto_huerfano"));
            return m;
        });
    }

    /** Replica RegistroDao.obtenerDetalleEmpleadoParaReorganizar(). */
    public Map<String, Object> obtenerDetalleEmpleadoParaReorganizar(int empleadoId) {
        try (Connection conn = ftDataSource.getConnection()) {
            return obtenerDetalleEmpleadoParaReorganizar(conn, empleadoId, true);
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error obteniendo detalle del empleado: " + e.getMessage(), e);
        }
    }

    /**
     * Version interna. Con jsonAmigable=true las fechas van como String
     * (para el endpoint GET); con false quedan como objetos java.sql para
     * el uso interno de reorganizarPagosEmpleado (igual que el DAO).
     */
    private Map<String, Object> obtenerDetalleEmpleadoParaReorganizar(
            Connection conn, int empleadoId, boolean jsonAmigable) throws SQLException {
        Map<String, Object> detalle = new LinkedHashMap<>();

        String sqlEmpleado = "SELECT national_id, fullName FROM employees WHERE employee_id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlEmpleado)) {
            stmt.setInt(1, empleadoId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    detalle.put("dni", rs.getString("national_id"));
                    detalle.put("nombre", rs.getString("fullName"));
                }
            }
        }

        List<Map<String, Object>> registrosHuerfanos = new ArrayList<>();
        String sqlHuerfanos = "SELECT r.id, r.codigo, r.fecha_registro, r.amount " +
                "FROM registro r " +
                "LEFT JOIN registerdetails rd ON rd.idRegistro = r.id " +
                "WHERE r.empleado_id = ? AND rd.id IS NULL " +
                "ORDER BY r.fecha_registro ASC";

        try (PreparedStatement stmt = conn.prepareStatement(sqlHuerfanos)) {
            stmt.setInt(1, empleadoId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> reg = new LinkedHashMap<>();
                    reg.put("id", rs.getInt("id"));
                    reg.put("codigo", rs.getString("codigo"));
                    reg.put("fechaRegistro", jsonAmigable
                            ? ts(rs.getTimestamp("fecha_registro"))
                            : rs.getTimestamp("fecha_registro"));
                    reg.put("amount", rs.getDouble("amount"));
                    registrosHuerfanos.add(reg);
                }
            }
        }
        detalle.put("registrosHuerfanos", registrosHuerfanos);

        List<Map<String, Object>> cuotasPrestamos = new ArrayList<>();
        String sqlPrestamos = "SELECT ld.ID, l.SoliNum, ld.Dues, l.Dues as TotalDues, " +
                "ld.MonthlyFeeValue, ld.payment, (ld.MonthlyFeeValue - ld.payment) as pendiente, " +
                "ld.PaymentDate, ld.State " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE l.EmployeeID = ? " +
                "ORDER BY ld.PaymentDate ASC, ld.Dues ASC";

        try (PreparedStatement stmt = conn.prepareStatement(sqlPrestamos)) {
            stmt.setInt(1, empleadoId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> cuota = new LinkedHashMap<>();
                    cuota.put("id", rs.getLong("ID"));
                    cuota.put("soliNum", rs.getString("SoliNum"));
                    cuota.put("dues", rs.getInt("Dues"));
                    cuota.put("totalDues", rs.getInt("TotalDues"));
                    cuota.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
                    cuota.put("payment", rs.getDouble("payment"));
                    cuota.put("pendiente", rs.getDouble("pendiente"));
                    cuota.put("paymentDate", jsonAmigable
                            ? dt(rs.getDate("PaymentDate"))
                            : rs.getDate("PaymentDate"));
                    cuota.put("state", rs.getString("State"));
                    cuotasPrestamos.add(cuota);
                }
            }
        }
        detalle.put("cuotasPrestamos", cuotasPrestamos);

        List<Map<String, Object>> cuotasAbonos = new ArrayList<>();
        String sqlAbonos = "SELECT ad.id, a.SoliNum, ad.dues, a.dues as TotalDues, " +
                "ad.monthly, ad.payment, (ad.monthly - ad.payment) as pendiente, " +
                "ad.paymentDate, ad.state, sc.description as concepto " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "INNER JOIN service_concept sc ON a.service_concept_id = sc.id " +
                "WHERE a.Employee_id = ? " +
                "ORDER BY ad.paymentDate ASC, ad.dues ASC";

        try (PreparedStatement stmt = conn.prepareStatement(sqlAbonos)) {
            stmt.setInt(1, empleadoId);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> cuota = new LinkedHashMap<>();
                    cuota.put("id", rs.getLong("id"));
                    cuota.put("soliNum", rs.getString("SoliNum"));
                    cuota.put("dues", rs.getInt("dues"));
                    cuota.put("totalDues", rs.getInt("TotalDues"));
                    cuota.put("monthly", rs.getDouble("monthly"));
                    cuota.put("payment", rs.getDouble("payment"));
                    cuota.put("pendiente", rs.getDouble("pendiente"));
                    cuota.put("paymentDate", jsonAmigable
                            ? dt(rs.getDate("paymentDate"))
                            : rs.getDate("paymentDate"));
                    cuota.put("state", rs.getString("state"));
                    cuota.put("concepto", rs.getString("concepto"));
                    cuotasAbonos.add(cuota);
                }
            }
        }
        detalle.put("cuotasAbonos", cuotasAbonos);

        return detalle;
    }

    /**
     * Replica RegistroDao.reorganizarPagosEmpleado(): asigna registros
     * huerfanos a cuotas por orden de vencimiento (pendientes/parciales
     * primero, luego pagadas sin vincular), elimina los duplicados sin
     * cuota disponible y guarda historial, en UNA transaccion.
     */
    @SuppressWarnings("unchecked")
    public int reorganizarPagosEmpleado(int empleadoId, String usuario, String motivo) {
        int reorganizados = 0;
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            Map<String, Object> detalle = obtenerDetalleEmpleadoParaReorganizar(conn, empleadoId, false);
            List<Map<String, Object>> registrosHuerfanos = (List<Map<String, Object>>) detalle.get("registrosHuerfanos");
            List<Map<String, Object>> cuotasPrestamos = (List<Map<String, Object>>) detalle.get("cuotasPrestamos");
            List<Map<String, Object>> cuotasAbonos = (List<Map<String, Object>>) detalle.get("cuotasAbonos");

            if (registrosHuerfanos == null || registrosHuerfanos.isEmpty()) {
                conn.rollback();
                return 0;
            }

            List<Long> prestamosConRegistro = obtenerCuotasConRegistro(conn, "idLoanDetails");
            List<Long> abonosConRegistro = obtenerCuotasConRegistro(conn, "idBondDetails");

            for (Map<String, Object> regHuerfano : registrosHuerfanos) {
                int registroId = (int) regHuerfano.get("id");
                String codigo = (String) regHuerfano.get("codigo");
                double montoDisponible = (double) regHuerfano.get("amount");
                boolean asignoAlgo = false;

                for (Map<String, Object> cuotaPrestamo : cuotasPrestamos) {
                    if (montoDisponible <= 0) break;

                    long loanDetailId = (long) cuotaPrestamo.get("id");
                    double mensual = (double) cuotaPrestamo.get("monthlyFeeValue");
                    double pagado = (double) cuotaPrestamo.get("payment");
                    double pendiente = (double) cuotaPrestamo.get("pendiente");
                    String estado = (String) cuotaPrestamo.get("state");

                    if (pendiente > 0) {
                        double pagoAplicar = Math.min(montoDisponible, pendiente);

                        String sqlInsert = "INSERT INTO registerdetails (idRegistro, idLoanDetails, amountPar) VALUES (?, ?, ?)";
                        try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                            stmt.setInt(1, registroId);
                            stmt.setLong(2, loanDetailId);
                            stmt.setDouble(3, pagoAplicar);
                            stmt.executeUpdate();
                        }

                        double nuevoPago = pagado + pagoAplicar;
                        String nuevoEstado = nuevoPago >= mensual ? "Pagado" : "Parcial";

                        String sqlUpdate = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
                        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
                            stmt.setDouble(1, nuevoPago);
                            stmt.setString(2, nuevoEstado);
                            stmt.setLong(3, loanDetailId);
                            stmt.executeUpdate();
                        }

                        cuotaPrestamo.put("payment", nuevoPago);
                        cuotaPrestamo.put("pendiente", mensual - nuevoPago);
                        cuotaPrestamo.put("state", nuevoEstado);

                        montoDisponible -= pagoAplicar;
                        asignoAlgo = true;
                    } else if ("Pagado".equals(estado) && !prestamosConRegistro.contains(loanDetailId)) {
                        double pagoAplicar = Math.min(montoDisponible, mensual);

                        if (Math.abs(pagoAplicar - mensual) < 0.02 || montoDisponible >= mensual) {
                            String sqlInsert = "INSERT INTO registerdetails (idRegistro, idLoanDetails, amountPar) VALUES (?, ?, ?)";
                            try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                                stmt.setInt(1, registroId);
                                stmt.setLong(2, loanDetailId);
                                stmt.setDouble(3, pagoAplicar);
                                stmt.executeUpdate();
                            }

                            prestamosConRegistro.add(loanDetailId);
                            montoDisponible -= pagoAplicar;
                            asignoAlgo = true;
                        }
                    }
                }

                for (Map<String, Object> cuotaAbono : cuotasAbonos) {
                    if (montoDisponible <= 0) break;

                    long abonoDetailId = (long) cuotaAbono.get("id");
                    double mensual = (double) cuotaAbono.get("monthly");
                    double pagado = (double) cuotaAbono.get("payment");
                    double pendiente = (double) cuotaAbono.get("pendiente");
                    String estado = (String) cuotaAbono.get("state");

                    if (pendiente > 0) {
                        double pagoAplicar = Math.min(montoDisponible, pendiente);

                        String sqlInsert = "INSERT INTO registerdetails (idRegistro, idBondDetails, amountPar) VALUES (?, ?, ?)";
                        try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                            stmt.setInt(1, registroId);
                            stmt.setLong(2, abonoDetailId);
                            stmt.setDouble(3, pagoAplicar);
                            stmt.executeUpdate();
                        }

                        double nuevoPago = pagado + pagoAplicar;
                        String nuevoEstado = nuevoPago >= mensual ? "Pagado" : "Parcial";

                        String sqlUpdate = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
                        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
                            stmt.setDouble(1, nuevoPago);
                            stmt.setString(2, nuevoEstado);
                            stmt.setLong(3, abonoDetailId);
                            stmt.executeUpdate();
                        }

                        cuotaAbono.put("payment", nuevoPago);
                        cuotaAbono.put("pendiente", mensual - nuevoPago);
                        cuotaAbono.put("state", nuevoEstado);

                        montoDisponible -= pagoAplicar;
                        asignoAlgo = true;
                    } else if ("Pagado".equals(estado) && !abonosConRegistro.contains(abonoDetailId)) {
                        double pagoAplicar = Math.min(montoDisponible, mensual);

                        if (Math.abs(pagoAplicar - mensual) < 0.02 || montoDisponible >= mensual) {
                            String sqlInsert = "INSERT INTO registerdetails (idRegistro, idBondDetails, amountPar) VALUES (?, ?, ?)";
                            try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                                stmt.setInt(1, registroId);
                                stmt.setLong(2, abonoDetailId);
                                stmt.setDouble(3, pagoAplicar);
                                stmt.executeUpdate();
                            }

                            abonosConRegistro.add(abonoDetailId);
                            montoDisponible -= pagoAplicar;
                            asignoAlgo = true;
                        }
                    }
                }

                if (!asignoAlgo) {
                    String sqlDelete = "DELETE FROM registro WHERE id = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlDelete)) {
                        stmt.setInt(1, registroId);
                        stmt.executeUpdate();
                    }

                    guardarHistorialCorreccion(conn, "HUERFANO_ELIMINADO", codigo, 0,
                            montoDisponible, 0, usuario, motivo + " - Registro sin cuotas disponibles");
                }

                reorganizados++;
            }

            guardarHistorialCorreccion(conn, "REORGANIZACION", String.valueOf(empleadoId), 0,
                    registrosHuerfanos.size(), reorganizados, usuario, motivo);

            conn.commit();
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error reorganizando pagos: " + e.getMessage());
        } finally {
            cerrarQuieto(conn);
        }
        return reorganizados;
    }

    private List<Long> obtenerCuotasConRegistro(Connection conn, String campo) throws SQLException {
        List<Long> ids = new ArrayList<>();
        String sql = "SELECT DISTINCT " + campo + " FROM registerdetails WHERE " + campo + " IS NOT NULL";
        try (PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                ids.add(rs.getLong(1));
            }
        }
        return ids;
    }

    /** Replica RegistroDao.eliminarRegistrosVacios(). */
    public int eliminarRegistrosVacios() {
        int eliminados = 0;

        String sqlSelect = "SELECT r.id, r.codigo FROM registro r " +
                "LEFT JOIN registerdetails rd ON rd.idRegistro = r.id " +
                "WHERE rd.id IS NULL";
        String sqlDelete = "DELETE FROM registro WHERE id = ?";

        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            List<Integer> registrosVacios = new ArrayList<>();
            try (PreparedStatement stmt = conn.prepareStatement(sqlSelect);
                 ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    registrosVacios.add(rs.getInt("id"));
                }
            }

            for (Integer id : registrosVacios) {
                try (PreparedStatement stmt = conn.prepareStatement(sqlDelete)) {
                    stmt.setInt(1, id);
                    stmt.executeUpdate();
                    eliminados++;
                }
            }

            conn.commit();
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error eliminando registros vacÃ­os: " + e.getMessage());
        } finally {
            cerrarQuieto(conn);
        }
        return eliminados;
    }

    // â”€â”€â”€ Edicion de pagos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.obtenerDetallesPagoParaEdicion(). */
    public Map<String, Object> obtenerDetallesPagoParaEdicion(int registroId) {
        Map<String, Object> resultado = new LinkedHashMap<>();
        List<Map<String, Object>> prestamos = new ArrayList<>();
        List<Map<String, Object>> abonos = new ArrayList<>();
        String empleadoNombre = "";
        String empleadoDni = "";

        try (Connection conn = ftDataSource.getConnection()) {
            String sqlEmpleado = "SELECT e.fullName, e.national_id " +
                    "FROM registro r " +
                    "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                    "WHERE r.id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlEmpleado)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        empleadoNombre = rs.getString("fullName");
                        empleadoDni = rs.getString("national_id");
                    }
                }
            }

            String sqlPrestamos = "SELECT l.SoliNum, ld.Dues, ld.MonthlyFeeValue, rd.amountPar, rd.id as rdId " +
                    "FROM registerdetails rd " +
                    "INNER JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE rd.idRegistro = ? AND rd.idLoanDetails IS NOT NULL " +
                    "ORDER BY l.SoliNum, ld.Dues";
            try (PreparedStatement stmt = conn.prepareStatement(sqlPrestamos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("soliNum", rs.getString("SoliNum"));
                        m.put("dues", rs.getInt("Dues"));
                        m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
                        m.put("amountPar", rs.getDouble("amountPar"));
                        m.put("rdId", rs.getLong("rdId"));
                        prestamos.add(m);
                    }
                }
            }

            String sqlAbonos = "SELECT a.SoliNum, ad.dues, ad.monthly, rd.amountPar, rd.id as rdId " +
                    "FROM registerdetails rd " +
                    "INNER JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "WHERE rd.idRegistro = ? AND rd.idBondDetails IS NOT NULL " +
                    "ORDER BY a.SoliNum, ad.dues";
            try (PreparedStatement stmt = conn.prepareStatement(sqlAbonos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("soliNum", rs.getString("SoliNum"));
                        m.put("dues", rs.getInt("dues"));
                        m.put("monthly", rs.getDouble("monthly"));
                        m.put("amountPar", rs.getDouble("amountPar"));
                        m.put("rdId", rs.getLong("rdId"));
                        abonos.add(m);
                    }
                }
            }
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error obteniendo detalles para edicion: " + e.getMessage(), e);
        }

        resultado.put("prestamos", prestamos);
        resultado.put("abonos", abonos);
        resultado.put("empleadoNombre", empleadoNombre);
        resultado.put("empleadoDni", empleadoDni);
        return resultado;
    }

    /** Replica RegistroDao.actualizarMontoDetallePago() (transaccional). */
    public boolean actualizarMontoDetallePago(long idRegisterDetail, boolean esPrestamo,
                                              double montoAnterior, double montoNuevo,
                                              String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String sqlGetDetail = "SELECT idLoanDetails, idBondDetails FROM registerdetails WHERE id = ?";
            Long idLoanDetails = null;
            Long idBondDetails = null;

            try (PreparedStatement stmt = conn.prepareStatement(sqlGetDetail)) {
                stmt.setLong(1, idRegisterDetail);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        idLoanDetails = rs.getObject("idLoanDetails") != null ? rs.getLong("idLoanDetails") : null;
                        idBondDetails = rs.getObject("idBondDetails") != null ? rs.getLong("idBondDetails") : null;
                    }
                }
            }

            double diferencia = montoNuevo - montoAnterior;

            String sqlUpdateRd = "UPDATE registerdetails SET amountPar = ? WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateRd)) {
                stmt.setDouble(1, montoNuevo);
                stmt.setLong(2, idRegisterDetail);
                stmt.executeUpdate();
            }

            if (esPrestamo && idLoanDetails != null) {
                String sqlUpdateLd = "UPDATE loandetail SET payment = payment + ?, " +
                        "State = CASE " +
                        "  WHEN payment + ? >= MonthlyFeeValue THEN 'Pagado' " +
                        "  WHEN payment + ? > 0 THEN 'Parcial' " +
                        "  ELSE 'Pendiente' " +
                        "END " +
                        "WHERE ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateLd)) {
                    stmt.setDouble(1, diferencia);
                    stmt.setDouble(2, diferencia);
                    stmt.setDouble(3, diferencia);
                    stmt.setLong(4, idLoanDetails);
                    stmt.executeUpdate();
                }

                String sqlGetLoanId = "SELECT LoanID FROM loandetail WHERE ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetLoanId)) {
                    stmt.setLong(1, idLoanDetails);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            actualizarEstadoGeneralLoan(conn, rs.getLong("LoanID"));
                        }
                    }
                }
            } else if (!esPrestamo && idBondDetails != null) {
                String sqlUpdateAd = "UPDATE abonodetail SET payment = payment + ?, " +
                        "state = CASE " +
                        "  WHEN payment + ? >= monthly THEN 'Pagado' " +
                        "  WHEN payment + ? > 0 THEN 'Parcial' " +
                        "  ELSE 'Pendiente' " +
                        "END " +
                        "WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateAd)) {
                    stmt.setDouble(1, diferencia);
                    stmt.setDouble(2, diferencia);
                    stmt.setDouble(3, diferencia);
                    stmt.setLong(4, idBondDetails);
                    stmt.executeUpdate();
                }

                String sqlGetAbonoId = "SELECT AbonoID FROM abonodetail WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetAbonoId)) {
                    stmt.setLong(1, idBondDetails);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            actualizarEstadoGeneralAbono(conn, rs.getLong("AbonoID"));
                        }
                    }
                }
            }

            guardarHistorialCorreccion(conn,
                    esPrestamo ? "EDICION_PRESTAMO" : "EDICION_ABONO",
                    String.valueOf(idRegisterDetail), 0,
                    montoAnterior, montoNuevo, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error actualizando detalle de pago: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /** Replica RegistroDao.eliminarDetallePago() (transaccional). */
    public boolean eliminarDetallePago(long idRegisterDetail, boolean esPrestamo,
                                       double monto, String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String sqlGetDetail = "SELECT idLoanDetails, idBondDetails FROM registerdetails WHERE id = ?";
            Long idLoanDetails = null;
            Long idBondDetails = null;
            Long loanId = null;
            Long abonoId = null;

            try (PreparedStatement stmt = conn.prepareStatement(sqlGetDetail)) {
                stmt.setLong(1, idRegisterDetail);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        idLoanDetails = rs.getObject("idLoanDetails") != null ? rs.getLong("idLoanDetails") : null;
                        idBondDetails = rs.getObject("idBondDetails") != null ? rs.getLong("idBondDetails") : null;
                    }
                }
            }

            if (esPrestamo && idLoanDetails != null) {
                String sqlGetLoanId = "SELECT LoanID FROM loandetail WHERE ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetLoanId)) {
                    stmt.setLong(1, idLoanDetails);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            loanId = rs.getLong("LoanID");
                        }
                    }
                }

                double paymentActual = 0;
                double monthlyFeeValue = 0;
                String sqlGetValues = "SELECT COALESCE(payment, 0) as payment, MonthlyFeeValue FROM loandetail WHERE ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetValues)) {
                    stmt.setLong(1, idLoanDetails);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            paymentActual = rs.getDouble("payment");
                            monthlyFeeValue = rs.getDouble("MonthlyFeeValue");
                        }
                    }
                }

                double nuevoPayment = Math.max(0, paymentActual - monto);
                String nuevoEstado;
                if (nuevoPayment == 0) {
                    nuevoEstado = "Pendiente";
                } else if (nuevoPayment < monthlyFeeValue) {
                    nuevoEstado = "Parcial";
                } else {
                    nuevoEstado = "Pagado";
                }

                String sqlUpdateLd = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateLd)) {
                    stmt.setDouble(1, nuevoPayment);
                    stmt.setString(2, nuevoEstado);
                    stmt.setLong(3, idLoanDetails);
                    stmt.executeUpdate();
                }

                if (loanId != null) {
                    actualizarEstadoGeneralLoan(conn, loanId);
                }
            } else if (!esPrestamo && idBondDetails != null) {
                double paymentActualAbono = 0;
                double monthlyAbono = 0;
                String sqlGetValuesAbono = "SELECT AbonoID, COALESCE(payment, 0) as payment, monthly FROM abonodetail WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetValuesAbono)) {
                    stmt.setLong(1, idBondDetails);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            abonoId = rs.getLong("AbonoID");
                            paymentActualAbono = rs.getDouble("payment");
                            monthlyAbono = rs.getDouble("monthly");
                        }
                    }
                }

                double nuevoPaymentAbono = Math.max(0, paymentActualAbono - monto);
                String nuevoEstadoAbono;
                if (nuevoPaymentAbono == 0) {
                    nuevoEstadoAbono = "Pendiente";
                } else if (nuevoPaymentAbono < monthlyAbono) {
                    nuevoEstadoAbono = "Parcial";
                } else {
                    nuevoEstadoAbono = "Pagado";
                }

                String sqlUpdateAd = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateAd)) {
                    stmt.setDouble(1, nuevoPaymentAbono);
                    stmt.setString(2, nuevoEstadoAbono);
                    stmt.setLong(3, idBondDetails);
                    stmt.executeUpdate();
                }

                if (abonoId != null) {
                    actualizarEstadoGeneralAbono(conn, abonoId);
                }
            }

            String sqlDelete = "DELETE FROM registerdetails WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDelete)) {
                stmt.setLong(1, idRegisterDetail);
                stmt.executeUpdate();
            }

            String solicitud = esPrestamo ?
                (loanId != null ? "LOAN-" + loanId + "/LD-" + idLoanDetails : String.valueOf(idRegisterDetail)) :
                (abonoId != null ? "ABONO-" + abonoId + "/AD-" + idBondDetails : String.valueOf(idRegisterDetail));

            guardarHistorialCorreccion(conn,
                    esPrestamo ? "ELIMINACION_PRESTAMO" : "ELIMINACION_ABONO",
                    solicitud, 0, monto, 0, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error eliminando detalle de pago: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    // â”€â”€â”€ Estados generales (privados, misma Connection) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    private void actualizarEstadoGeneralLoan(Connection conn, long loanId) throws SQLException {
        String sqlContarEstados = "SELECT " +
                "SUM(CASE WHEN State = 'Pagado' THEN 1 ELSE 0 END) AS pagadas, " +
                "SUM(CASE WHEN State = 'Parcial' THEN 1 ELSE 0 END) AS parciales, " +
                "SUM(CASE WHEN State = 'Pendiente' THEN 1 ELSE 0 END) AS pendientes, " +
                "COUNT(*) AS total " +
                "FROM loandetail WHERE LoanID = ?";

        int pagadas = 0, total = 0;
        try (PreparedStatement stmt = conn.prepareStatement(sqlContarEstados)) {
            stmt.setLong(1, loanId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    pagadas = rs.getInt("pagadas");
                    total = rs.getInt("total");
                }
            }
        }

        String nuevoEstado = (pagadas == total && total > 0) ? "Pagado" : "Pendiente";

        String sqlUpdateLoan = "UPDATE loan SET StateLoan = ? WHERE ID = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateLoan)) {
            stmt.setString(1, nuevoEstado);
            stmt.setLong(2, loanId);
            stmt.executeUpdate();
        }
    }

    private void actualizarEstadoGeneralAbono(Connection conn, long abonoId) throws SQLException {
        String sqlContarEstados = "SELECT " +
                "SUM(CASE WHEN state = 'Pagado' THEN 1 ELSE 0 END) AS pagadas, " +
                "SUM(CASE WHEN state = 'Parcial' THEN 1 ELSE 0 END) AS parciales, " +
                "SUM(CASE WHEN state = 'Pendiente' THEN 1 ELSE 0 END) AS pendientes, " +
                "COUNT(*) AS total " +
                "FROM abonodetail WHERE AbonoID = ?";

        int pagadas = 0, total = 0;
        try (PreparedStatement stmt = conn.prepareStatement(sqlContarEstados)) {
            stmt.setLong(1, abonoId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    pagadas = rs.getInt("pagadas");
                    total = rs.getInt("total");
                }
            }
        }

        String nuevoEstado = (pagadas == total && total > 0) ? "Pagado" : "Pendiente";

        String sqlUpdateAbono = "UPDATE abono SET status = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateAbono)) {
            stmt.setString(1, nuevoEstado);
            stmt.setLong(2, abonoId);
            stmt.executeUpdate();
        }
    }

    // â”€â”€â”€ Cuotas (lecturas) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.buscarCuotasPrestamosPendientesEmpleado(). */
    public List<Map<String, Object>> buscarCuotasPrestamosPendientesEmpleado(int empleadoId) {
        String sql = "SELECT ld.ID, l.SoliNum, ld.Dues, ld.MonthlyFeeValue, ld.payment, " +
                "(ld.MonthlyFeeValue - COALESCE(ld.payment, 0)) AS pendiente, ld.State " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE l.EmployeeID = ? " +
                "AND (ld.State = 'Pendiente' OR ld.State = 'Parcial') " +
                "ORDER BY l.SoliNum, ld.Dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("ID"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("State"));
            return m;
        }, empleadoId);
    }

    /** Replica RegistroDao.buscarCuotasAbonosPendientesEmpleado(). */
    public List<Map<String, Object>> buscarCuotasAbonosPendientesEmpleado(int empleadoId) {
        String sql = "SELECT ad.id, a.SoliNum, COALESCE(sc.description, 'Sin concepto') AS concepto, " +
                "ad.dues, ad.monthly, ad.payment, " +
                "(ad.monthly - COALESCE(ad.payment, 0)) AS pendiente, ad.state " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                "WHERE a.Employee_id = ? " +
                "AND (ad.state = 'Pendiente' OR ad.state = 'Parcial') " +
                "ORDER BY a.SoliNum, ad.dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("id"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("concepto", rs.getString("concepto"));
            m.put("dues", rs.getInt("dues"));
            m.put("monthly", rs.getDouble("monthly"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("state"));
            return m;
        }, empleadoId);
    }

    /** Replica RegistroDao.buscarCuotasPrestamoPorSolicitud(). */
    public List<Map<String, Object>> buscarCuotasPrestamoPorSolicitud(String soliNum) {
        String sql = "SELECT ld.ID, l.SoliNum, ld.Dues, ld.MonthlyFeeValue, COALESCE(ld.payment, 0) AS payment, " +
                "(ld.MonthlyFeeValue - COALESCE(ld.payment, 0)) AS pendiente, ld.State, l.Dues AS totalCuotas " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE l.SoliNum = ? " +
                "ORDER BY ld.Dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("ID"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("State"));
            m.put("totalCuotas", rs.getInt("totalCuotas"));
            return m;
        }, soliNum);
    }

    /** Replica RegistroDao.buscarCuotasAbonoPorSolicitud(). */
    public List<Map<String, Object>> buscarCuotasAbonoPorSolicitud(String soliNum) {
        String sql = "SELECT ad.id, a.SoliNum, COALESCE(sc.description, 'Sin concepto') AS concepto, " +
                "ad.dues, ad.monthly, COALESCE(ad.payment, 0) AS payment, " +
                "(ad.monthly - COALESCE(ad.payment, 0)) AS pendiente, ad.state, a.dues AS totalCuotas " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                "WHERE a.SoliNum = ? " +
                "ORDER BY ad.dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("id"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("concepto", rs.getString("concepto"));
            m.put("dues", rs.getInt("dues"));
            m.put("monthly", rs.getDouble("monthly"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("state"));
            m.put("totalCuotas", rs.getInt("totalCuotas"));
            return m;
        }, soliNum);
    }

    /** Replica RegistroDao.buscarTodasCuotasPrestamosEmpleado(). */
    public List<Map<String, Object>> buscarTodasCuotasPrestamosEmpleado(int empleadoId) {
        String sql = "SELECT ld.ID, l.SoliNum, ld.Dues, ld.MonthlyFeeValue, COALESCE(ld.payment, 0) AS payment, " +
                "(ld.MonthlyFeeValue - COALESCE(ld.payment, 0)) AS pendiente, ld.State " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE l.EmployeeID = ? " +
                "ORDER BY l.SoliNum, ld.Dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("ID"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("State"));
            return m;
        }, empleadoId);
    }

    /** Replica RegistroDao.buscarTodasCuotasAbonosEmpleado(). */
    public List<Map<String, Object>> buscarTodasCuotasAbonosEmpleado(int empleadoId) {
        String sql = "SELECT ad.id, a.SoliNum, COALESCE(sc.description, 'Sin concepto') AS concepto, " +
                "ad.dues, ad.monthly, COALESCE(ad.payment, 0) AS payment, " +
                "(ad.monthly - COALESCE(ad.payment, 0)) AS pendiente, ad.state " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                "WHERE a.Employee_id = ? " +
                "ORDER BY a.SoliNum, ad.dues";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("id"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("concepto", rs.getString("concepto"));
            m.put("dues", rs.getInt("dues"));
            m.put("monthly", rs.getDouble("monthly"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("state"));
            return m;
        }, empleadoId);
    }

    // â”€â”€â”€ Agregar detalles a un registro existente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.agregarDetallePrestamoARegistro() (transaccional). */
    public boolean agregarDetallePrestamoARegistro(int registroId, long loanDetailId, double monto,
                                                   String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            Long loanId = null;
            String soliNum = null;
            int cuota = 0;
            String sqlGetInfo = "SELECT ld.LoanID, ld.Dues, l.SoliNum FROM loandetail ld " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID WHERE ld.ID = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetInfo)) {
                stmt.setLong(1, loanDetailId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        loanId = rs.getLong("LoanID");
                        cuota = rs.getInt("Dues");
                        soliNum = rs.getString("SoliNum");
                    }
                }
            }

            String sqlInsert = "INSERT INTO registerdetails (idRegistro, idLoanDetails, amountPar) VALUES (?, ?, ?)";
            try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                stmt.setInt(1, registroId);
                stmt.setLong(2, loanDetailId);
                stmt.setDouble(3, monto);
                stmt.executeUpdate();
            }

            String sqlUpdate = "UPDATE loandetail SET payment = COALESCE(payment, 0) + ?, " +
                    "State = CASE " +
                    "  WHEN COALESCE(payment, 0) + ? >= MonthlyFeeValue THEN 'Pagado' " +
                    "  WHEN COALESCE(payment, 0) + ? > 0 THEN 'Parcial' " +
                    "  ELSE 'Pendiente' " +
                    "END " +
                    "WHERE ID = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
                stmt.setDouble(1, monto);
                stmt.setDouble(2, monto);
                stmt.setDouble(3, monto);
                stmt.setLong(4, loanDetailId);
                stmt.executeUpdate();
            }

            if (loanId != null) {
                actualizarEstadoGeneralLoan(conn, loanId);
            }

            guardarHistorialCorreccion(conn, "AGREGAR_PRESTAMO_REGISTRO",
                    soliNum != null ? soliNum : "LOAN-" + loanId, cuota,
                    0, monto, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error agregando detalle prÃ©stamo: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /** Replica RegistroDao.agregarDetalleAbonoARegistro() (transaccional). */
    public boolean agregarDetalleAbonoARegistro(int registroId, long abonoDetailId, double monto,
                                                String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            Long abonoId = null;
            String soliNum = null;
            int cuota = 0;
            String sqlGetInfo = "SELECT ad.AbonoID, ad.dues, a.SoliNum FROM abonodetail ad " +
                    "INNER JOIN abono a ON ad.AbonoID = a.id WHERE ad.id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetInfo)) {
                stmt.setLong(1, abonoDetailId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        abonoId = rs.getLong("AbonoID");
                        cuota = rs.getInt("dues");
                        soliNum = rs.getString("SoliNum");
                    }
                }
            }

            String sqlInsert = "INSERT INTO registerdetails (idRegistro, idBondDetails, amountPar) VALUES (?, ?, ?)";
            try (PreparedStatement stmt = conn.prepareStatement(sqlInsert)) {
                stmt.setInt(1, registroId);
                stmt.setLong(2, abonoDetailId);
                stmt.setDouble(3, monto);
                stmt.executeUpdate();
            }

            String sqlUpdate = "UPDATE abonodetail SET payment = COALESCE(payment, 0) + ?, " +
                    "state = CASE " +
                    "  WHEN COALESCE(payment, 0) + ? >= monthly THEN 'Pagado' " +
                    "  WHEN COALESCE(payment, 0) + ? > 0 THEN 'Parcial' " +
                    "  ELSE 'Pendiente' " +
                    "END " +
                    "WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
                stmt.setDouble(1, monto);
                stmt.setDouble(2, monto);
                stmt.setDouble(3, monto);
                stmt.setLong(4, abonoDetailId);
                stmt.executeUpdate();
            }

            if (abonoId != null) {
                actualizarEstadoGeneralAbono(conn, abonoId);
            }

            guardarHistorialCorreccion(conn, "AGREGAR_ABONO_REGISTRO",
                    soliNum != null ? soliNum : "ABONO-" + abonoId, cuota,
                    0, monto, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error agregando detalle abono: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /** Replica RegistroDao.obtenerDetallesCompletoPago(). */
    public Map<String, Object> obtenerDetallesCompletoPago(int registroId) {
        Map<String, Object> resultado = new LinkedHashMap<>();
        List<Map<String, Object>> prestamos = new ArrayList<>();
        List<Map<String, Object>> abonos = new ArrayList<>();
        String empleadoNombre = "";
        String empleadoDni = "";
        int empleadoId = 0;

        try (Connection conn = ftDataSource.getConnection()) {
            String sqlEmpleado = "SELECT e.employee_id, e.fullName, e.national_id " +
                    "FROM registro r " +
                    "INNER JOIN employees e ON r.empleado_id = e.employee_id " +
                    "WHERE r.id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlEmpleado)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        empleadoId = rs.getInt("employee_id");
                        empleadoNombre = rs.getString("fullName");
                        empleadoDni = rs.getString("national_id");
                    }
                }
            }

            String sqlPrestamos = "SELECT l.SoliNum, ld.Dues, ld.MonthlyFeeValue, ld.payment AS totalPagadoCuota, " +
                    "rd.amountPar, rd.id as rdId, ld.ID as ldId, ld.State " +
                    "FROM registerdetails rd " +
                    "INNER JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE rd.idRegistro = ? AND rd.idLoanDetails IS NOT NULL " +
                    "ORDER BY l.SoliNum, ld.Dues";
            try (PreparedStatement stmt = conn.prepareStatement(sqlPrestamos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("soliNum", rs.getString("SoliNum"));
                        m.put("dues", rs.getInt("Dues"));
                        m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
                        m.put("totalPagadoCuota", rs.getDouble("totalPagadoCuota"));
                        m.put("amountPar", rs.getDouble("amountPar"));
                        m.put("rdId", rs.getLong("rdId"));
                        m.put("ldId", rs.getLong("ldId"));
                        m.put("state", rs.getString("State"));
                        prestamos.add(m);
                    }
                }
            }

            String sqlAbonos = "SELECT a.SoliNum, COALESCE(sc.description, 'Sin concepto') AS concepto, " +
                    "ad.dues, ad.monthly, ad.payment AS totalPagadoCuota, " +
                    "rd.amountPar, rd.id as rdId, ad.id as adId, ad.state " +
                    "FROM registerdetails rd " +
                    "INNER JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                    "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                    "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                    "WHERE rd.idRegistro = ? AND rd.idBondDetails IS NOT NULL " +
                    "ORDER BY a.SoliNum, ad.dues";
            try (PreparedStatement stmt = conn.prepareStatement(sqlAbonos)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("soliNum", rs.getString("SoliNum"));
                        m.put("concepto", rs.getString("concepto"));
                        m.put("dues", rs.getInt("dues"));
                        m.put("monthly", rs.getDouble("monthly"));
                        m.put("totalPagadoCuota", rs.getDouble("totalPagadoCuota"));
                        m.put("amountPar", rs.getDouble("amountPar"));
                        m.put("rdId", rs.getLong("rdId"));
                        m.put("adId", rs.getLong("adId"));
                        m.put("state", rs.getString("state"));
                        abonos.add(m);
                    }
                }
            }
        } catch (SQLException e) {
            throw new IllegalStateException(
                    "Error obteniendo detalle completo del pago: " + e.getMessage(), e);
        }

        resultado.put("prestamos", prestamos);
        resultado.put("abonos", abonos);
        resultado.put("empleadoNombre", empleadoNombre);
        resultado.put("empleadoDni", empleadoDni);
        resultado.put("empleadoId", empleadoId);
        return resultado;
    }

    // â”€â”€â”€ Cuotas con voucher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.buscarCuotasPrestamosConVoucher(). */
    public List<Map<String, Object>> buscarCuotasPrestamosConVoucher(String soliNum, int empleadoId, boolean mostrarTodas) {
        String sql = "SELECT ld.ID, l.SoliNum, ld.Dues, ld.MonthlyFeeValue, COALESCE(ld.payment, 0) AS payment, " +
                "(ld.MonthlyFeeValue - COALESCE(ld.payment, 0)) AS pendiente, ld.State, " +
                "r.codigo AS voucherCodigo, r.id AS voucherId, rd.id AS rdId, rd.amountPar " +
                "FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "LEFT JOIN registerdetails rd ON rd.idLoanDetails = ld.ID " +
                "LEFT JOIN registro r ON rd.idRegistro = r.id " +
                "WHERE l.EmployeeID = ? ";

        if (soliNum != null && !soliNum.trim().isEmpty()) {
            sql += "AND l.SoliNum LIKE ? ";
        }
        if (!mostrarTodas) {
            sql += "AND (ld.State != 'Pagado' OR ld.State IS NULL) ";
        }
        sql += "ORDER BY l.SoliNum, ld.Dues, r.fecha_registro DESC";

        Object[] params = (soliNum != null && !soliNum.trim().isEmpty())
                ? new Object[]{empleadoId, "%" + soliNum + "%"}
                : new Object[]{empleadoId};

        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("ID"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("dues", rs.getInt("Dues"));
            m.put("monthlyFeeValue", rs.getDouble("MonthlyFeeValue"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("State"));
            m.put("voucherCodigo", rs.getString("voucherCodigo"));
            m.put("voucherId", rs.getObject("voucherId") != null ? rs.getInt("voucherId") : null);
            m.put("rdId", rs.getObject("rdId") != null ? rs.getLong("rdId") : null);
            m.put("amountPar", rs.getObject("amountPar") != null ? rs.getDouble("amountPar") : 0.0);
            return m;
        }, params);
    }

    /** Replica RegistroDao.buscarCuotasAbonosConVoucher(). */
    public List<Map<String, Object>> buscarCuotasAbonosConVoucher(String soliNum, int empleadoId, boolean mostrarTodas) {
        String sql = "SELECT ad.id, a.SoliNum, COALESCE(sc.description, 'Sin concepto') AS concepto, " +
                "ad.dues, ad.monthly, COALESCE(ad.payment, 0) AS payment, " +
                "(ad.monthly - COALESCE(ad.payment, 0)) AS pendiente, ad.state, " +
                "r.codigo AS voucherCodigo, r.id AS voucherId, rd.id AS rdId, rd.amountPar " +
                "FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "LEFT JOIN service_concept sc ON a.service_concept_id = sc.id " +
                "LEFT JOIN registerdetails rd ON rd.idBondDetails = ad.id " +
                "LEFT JOIN registro r ON rd.idRegistro = r.id " +
                "WHERE a.Employee_id = ? ";

        if (soliNum != null && !soliNum.trim().isEmpty()) {
            sql += "AND a.SoliNum LIKE ? ";
        }
        if (!mostrarTodas) {
            sql += "AND (ad.state != 'Pagado' OR ad.state IS NULL) ";
        }
        sql += "ORDER BY a.SoliNum, ad.dues, r.fecha_registro DESC";

        Object[] params = (soliNum != null && !soliNum.trim().isEmpty())
                ? new Object[]{empleadoId, "%" + soliNum + "%"}
                : new Object[]{empleadoId};

        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("id"));
            m.put("soliNum", rs.getString("SoliNum"));
            m.put("concepto", rs.getString("concepto"));
            m.put("dues", rs.getInt("dues"));
            m.put("monthly", rs.getDouble("monthly"));
            m.put("payment", rs.getDouble("payment"));
            m.put("pendiente", rs.getDouble("pendiente"));
            m.put("state", rs.getString("state"));
            m.put("voucherCodigo", rs.getString("voucherCodigo"));
            m.put("voucherId", rs.getObject("voucherId") != null ? rs.getInt("voucherId") : null);
            m.put("rdId", rs.getObject("rdId") != null ? rs.getLong("rdId") : null);
            m.put("amountPar", rs.getObject("amountPar") != null ? rs.getDouble("amountPar") : 0.0);
            return m;
        }, params);
    }

    // â”€â”€â”€ Transferencias de pagos entre vouchers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.transferirPagoPrestamoAVoucher() (transaccional). */
    public boolean transferirPagoPrestamoAVoucher(long rdIdOrigen, long loanDetailId, int registroIdDestino,
                                                  double montoTransferir, String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            int voucherOrigenId = 0;
            double montoOriginal = 0;
            String sqlGetOrigen = "SELECT idRegistro, amountPar FROM registerdetails WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetOrigen)) {
                stmt.setLong(1, rdIdOrigen);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        voucherOrigenId = rs.getInt("idRegistro");
                        montoOriginal = rs.getDouble("amountPar");
                    }
                }
            }

            if (voucherOrigenId == 0) {
                throw new SQLException("No se encontrÃ³ el pago original");
            }

            String sqlDeleteOrigen = "DELETE FROM registerdetails WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteOrigen)) {
                stmt.setLong(1, rdIdOrigen);
                stmt.executeUpdate();
            }

            String sqlRevertLoan = "UPDATE loandetail SET payment = GREATEST(0, COALESCE(payment, 0) - ?), " +
                    "State = CASE " +
                    "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) = 0 THEN 'Pendiente' " +
                    "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) < MonthlyFeeValue THEN 'Parcial' " +
                    "  ELSE 'Pagado' " +
                    "END " +
                    "WHERE ID = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlRevertLoan)) {
                stmt.setDouble(1, montoOriginal);
                stmt.setDouble(2, montoOriginal);
                stmt.setDouble(3, montoOriginal);
                stmt.setLong(4, loanDetailId);
                stmt.executeUpdate();
            }

            String sqlInsertDestino = "INSERT INTO registerdetails (idRegistro, idLoanDetails, amountPar) VALUES (?, ?, ?)";
            try (PreparedStatement stmt = conn.prepareStatement(sqlInsertDestino)) {
                stmt.setInt(1, registroIdDestino);
                stmt.setLong(2, loanDetailId);
                stmt.setDouble(3, montoTransferir);
                stmt.executeUpdate();
            }

            String sqlApplyLoan = "UPDATE loandetail SET payment = COALESCE(payment, 0) + ?, " +
                    "State = CASE " +
                    "  WHEN COALESCE(payment, 0) + ? >= MonthlyFeeValue THEN 'Pagado' " +
                    "  WHEN COALESCE(payment, 0) + ? > 0 THEN 'Parcial' " +
                    "  ELSE 'Pendiente' " +
                    "END " +
                    "WHERE ID = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlApplyLoan)) {
                stmt.setDouble(1, montoTransferir);
                stmt.setDouble(2, montoTransferir);
                stmt.setDouble(3, montoTransferir);
                stmt.setLong(4, loanDetailId);
                stmt.executeUpdate();
            }

            Long loanId = null;
            String sqlGetLoanId = "SELECT LoanID FROM loandetail WHERE ID = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetLoanId)) {
                stmt.setLong(1, loanDetailId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        loanId = rs.getLong("LoanID");
                    }
                }
            }
            if (loanId != null) {
                actualizarEstadoGeneralLoan(conn, loanId);
            }

            eliminarVoucherSiVacio(conn, voucherOrigenId, usuario);

            guardarHistorialCorreccion(conn, "TRANSFERIR_PRESTAMO_VOUCHER",
                    "ORIGEN-REG-" + voucherOrigenId + "/DESTINO-REG-" + registroIdDestino + "/LD-" + loanDetailId,
                    0, montoOriginal, montoTransferir, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error transfiriendo pago prÃ©stamo: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /** Replica RegistroDao.transferirPagoAbonoAVoucher() (transaccional). */
    public boolean transferirPagoAbonoAVoucher(long rdIdOrigen, long abonoDetailId, int registroIdDestino,
                                               double montoTransferir, String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            int voucherOrigenId = 0;
            double montoOriginal = 0;
            String sqlGetOrigen = "SELECT idRegistro, amountPar FROM registerdetails WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetOrigen)) {
                stmt.setLong(1, rdIdOrigen);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        voucherOrigenId = rs.getInt("idRegistro");
                        montoOriginal = rs.getDouble("amountPar");
                    }
                }
            }

            if (voucherOrigenId == 0) {
                throw new SQLException("No se encontrÃ³ el pago original");
            }

            String sqlDeleteOrigen = "DELETE FROM registerdetails WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteOrigen)) {
                stmt.setLong(1, rdIdOrigen);
                stmt.executeUpdate();
            }

            String sqlRevertAbono = "UPDATE abonodetail SET payment = GREATEST(0, COALESCE(payment, 0) - ?), " +
                    "state = CASE " +
                    "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) = 0 THEN 'Pendiente' " +
                    "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) < monthly THEN 'Parcial' " +
                    "  ELSE 'Pagado' " +
                    "END " +
                    "WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlRevertAbono)) {
                stmt.setDouble(1, montoOriginal);
                stmt.setDouble(2, montoOriginal);
                stmt.setDouble(3, montoOriginal);
                stmt.setLong(4, abonoDetailId);
                stmt.executeUpdate();
            }

            String sqlInsertDestino = "INSERT INTO registerdetails (idRegistro, idBondDetails, amountPar) VALUES (?, ?, ?)";
            try (PreparedStatement stmt = conn.prepareStatement(sqlInsertDestino)) {
                stmt.setInt(1, registroIdDestino);
                stmt.setLong(2, abonoDetailId);
                stmt.setDouble(3, montoTransferir);
                stmt.executeUpdate();
            }

            String sqlApplyAbono = "UPDATE abonodetail SET payment = COALESCE(payment, 0) + ?, " +
                    "state = CASE " +
                    "  WHEN COALESCE(payment, 0) + ? >= monthly THEN 'Pagado' " +
                    "  WHEN COALESCE(payment, 0) + ? > 0 THEN 'Parcial' " +
                    "  ELSE 'Pendiente' " +
                    "END " +
                    "WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlApplyAbono)) {
                stmt.setDouble(1, montoTransferir);
                stmt.setDouble(2, montoTransferir);
                stmt.setDouble(3, montoTransferir);
                stmt.setLong(4, abonoDetailId);
                stmt.executeUpdate();
            }

            Long abonoId = null;
            String sqlGetAbonoId = "SELECT AbonoID FROM abonodetail WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetAbonoId)) {
                stmt.setLong(1, abonoDetailId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        abonoId = rs.getLong("AbonoID");
                    }
                }
            }
            if (abonoId != null) {
                actualizarEstadoGeneralAbono(conn, abonoId);
            }

            eliminarVoucherSiVacio(conn, voucherOrigenId, usuario);

            guardarHistorialCorreccion(conn, "TRANSFERIR_ABONO_VOUCHER",
                    "ORIGEN-REG-" + voucherOrigenId + "/DESTINO-REG-" + registroIdDestino + "/AD-" + abonoDetailId,
                    0, montoOriginal, montoTransferir, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error transfiriendo pago abono: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    /** Replica RegistroDao.eliminarVoucherSiVacio() (endpoint suelto). */
    public boolean eliminarVoucherSiVacio(int registroId, String usuario) {
        try (Connection conn = ftDataSource.getConnection()) {
            return eliminarVoucherSiVacio(conn, registroId, usuario);
        } catch (SQLException e) {
            System.out.println("Error verificando/eliminando voucher vacÃ­o: " + e.getMessage());
            return false;
        }
    }

    /** Version con Connection compartida, usada dentro de las transferencias. */
    private boolean eliminarVoucherSiVacio(Connection conn, int registroId, String usuario) {
        try {
            String sqlContarDetalles = "SELECT COUNT(*) AS total FROM registerdetails WHERE idRegistro = ?";
            int totalDetalles = 0;
            try (PreparedStatement stmt = conn.prepareStatement(sqlContarDetalles)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        totalDetalles = rs.getInt("total");
                    }
                }
            }

            if (totalDetalles == 0) {
                String codigoVoucher = "";
                double montoVoucher = 0;
                String sqlGetVoucher = "SELECT codigo, amount FROM registro WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetVoucher)) {
                    stmt.setInt(1, registroId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            codigoVoucher = rs.getString("codigo");
                            montoVoucher = rs.getDouble("amount");
                        }
                    }
                }

                String sqlDelete = "DELETE FROM registro WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlDelete)) {
                    stmt.setInt(1, registroId);
                    stmt.executeUpdate();
                }

                guardarHistorialCorreccion(conn, "ELIMINAR_VOUCHER_VACIO",
                        "REG-" + registroId + "/COD-" + codigoVoucher,
                        0, montoVoucher, 0, usuario, "Voucher eliminado por quedar vacÃ­o despuÃ©s de transferencia");
                return true;
            }
            return false;
        } catch (SQLException e) {
            System.out.println("Error verificando/eliminando voucher vacÃ­o: " + e.getMessage());
            return false;
        }
    }

    /** Replica RegistroDao.eliminarVoucherCompleto() (transaccional). */
    public boolean eliminarVoucherCompleto(int registroId, String usuario, String motivo) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String codigoVoucher = "";
            double montoVoucher = 0;
            String sqlGetVoucher = "SELECT codigo, amount FROM registro WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlGetVoucher)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        codigoVoucher = rs.getString("codigo");
                        montoVoucher = rs.getDouble("amount");
                    }
                }
            }

            List<Object[]> detalles = new ArrayList<>();
            String sqlDetalles = "SELECT id, idBondDetails, idLoanDetails, amountPar FROM registerdetails WHERE idRegistro = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDetalles)) {
                stmt.setInt(1, registroId);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        Object[] det = new Object[4];
                        det[0] = rs.getLong("id");
                        det[1] = rs.getObject("idBondDetails");
                        det[2] = rs.getObject("idLoanDetails");
                        det[3] = rs.getDouble("amountPar");
                        detalles.add(det);
                    }
                }
            }

            for (Object[] det : detalles) {
                Long bondId = det[1] != null ? ((Number) det[1]).longValue() : null;
                Long loanId = det[2] != null ? ((Number) det[2]).longValue() : null;
                double monto = (Double) det[3];

                if (loanId != null) {
                    String sqlRevert = "UPDATE loandetail SET payment = GREATEST(0, COALESCE(payment, 0) - ?), " +
                            "State = CASE " +
                            "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) = 0 THEN 'Pendiente' " +
                            "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) < MonthlyFeeValue THEN 'Parcial' " +
                            "  ELSE 'Pagado' " +
                            "END WHERE ID = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlRevert)) {
                        stmt.setDouble(1, monto);
                        stmt.setDouble(2, monto);
                        stmt.setDouble(3, monto);
                        stmt.setLong(4, loanId);
                        stmt.executeUpdate();
                    }

                    Long parentLoanId = null;
                    String sqlGetParent = "SELECT LoanID FROM loandetail WHERE ID = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlGetParent)) {
                        stmt.setLong(1, loanId);
                        try (ResultSet rs = stmt.executeQuery()) {
                            if (rs.next()) parentLoanId = rs.getLong("LoanID");
                        }
                    }
                    if (parentLoanId != null) actualizarEstadoGeneralLoan(conn, parentLoanId);
                }

                if (bondId != null) {
                    String sqlRevert = "UPDATE abonodetail SET payment = GREATEST(0, COALESCE(payment, 0) - ?), " +
                            "state = CASE " +
                            "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) = 0 THEN 'Pendiente' " +
                            "  WHEN GREATEST(0, COALESCE(payment, 0) - ?) < monthly THEN 'Parcial' " +
                            "  ELSE 'Pagado' " +
                            "END WHERE id = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlRevert)) {
                        stmt.setDouble(1, monto);
                        stmt.setDouble(2, monto);
                        stmt.setDouble(3, monto);
                        stmt.setLong(4, bondId);
                        stmt.executeUpdate();
                    }

                    Long parentAbonoId = null;
                    String sqlGetParent = "SELECT AbonoID FROM abonodetail WHERE id = ?";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlGetParent)) {
                        stmt.setLong(1, bondId);
                        try (ResultSet rs = stmt.executeQuery()) {
                            if (rs.next()) parentAbonoId = rs.getLong("AbonoID");
                        }
                    }
                    if (parentAbonoId != null) actualizarEstadoGeneralAbono(conn, parentAbonoId);
                }
            }

            String sqlDeleteDetalles = "DELETE FROM registerdetails WHERE idRegistro = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteDetalles)) {
                stmt.setInt(1, registroId);
                stmt.executeUpdate();
            }

            String sqlDeleteRegistro = "DELETE FROM registro WHERE id = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRegistro)) {
                stmt.setInt(1, registroId);
                stmt.executeUpdate();
            }

            guardarHistorialCorreccion(conn, "ELIMINAR_VOUCHER_COMPLETO",
                    "REG-" + registroId + "/COD-" + codigoVoucher,
                    0, montoVoucher, 0, usuario, motivo);

            conn.commit();
            return true;
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("Error eliminando voucher completo: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    // â”€â”€â”€ Autocompletado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.obtenerCodigosSolicitudesPrestamos(). */
    public List<String> obtenerCodigosSolicitudesPrestamos() {
        return ftJdbc.queryForList(
                "SELECT DISTINCT l.SoliNum FROM loan l "
                        + "WHERE l.SoliNum IS NOT NULL AND l.SoliNum != '' "
                        + "ORDER BY l.SoliNum",
                new MapSqlParameterSource(), String.class);
    }

    /** Replica RegistroDao.obtenerCodigosSolicitudesAbonos(). */
    public List<String> obtenerCodigosSolicitudesAbonos() {
        return ftJdbc.queryForList(
                "SELECT DISTINCT a.SoliNum FROM abono a "
                        + "WHERE a.SoliNum IS NOT NULL AND a.SoliNum != '' "
                        + "ORDER BY a.SoliNum",
                new MapSqlParameterSource(), String.class);
    }

    /** Replica RegistroDao.obtenerCodigosTickets(). */
    public List<String> obtenerCodigosTickets() {
        return ftJdbc.queryForList(
                "SELECT DISTINCT r.codigo FROM registro r "
                        + "WHERE r.codigo IS NOT NULL AND r.codigo != '' "
                        + "ORDER BY r.codigo DESC "
                        + "LIMIT 500",
                new MapSqlParameterSource(), String.class);
    }

    /** Replica RegistroDao.obtenerCodigosSolicitudesPrestamosPorEmpleado(). */
    public List<String> obtenerCodigosSolicitudesPrestamosPorEmpleado(int empleadoId) {
        return ftJdbc.queryForList(
                "SELECT DISTINCT l.SoliNum FROM loan l "
                        + "WHERE l.EmployeeID = :eid AND l.SoliNum IS NOT NULL AND l.SoliNum != '' "
                        + "ORDER BY l.SoliNum",
                new MapSqlParameterSource("eid", empleadoId), String.class);
    }

    /** Replica RegistroDao.obtenerCodigosSolicitudesAbonosPorEmpleado(). */
    public List<String> obtenerCodigosSolicitudesAbonosPorEmpleado(int empleadoId) {
        return ftJdbc.queryForList(
                "SELECT DISTINCT a.SoliNum FROM abono a "
                        + "WHERE a.Employee_id = :eid AND a.SoliNum IS NOT NULL AND a.SoliNum != '' "
                        + "ORDER BY a.SoliNum",
                new MapSqlParameterSource("eid", empleadoId), String.class);
    }

    // â”€â”€â”€ Revertir ultimos cambios â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** Replica RegistroDao.obtenerUltimosCambios(). */
    public List<Map<String, Object>> obtenerUltimosCambios(int limite) {
        String sql = "SELECT id, tipo, solicitud, cuota, pago_anterior, pago_nuevo, usuario, motivo, fecha_correccion " +
                "FROM historial_correcciones " +
                "ORDER BY fecha_correccion DESC, id DESC " +
                "LIMIT ?";
        return queryList(sql, rs -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", rs.getLong("id"));
            m.put("tipo", rs.getString("tipo"));
            m.put("solicitud", rs.getString("solicitud"));
            m.put("cuota", rs.getInt("cuota"));
            m.put("pagoAnterior", rs.getDouble("pago_anterior"));
            m.put("pagoNuevo", rs.getDouble("pago_nuevo"));
            m.put("usuario", rs.getString("usuario"));
            m.put("motivo", rs.getString("motivo"));
            m.put("fechaCorreccion", ts(rs.getTimestamp("fecha_correccion")));
            return m;
        }, limite);
    }

    /**
     * Replica RegistroDao.revertirCambio(): deshace segun el tipo guardado
     * en historial_correcciones y marca la fila como [REVERTIDO ...] o
     * [NO REVERTIBLE ...], transaccional.
     */
    public boolean revertirCambio(long historialId, String usuario) {
        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();

            String sqlGet = "SELECT tipo, solicitud, cuota, pago_anterior, pago_nuevo, motivo " +
                    "FROM historial_correcciones WHERE id = ?";

            String tipo = null;
            String solicitud = null;
            int cuota = 0;
            double pagoAnterior = 0;
            double pagoNuevo = 0;
            String motivoOriginal = null;

            try (PreparedStatement stmt = conn.prepareStatement(sqlGet)) {
                stmt.setLong(1, historialId);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        tipo = rs.getString("tipo");
                        solicitud = rs.getString("solicitud");
                        cuota = rs.getInt("cuota");
                        pagoAnterior = rs.getDouble("pago_anterior");
                        pagoNuevo = rs.getDouble("pago_nuevo");
                        motivoOriginal = rs.getString("motivo");
                    } else {
                        return false;
                    }
                }
            }

            conn.setAutoCommit(false);

            boolean exito;
            switch (tipo) {
                case "TRANSFERIR_PRESTAMO_VOUCHER":
                    exito = revertirTransferenciaPrestamo(conn, solicitud, cuota, pagoAnterior, pagoNuevo, motivoOriginal, usuario);
                    break;
                case "TRANSFERIR_ABONO_VOUCHER":
                    exito = revertirTransferenciaAbono(conn, solicitud, cuota, pagoAnterior, pagoNuevo, motivoOriginal, usuario);
                    break;
                case "AGREGAR_PRESTAMO_REGISTRO":
                    exito = revertirAgregarPrestamo(conn, solicitud, cuota, pagoNuevo, usuario);
                    break;
                case "AGREGAR_ABONO_REGISTRO":
                    exito = revertirAgregarAbono(conn, solicitud, cuota, pagoNuevo, usuario);
                    break;
                case "EDICION_PRESTAMO":
                    exito = revertirEdicionPrestamo(conn, solicitud, pagoAnterior, pagoNuevo, usuario);
                    break;
                case "EDICION_ABONO":
                    exito = revertirEdicionAbono(conn, solicitud, pagoAnterior, pagoNuevo, usuario);
                    break;
                case "ELIMINACION_PRESTAMO":
                case "ELIMINACION_ABONO":
                    conn.rollback();
                    return false;
                default:
                    conn.rollback();
                    return false;
            }

            if (exito) {
                String sqlMark = "UPDATE historial_correcciones SET motivo = CONCAT(COALESCE(motivo, ''), ' [REVERTIDO por ', ?, ' el ', NOW(), ']') WHERE id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlMark)) {
                    stmt.setString(1, usuario);
                    stmt.setLong(2, historialId);
                    stmt.executeUpdate();
                }
                conn.commit();
                return true;
            } else {
                conn.rollback();
                try {
                    conn.setAutoCommit(true);
                    String sqlMarkFailed = "UPDATE historial_correcciones SET motivo = CONCAT(COALESCE(motivo, ''), ' [NO REVERTIBLE - Registro eliminado o movido]') WHERE id = ? AND motivo NOT LIKE '%NO REVERTIBLE%'";
                    try (PreparedStatement stmt = conn.prepareStatement(sqlMarkFailed)) {
                        stmt.setLong(1, historialId);
                        stmt.executeUpdate();
                    }
                } catch (SQLException markEx) {
                    System.out.println("No se pudo marcar como no revertible: " + markEx.getMessage());
                }
                return false;
            }
        } catch (SQLException e) {
            rollbackQuieto(conn);
            System.out.println("ERROR SQL revirtiendo cambio: " + e.getMessage());
            return false;
        } finally {
            cerrarQuieto(conn);
        }
    }

    private boolean revertirTransferenciaPrestamo(Connection conn, String solicitud, int cuota,
                                                  double montoOrigen, double montoDestino,
                                                  String motivoOriginal, String usuario) throws SQLException {
        String sqlFind = "SELECT ld.ID, ld.payment, ld.MonthlyFeeValue FROM loandetail ld " +
                "INNER JOIN loan l ON ld.LoanID = l.ID " +
                "WHERE l.SoliNum = ? AND ld.Dues = ?";

        Long loanDetailId = null;
        double paymentActual = 0;
        double monthlyFee = 0;

        try (PreparedStatement stmt = conn.prepareStatement(sqlFind)) {
            stmt.setString(1, solicitud.split("-")[0] + "-" + solicitud.split("-")[1]);
            stmt.setInt(2, cuota);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    loanDetailId = rs.getLong("ID");
                    paymentActual = rs.getDouble("payment");
                    monthlyFee = rs.getDouble("MonthlyFeeValue");
                }
            }
        }

        if (loanDetailId == null) {
            return false;
        }

        double nuevoPayment = Math.max(0, paymentActual - montoDestino);
        String nuevoEstado = nuevoPayment == 0 ? "Pendiente" : (nuevoPayment < monthlyFee ? "Parcial" : "Pagado");

        String sqlUpdate = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
            stmt.setDouble(1, nuevoPayment);
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, loanDetailId);
            stmt.executeUpdate();
        }

        String sqlDeleteRd = "DELETE FROM registerdetails WHERE idLoanDetails = ? ORDER BY id DESC LIMIT 1";
        try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRd)) {
            stmt.setLong(1, loanDetailId);
            stmt.executeUpdate();
        }

        guardarHistorialCorreccion(conn, "REVERTIR_TRANSFERENCIA_PRESTAMO", solicitud, cuota, montoDestino, nuevoPayment, usuario, "ReversiÃ³n de transferencia");
        return true;
    }

    private boolean revertirTransferenciaAbono(Connection conn, String solicitud, int cuota,
                                               double montoOrigen, double montoDestino,
                                               String motivoOriginal, String usuario) throws SQLException {
        String sqlFind = "SELECT ad.id, ad.payment, ad.monthly FROM abonodetail ad " +
                "INNER JOIN abono a ON ad.AbonoID = a.ID " +
                "WHERE a.SoliNum = ? AND ad.dues = ?";

        Long abonoDetailId = null;
        double paymentActual = 0;
        double monthly = 0;

        String soliNum = solicitud.contains("-") ? solicitud.substring(0, solicitud.lastIndexOf("-")) : solicitud;

        try (PreparedStatement stmt = conn.prepareStatement(sqlFind)) {
            stmt.setString(1, soliNum);
            stmt.setInt(2, cuota);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    abonoDetailId = rs.getLong("id");
                    paymentActual = rs.getDouble("payment");
                    monthly = rs.getDouble("monthly");
                }
            }
        }

        if (abonoDetailId == null) {
            return false;
        }

        double nuevoPayment = Math.max(0, paymentActual - montoDestino);
        String nuevoEstado = nuevoPayment == 0 ? "Pendiente" : (nuevoPayment < monthly ? "Parcial" : "Pagado");

        String sqlUpdate = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
            stmt.setDouble(1, nuevoPayment);
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, abonoDetailId);
            stmt.executeUpdate();
        }

        String sqlDeleteRd = "DELETE FROM registerdetails WHERE idBondDetails = ? ORDER BY id DESC LIMIT 1";
        try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRd)) {
            stmt.setLong(1, abonoDetailId);
            stmt.executeUpdate();
        }

        guardarHistorialCorreccion(conn, "REVERTIR_TRANSFERENCIA_ABONO", solicitud, cuota, montoDestino, nuevoPayment, usuario, "ReversiÃ³n de transferencia");
        return true;
    }

    private boolean revertirAgregarPrestamo(Connection conn, String solicitud, int cuota,
                                            double monto, String usuario) throws SQLException {
        Long loanDetailId = null;
        Long loanId = null;
        double paymentActual = 0;
        double monthlyFee = 0;

        if (solicitud.contains("/LD-")) {
            try {
                String ldPart = solicitud.substring(solicitud.lastIndexOf("/LD-") + 4);
                loanDetailId = Long.parseLong(ldPart);

                String sqlGetData = "SELECT ld.payment, ld.MonthlyFeeValue, ld.LoanID FROM loandetail ld WHERE ld.ID = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetData)) {
                    stmt.setLong(1, loanDetailId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            paymentActual = rs.getDouble("payment");
                            monthlyFee = rs.getDouble("MonthlyFeeValue");
                            loanId = rs.getLong("LoanID");
                        } else {
                            return false;
                        }
                    }
                }
            } catch (Exception e) {
                System.out.println("Error parseando formato antiguo: " + e.getMessage());
                return false;
            }
        } else {
            String sqlFind = "SELECT ld.ID, ld.payment, ld.MonthlyFeeValue, l.ID as LoanID FROM loandetail ld " +
                    "INNER JOIN loan l ON ld.LoanID = l.ID " +
                    "WHERE l.SoliNum = ? AND ld.Dues = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlFind)) {
                stmt.setString(1, solicitud);
                stmt.setInt(2, cuota);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        loanDetailId = rs.getLong("ID");
                        loanId = rs.getLong("LoanID");
                        paymentActual = rs.getDouble("payment");
                        monthlyFee = rs.getDouble("MonthlyFeeValue");
                    }
                }
            }
        }

        if (loanDetailId == null) {
            return false;
        }

        Long rdIdEliminar = null;
        String sqlFindRd = "SELECT id FROM registerdetails WHERE idLoanDetails = ? AND ABS(amountPar - ?) < 0.01 ORDER BY id DESC LIMIT 1";
        try (PreparedStatement stmt = conn.prepareStatement(sqlFindRd)) {
            stmt.setLong(1, loanDetailId);
            stmt.setDouble(2, monto);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    rdIdEliminar = rs.getLong("id");
                }
            }
        }

        if (rdIdEliminar == null) {
            return false;
        }

        double nuevoPayment = Math.max(0, paymentActual - monto);
        String nuevoEstado = nuevoPayment == 0 ? "Pendiente" : (nuevoPayment < monthlyFee ? "Parcial" : "Pagado");

        String sqlUpdate = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
            stmt.setDouble(1, nuevoPayment);
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, loanDetailId);
            stmt.executeUpdate();
        }

        String sqlDeleteRd = "DELETE FROM registerdetails WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRd)) {
            stmt.setLong(1, rdIdEliminar);
            stmt.executeUpdate();
        }

        if (loanId != null) {
            actualizarEstadoGeneralLoan(conn, loanId);
        }

        guardarHistorialCorreccion(conn, "REVERTIR_AGREGAR_PRESTAMO", solicitud, cuota, monto, nuevoPayment, usuario, "ReversiÃ³n de adiciÃ³n");
        return true;
    }

    private boolean revertirAgregarAbono(Connection conn, String solicitud, int cuota,
                                         double monto, String usuario) throws SQLException {
        Long abonoDetailId = null;
        Long abonoId = null;
        double paymentActual = 0;
        double monthly = 0;

        if (solicitud.contains("/AD-")) {
            try {
                String adPart = solicitud.substring(solicitud.lastIndexOf("/AD-") + 4);
                abonoDetailId = Long.parseLong(adPart);

                String sqlGetData = "SELECT ad.payment, ad.monthly, ad.AbonoID FROM abonodetail ad WHERE ad.id = ?";
                try (PreparedStatement stmt = conn.prepareStatement(sqlGetData)) {
                    stmt.setLong(1, abonoDetailId);
                    try (ResultSet rs = stmt.executeQuery()) {
                        if (rs.next()) {
                            paymentActual = rs.getDouble("payment");
                            monthly = rs.getDouble("monthly");
                            abonoId = rs.getLong("AbonoID");
                        } else {
                            return false;
                        }
                    }
                }
            } catch (Exception e) {
                System.out.println("Error parseando formato antiguo: " + e.getMessage());
                return false;
            }
        } else {
            String sqlFind = "SELECT ad.id, ad.payment, ad.monthly, a.id as AbonoID FROM abonodetail ad " +
                    "INNER JOIN abono a ON ad.AbonoID = a.id " +
                    "WHERE a.SoliNum = ? AND ad.dues = ?";
            try (PreparedStatement stmt = conn.prepareStatement(sqlFind)) {
                stmt.setString(1, solicitud);
                stmt.setInt(2, cuota);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        abonoDetailId = rs.getLong("id");
                        abonoId = rs.getLong("AbonoID");
                        paymentActual = rs.getDouble("payment");
                        monthly = rs.getDouble("monthly");
                    }
                }
            }
        }

        if (abonoDetailId == null) {
            return false;
        }

        Long rdIdEliminar = null;
        String sqlFindRd = "SELECT id FROM registerdetails WHERE idBondDetails = ? AND ABS(amountPar - ?) < 0.01 ORDER BY id DESC LIMIT 1";
        try (PreparedStatement stmt = conn.prepareStatement(sqlFindRd)) {
            stmt.setLong(1, abonoDetailId);
            stmt.setDouble(2, monto);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    rdIdEliminar = rs.getLong("id");
                }
            }
        }

        if (rdIdEliminar == null) {
            return false;
        }

        double nuevoPayment = Math.max(0, paymentActual - monto);
        String nuevoEstado = nuevoPayment == 0 ? "Pendiente" : (nuevoPayment < monthly ? "Parcial" : "Pagado");

        String sqlUpdate = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdate)) {
            stmt.setDouble(1, nuevoPayment);
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, abonoDetailId);
            stmt.executeUpdate();
        }

        String sqlDeleteRd = "DELETE FROM registerdetails WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlDeleteRd)) {
            stmt.setLong(1, rdIdEliminar);
            stmt.executeUpdate();
        }

        if (abonoId != null) {
            actualizarEstadoGeneralAbono(conn, abonoId);
        }

        guardarHistorialCorreccion(conn, "REVERTIR_AGREGAR_ABONO", solicitud, cuota, monto, nuevoPayment, usuario, "ReversiÃ³n de adiciÃ³n");
        return true;
    }

    private boolean revertirEdicionPrestamo(Connection conn, String rdIdStr,
                                            double montoAnterior, double montoNuevo,
                                            String usuario) throws SQLException {
        long rdId;
        try {
            rdId = Long.parseLong(rdIdStr);
        } catch (NumberFormatException e) {
            return false;
        }

        String sqlGetLd = "SELECT rd.idLoanDetails, ld.payment, ld.MonthlyFeeValue, ld.LoanID " +
                "FROM registerdetails rd " +
                "INNER JOIN loandetail ld ON rd.idLoanDetails = ld.ID " +
                "WHERE rd.id = ?";

        Long loanDetailId = null;
        Long loanId = null;
        double paymentActual = 0;
        double monthlyFee = 0;

        try (PreparedStatement stmt = conn.prepareStatement(sqlGetLd)) {
            stmt.setLong(1, rdId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    loanDetailId = rs.getLong("idLoanDetails");
                    loanId = rs.getLong("LoanID");
                    paymentActual = rs.getDouble("payment");
                    monthlyFee = rs.getDouble("MonthlyFeeValue");
                }
            }
        }

        if (loanDetailId == null) {
            return false;
        }

        double diferencia = montoAnterior - montoNuevo;
        double nuevoPayment = Math.max(0, paymentActual + diferencia);

        String sqlUpdateRd = "UPDATE registerdetails SET amountPar = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateRd)) {
            stmt.setDouble(1, montoAnterior);
            stmt.setLong(2, rdId);
            stmt.executeUpdate();
        }

        String nuevoEstado;
        if (nuevoPayment <= 0) {
            nuevoEstado = "Pendiente";
        } else if (nuevoPayment < monthlyFee) {
            nuevoEstado = "Parcial";
        } else {
            nuevoEstado = "Pagado";
        }

        String sqlUpdateLd = "UPDATE loandetail SET payment = ?, State = ? WHERE ID = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateLd)) {
            stmt.setDouble(1, nuevoPayment);
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, loanDetailId);
            stmt.executeUpdate();
        }

        if (loanId != null) {
            actualizarEstadoGeneralLoan(conn, loanId);
        }

        guardarHistorialCorreccion(conn, "REVERTIR_EDICION_PRESTAMO", rdIdStr, 0, montoNuevo, montoAnterior, usuario, "ReversiÃ³n de ediciÃ³n");
        return true;
    }

    private boolean revertirEdicionAbono(Connection conn, String rdIdStr,
                                         double montoAnterior, double montoNuevo,
                                         String usuario) throws SQLException {
        long rdId;
        try {
            rdId = Long.parseLong(rdIdStr);
        } catch (NumberFormatException e) {
            return false;
        }

        String sqlGetAd = "SELECT rd.idBondDetails, ad.payment, ad.monthly, ad.AbonoID " +
                "FROM registerdetails rd " +
                "INNER JOIN abonodetail ad ON rd.idBondDetails = ad.id " +
                "WHERE rd.id = ?";

        Long abonoDetailId = null;
        Long abonoId = null;
        double paymentActual = 0;
        double monthly = 0;

        try (PreparedStatement stmt = conn.prepareStatement(sqlGetAd)) {
            stmt.setLong(1, rdId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    abonoDetailId = rs.getLong("idBondDetails");
                    abonoId = rs.getLong("AbonoID");
                    paymentActual = rs.getDouble("payment");
                    monthly = rs.getDouble("monthly");
                }
            }
        }

        if (abonoDetailId == null) {
            return false;
        }

        double diferencia = montoAnterior - montoNuevo;

        String sqlUpdateRd = "UPDATE registerdetails SET amountPar = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateRd)) {
            stmt.setDouble(1, montoAnterior);
            stmt.setLong(2, rdId);
            stmt.executeUpdate();
        }

        double nuevoPayment = paymentActual + diferencia;
        String nuevoEstado = nuevoPayment <= 0 ? "Pendiente" : (nuevoPayment < monthly ? "Parcial" : "Pagado");

        String sqlUpdateAd = "UPDATE abonodetail SET payment = ?, state = ? WHERE id = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sqlUpdateAd)) {
            stmt.setDouble(1, Math.max(0, nuevoPayment));
            stmt.setString(2, nuevoEstado);
            stmt.setLong(3, abonoDetailId);
            stmt.executeUpdate();
        }

        if (abonoId != null) {
            actualizarEstadoGeneralAbono(conn, abonoId);
        }

        guardarHistorialCorreccion(conn, "REVERTIR_EDICION_ABONO", rdIdStr, 0, montoNuevo, montoAnterior, usuario, "ReversiÃ³n de ediciÃ³n");
        return true;
    }
}
