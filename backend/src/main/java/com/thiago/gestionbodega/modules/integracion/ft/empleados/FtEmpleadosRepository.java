package com.thiago.gestionbodega.modules.integracion.ft.empleados;

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
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * CRUD de la tabla employees de la BD financialtracker1.
 * Replica EXACTAMENTE el SQL del EmployeeDao original de FinantialTracker
 * (app Swing), para que la UI existente pueda pasar por el backend sin
 * cambiar de comportamiento. El DAO Swing queda como fallback JDBC.
 *
 * Las fechas se devuelven como String via DATE_FORMAT para que el JSON sea
 * estable ("yyyy-MM-dd" y "yyyy-MM-dd HH:mm:ss") y el DAO Swing pueda
 * reconstruir su EmployeeTb (LocalDate / LocalDateTime) sin ambiguedad.
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier}
 * sobre un campo con {@code @RequiredArgsConstructor} NO se propaga al
 * constructor generado â€” Spring inyectaria el JdbcTemplate primario
 * (bodega) en vez del secundario (FT).
 */
@Repository
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true")
public class FtEmpleadosRepository {

    private final NamedParameterJdbcTemplate ftJdbc;
    private final DataSource ftDataSource;

    public FtEmpleadosRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc,
            @Qualifier("financialTrackerDataSource") DataSource ftDataSource) {
        this.ftJdbc = ftJdbc;
        this.ftDataSource = ftDataSource;
    }

    /** Columnas completas de employees, mismas keys que espera el DAO Swing. */
    private static final String SELECT_FULL = """
            SELECT e.employee_id,
                   e.fullName,
                   e.national_id,
                   e.gender,
                   e.employment_status,
                   e.employment_status_code,
                   DATE_FORMAT(e.start_date, '%Y-%m-%d') AS start_date,
                   DATE_FORMAT(e.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
                   DATE_FORMAT(e.updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
              FROM employees e
            """;

    /**
     * Subquery del DAO original AMPLIADA: excluye de todos los listados a
     * los empleados vinculados a cuentas de administrador — super admin
     * (state 9) y cualquier usuario con rol ADMINISTRADOR/SUPER
     * ADMINISTRADOR. Los administradores no deben aparecer en busquedas,
     * listas ni reportes.
     */
    private static final String EXCLUIR_SUPER_ADMIN =
            " e.employee_id NOT IN (SELECT u.idEmployee FROM user u "
            + "WHERE u.state = '9' OR UPPER(u.rol) LIKE '%ADMINISTRADOR%') ";

    /**
     * Mismo mapeo de estado a codigo que hace el EmployeeDao original:
     * CAS -> 2028, NOMBRADO -> 2154, cualquier otro -> 2028.
     */
    private static String codigoEstado(String employmentStatus) {
        if (employmentStatus != null && employmentStatus.equalsIgnoreCase("NOMBRADO")) {
            return "2154";
        }
        return "2028";
    }

    // â”€â”€â”€ Lecturas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** EmployeeDao.findAll(): todos menos super admins, orden por nombre. */
    public List<Map<String, Object>> listarTodos() {
        return ftJdbc.queryForList(
                SELECT_FULL + " WHERE " + EXCLUIR_SUPER_ADMIN + " ORDER BY e.fullName ASC",
                new MapSqlParameterSource());
    }

    /** EmployeeDao.findById(Integer). Sin exclusion (igual que el original). */
    public Optional<Map<String, Object>> buscarPorId(int id) {
        List<Map<String, Object>> rows = ftJdbc.queryForList(
                SELECT_FULL + " WHERE e.employee_id = :id",
                new MapSqlParameterSource("id", id));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** EmployeeDao.findById(String dni). Sin exclusion (igual que el original). */
    public Optional<Map<String, Object>> buscarPorDni(String dni) {
        List<Map<String, Object>> rows = ftJdbc.queryForList(
                SELECT_FULL + " WHERE e.national_id = :dni",
                new MapSqlParameterSource("dni", dni));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** EmployeeDao.findEmployeesByFullName(): LIKE %NOMBRE% en mayusculas. */
    public List<Map<String, Object>> buscarPorNombre(String nombre) {
        String patron = "%" + nombre.toUpperCase().trim() + "%";
        return ftJdbc.queryForList(
                SELECT_FULL + " WHERE e.fullName LIKE :patron AND " + EXCLUIR_SUPER_ADMIN
                        + " ORDER BY e.fullName ASC",
                new MapSqlParameterSource("patron", patron));
    }

    /** EmployeeDao.getEmployeesByDateRange(): start_date entre inicio y fin. */
    public List<Map<String, Object>> listarPorRango(LocalDate inicio, LocalDate fin) {
        return ftJdbc.queryForList(
                SELECT_FULL + " WHERE e.start_date BETWEEN :inicio AND :fin AND "
                        + EXCLUIR_SUPER_ADMIN + " ORDER BY e.start_date ASC",
                new MapSqlParameterSource()
                        .addValue("inicio", inicio.toString())
                        .addValue("fin", fin.toString()));
    }

    /** EmployeeDao.getLastEmployees(): ultimos N por employee_id DESC (con offset). */
    public List<Map<String, Object>> listarUltimos(int limite, int offset) {
        return ftJdbc.queryForList(
                SELECT_FULL + " WHERE " + EXCLUIR_SUPER_ADMIN
                        + " ORDER BY e.employee_id DESC LIMIT :lim OFFSET :off",
                new MapSqlParameterSource("lim", limite).addValue("off", offset));
    }

    /**
     * EmployeeDao.getAllEmployeeDniNames(): dni + nombre de TODOS los
     * empleados (el original no excluye super admins aqui).
     */
    public List<Map<String, Object>> listarDniNombres() {
        return ftJdbc.queryForList("""
                SELECT national_id AS dni, fullName AS nombre
                  FROM employees
                 ORDER BY fullName ASC
                """, new MapSqlParameterSource());
    }

    // â”€â”€â”€ Escrituras â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * EmployeeDao.create(): INSERT con los mismos toUpperCase() y el mismo
     * default de gender null -> "". Devuelve el id generado.
     */
    public int crear(String fullName, String nationalId, String gender,
                     String employmentStatus, String employmentStatusCode,
                     LocalDate startDate) {
        String sql = """
                INSERT INTO employees
                    (fullName, national_id, gender, employment_status,
                     employment_status_code, start_date)
                VALUES (:nombre, :dni, :genero, :estado, :codigo, :fecha)
                """;
        KeyHolder kh = new GeneratedKeyHolder();
        ftJdbc.update(sql,
                new MapSqlParameterSource()
                        .addValue("nombre", fullName.toUpperCase())
                        .addValue("dni", nationalId.toUpperCase())
                        .addValue("genero", gender == null ? "" : gender)
                        .addValue("estado", employmentStatus.toUpperCase())
                        .addValue("codigo", employmentStatusCode)
                        .addValue("fecha", startDate.toString()),
                kh);
        Number key = kh.getKey();
        if (key == null) {
            throw new IllegalStateException("Creating employee failed, no ID obtained.");
        }
        return key.intValue();
    }

    /**
     * EmployeeDao.updateEmploymentStatusByDNI(): recalcula el codigo con la
     * misma regla y actualiza updated_at. Devuelve true si afecto filas.
     */
    public boolean actualizarEstadoPorDni(String dni, String nuevoEstado) {
        String sql = """
                UPDATE employees
                   SET employment_status = :estado,
                       employment_status_code = :codigo,
                       updated_at = CURRENT_TIMESTAMP
                 WHERE national_id = :dni
                """;
        int rows = ftJdbc.update(sql,
                new MapSqlParameterSource()
                        .addValue("estado", nuevoEstado)
                        .addValue("codigo", codigoEstado(nuevoEstado))
                        .addValue("dni", dni));
        return rows > 0;
    }

    /**
     * EmployeeDao.updateEmployee(): UPDATE de employees + (si cambia el DNI)
     * de loan.EmployeeID y loan.GuarantorId, en UNA transaccion, igual que
     * el original (loan.EmployeeID guarda el DNI, no el id numerico).
     */
    public void actualizarEmpleado(String originalDni, String nuevoDni, String fullName,
                                   String gender, String employmentStatus,
                                   LocalDate startDate) throws SQLException {
        String sqlEmployee = "UPDATE employees SET national_id = ?, fullName = ?, gender = ?, "
                + "employment_status = ?, employment_status_code = ?, start_date = ?, "
                + "updated_at = CURRENT_TIMESTAMP WHERE national_id = ?";
        String sqlLoanEmployee = "UPDATE loan SET EmployeeID = ? WHERE EmployeeID = ?";
        String sqlLoanGuarantor = "UPDATE loan SET GuarantorId = ? WHERE GuarantorId = ?";

        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            String statusCode = codigoEstado(employmentStatus);

            try (PreparedStatement ps = conn.prepareStatement(sqlEmployee)) {
                ps.setString(1, nuevoDni);
                ps.setString(2, fullName.toUpperCase());
                ps.setString(3, gender);
                ps.setString(4, employmentStatus.toUpperCase());
                ps.setString(5, statusCode);
                ps.setString(6, startDate.toString());
                ps.setString(7, originalDni);
                ps.executeUpdate();
            }

            if (!originalDni.equals(nuevoDni)) {
                try (PreparedStatement ps = conn.prepareStatement(sqlLoanEmployee)) {
                    ps.setString(1, nuevoDni);
                    ps.setString(2, originalDni);
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = conn.prepareStatement(sqlLoanGuarantor)) {
                    ps.setString(1, nuevoDni);
                    ps.setString(2, originalDni);
                    ps.executeUpdate();
                }
            }

            conn.commit();
        } catch (SQLException e) {
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ignore) {
                    // best effort
                }
            }
            throw e;
        } finally {
            if (conn != null) {
                try {
                    conn.setAutoCommit(true);
                } catch (SQLException ignore) {
                    // best effort
                }
                try {
                    conn.close();
                } catch (SQLException ignore) {
                    // best effort
                }
            }
        }
    }

    // â”€â”€â”€ Borrado condicionado (EmployeeDao.deleteEmployeeIfNotUsed) â”€â”€â”€â”€

    /** Paso 1 del delete: id del empleado por DNI. */
    public Optional<Integer> buscarIdPorDni(String dni) {
        List<Integer> ids = ftJdbc.queryForList(
                "SELECT employee_id FROM employees WHERE national_id = :dni",
                new MapSqlParameterSource("dni", dni), Integer.class);
        return ids.isEmpty() ? Optional.empty() : Optional.of(ids.get(0));
    }

    /** loan.EmployeeID guarda el DNI (igual que la query del DAO original). */
    public int contarPrestamosPorDni(String dni) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM loan WHERE EmployeeID = :dni",
                new MapSqlParameterSource("dni", dni), Integer.class);
        return count == null ? 0 : count;
    }

    /** Usuarios ligados al empleado (misma query LEFT JOIN del DAO). */
    public int contarUsuariosPorDni(String dni) {
        Integer count = ftJdbc.queryForObject("""
                SELECT COUNT(*) FROM user se
                  LEFT JOIN employees em ON se.idEmployee = em.employee_id
                 WHERE em.national_id = :dni
                """, new MapSqlParameterSource("dni", dni), Integer.class);
        return count == null ? 0 : count;
    }

    /** abono.Employee_id guarda el id numerico (igual que el DAO original). */
    public int contarAbonosPorEmployeeId(int employeeId) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM abono WHERE Employee_id = :eid",
                new MapSqlParameterSource("eid", employeeId), Integer.class);
        return count == null ? 0 : count;
    }

    public boolean eliminarPorId(int employeeId) {
        return ftJdbc.update("DELETE FROM employees WHERE employee_id = :id",
                new MapSqlParameterSource("id", employeeId)) > 0;
    }

    // â”€â”€â”€ Usuarios (espejo de UserDao del Swing) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * State del usuario (UserDao lo consulta antes de toggle/updatePassword/
     * updateRole para proteger al super admin, state = 9).
     */
    public Optional<Integer> estadoUsuario(String username) {
        List<Integer> states = ftJdbc.queryForList(
                "SELECT state FROM user WHERE username = :u",
                new MapSqlParameterSource("u", username), Integer.class);
        return states.isEmpty() ? Optional.empty() : Optional.ofNullable(states.get(0));
    }

    /** Rol del usuario (para proteger las cuentas de administrador). */
    public Optional<String> rolUsuario(String username) {
        List<String> roles = ftJdbc.queryForList(
                "SELECT rol FROM user WHERE username = :u",
                new MapSqlParameterSource("u", username), String.class);
        return roles.isEmpty() ? Optional.ofNullable(null) : Optional.ofNullable(roles.get(0));
    }

    /** UserDao.toggleUserState() paso 2: UPDATE del state. */
    public boolean actualizarEstadoUsuario(String username, int nuevoEstado) {
        return ftJdbc.update(
                "UPDATE user SET state = :estado WHERE username = :u",
                new MapSqlParameterSource()
                        .addValue("estado", nuevoEstado)
                        .addValue("u", username)) > 0;
    }

    /** UserDao.isUsernameTaken(). */
    public boolean existeUsername(String username) {
        Integer count = ftJdbc.queryForObject(
                "SELECT COUNT(*) FROM user WHERE username = :u",
                new MapSqlParameterSource("u", username), Integer.class);
        return count != null && count > 0;
    }

    /**
     * UserDao.getUserByUsername(): misma fila user + employees. Incluye el
     * hash BCrypt en la key "password" para que el controller verifique la
     * contrasena â€” el controller NUNCA debe devolver esa key al cliente.
     */
    public Optional<Map<String, Object>> buscarUsuarioPorUsername(String username) {
        List<Map<String, Object>> rows = ftJdbc.queryForList("""
                SELECT u.iduser, u.username, u.password, u.idEmployee, u.rol, u.state,
                       e.fullName, e.national_id, e.gender,
                       e.employment_status, e.employment_status_code,
                       DATE_FORMAT(e.start_date, '%Y-%m-%d') AS start_date,
                       DATE_FORMAT(e.created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
                       DATE_FORMAT(e.updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
                  FROM user u
                  JOIN employees e ON u.idEmployee = e.employee_id
                 WHERE u.username = :u
                """, new MapSqlParameterSource("u", username));
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /**
     * UserDao.createUser(): INSERT con state fijo '1' (igual que el
     * original; el parametro "state" del DAO en realidad es el rol).
     * La password llega YA hasheada con BCrypt desde el controller.
     */
    public boolean crearUsuario(String username, String passwordHasheada,
                                int idEmployee, String rol) {
        return ftJdbc.update("""
                INSERT INTO user (username, password, idEmployee, rol, state)
                VALUES (:u, :p, :ide, :rol, '1')
                """,
                new MapSqlParameterSource()
                        .addValue("u", username)
                        .addValue("p", passwordHasheada)
                        .addValue("ide", idEmployee)
                        .addValue("rol", rol)) > 0;
    }

    /**
     * UserDao.getAllUsers(): mismas columnas (incluye hash, como el
     * original), pero SIN cuentas de administrador — no deben aparecer en
     * la lista de usuarios ni en ningun reporte.
     */
    public List<Map<String, Object>> listarUsuarios() {
        return ftJdbc.queryForList("""
                SELECT u.iduser, u.username, u.password,
                       e.fullName AS employee_name,
                       u.rol, u.state
                  FROM user u
                  JOIN employees e ON u.idEmployee = e.employee_id
                 WHERE u.state <> '9'
                   AND (u.rol IS NULL OR UPPER(u.rol) NOT LIKE '%ADMINISTRADOR%')
                """, new MapSqlParameterSource());
    }

    /** UserDao.updateUserPassword() paso 2 (password ya hasheada). */
    public boolean actualizarPasswordUsuario(String username, String passwordHasheada) {
        return ftJdbc.update(
                "UPDATE user SET password = :p WHERE username = :u",
                new MapSqlParameterSource()
                        .addValue("p", passwordHasheada)
                        .addValue("u", username)) > 0;
    }

    /** UserDao.updateUserRole() paso 2. */
    public boolean actualizarRolUsuario(String username, String rol) {
        return ftJdbc.update(
                "UPDATE user SET rol = :rol WHERE username = :u",
                new MapSqlParameterSource()
                        .addValue("rol", rol)
                        .addValue("u", username)) > 0;
    }
}
