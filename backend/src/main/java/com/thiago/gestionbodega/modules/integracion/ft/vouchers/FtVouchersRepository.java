package com.thiago.gestionbodega.modules.integracion.ft.vouchers;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/**
 * Escrituras sobre las tablas voucher / voucher_temp de la BD
 * financialtracker1. Replica EXACTAMENTE el SQL que ejecuta
 * PaymentVoucher (app Swing FinantialTracker) con JDBC directo, para que
 * la UI existente pueda pasar por el backend sin cambiar de comportamiento.
 *
 * IMPORTANTE: constructor manual (sin Lombok) porque {@code @Qualifier}
 * sobre un campo con {@code @RequiredArgsConstructor} NO se propaga al
 * constructor generado â€” Spring inyectaria el DataSource/JdbcTemplate
 * primario (bodega) en vez del secundario (FT).
 */
@Repository
@ConditionalOnProperty(name = "integracion.financialtracker.enabled", havingValue = "true")
public class FtVouchersRepository {

    private final NamedParameterJdbcTemplate ftJdbc;
    private final DataSource ftDataSource;

    public FtVouchersRepository(
            @Qualifier("ftJdbc") NamedParameterJdbcTemplate ftJdbc,
            @Qualifier("financialTrackerDataSource") DataSource ftDataSource) {
        this.ftJdbc = ftJdbc;
        this.ftDataSource = ftDataSource;
    }

    // â”€â”€â”€ Crear voucher (transaccional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Confirma la reserva en voucher_temp y registra el voucher definitivo,
     * todo en UNA transaccion server-side (mismo flujo que
     * PaymentVoucher.generateVoucher(): UPDATE voucher_temp a CONFIRMED +
     * INSERT voucher).
     *
     * @return filas afectadas por el INSERT en voucher (0 o 1).
     */
    public int crearVoucher(String numVoucher, String numAccount, String numCheck,
                            String bank, String dateEntry, Double amount,
                            String details, String documentDni, String nameLastname,
                            Integer userId) throws SQLException {

        String updateTempSql = "UPDATE voucher_temp SET status = 'CONFIRMED' WHERE num_voucher = ?";
        String insertSql = "INSERT INTO voucher (num_voucher, num_account, num_check, bank, "
                + "date_entry, amount, details, document_dni, name_lastname, userId) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        Connection conn = null;
        try {
            conn = ftDataSource.getConnection();
            conn.setAutoCommit(false);

            try (PreparedStatement up = conn.prepareStatement(updateTempSql)) {
                up.setString(1, numVoucher);
                up.executeUpdate();
            }

            int filas;
            try (PreparedStatement ins = conn.prepareStatement(insertSql)) {
                ins.setString(1, numVoucher);
                ins.setString(2, numAccount);
                ins.setString(3, numCheck);
                ins.setString(4, bank);
                // date_entry es varchar en el schema original; llega "yyyy-MM-dd"
                ins.setString(5, dateEntry);
                if (amount == null) {
                    ins.setNull(6, java.sql.Types.DOUBLE);
                } else {
                    ins.setDouble(6, amount);
                }
                ins.setString(7, details);
                ins.setString(8, documentDni);
                ins.setString(9, nameLastname);
                // el DAO original tambien manda el userId como String
                ins.setString(10, userId == null ? null : userId.toString());
                filas = ins.executeUpdate();
            }

            conn.commit();
            return filas;
        } catch (SQLException e) {
            if (conn != null) {
                try {
                    conn.rollback();
                } catch (SQLException ignored) {
                }
            }
            throw e;
        } finally {
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
    }

    // â”€â”€â”€ Actualizar voucher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica PaymentVoucher.updateVoucher(): UPDATE voucher ... WHERE
     * num_voucher. Devuelve filas afectadas (0 si el voucher no existe).
     */
    public int actualizarVoucher(String numVoucher, String numAccount, String numCheck,
                                 String bank, String dateEntry, Double amount,
                                 String details, String documentDni, String nameLastname) {
        String sql = """
                UPDATE voucher SET
                       num_account = :numAccount,
                       num_check = :numCheck,
                       bank = :bank,
                       date_entry = :dateEntry,
                       amount = :amount,
                       details = :details,
                       document_dni = :documentDni,
                       name_lastname = :nameLastname
                 WHERE num_voucher = :numVoucher
                """;
        return ftJdbc.update(sql, new MapSqlParameterSource()
                .addValue("numAccount", numAccount)
                .addValue("numCheck", numCheck)
                .addValue("bank", bank)
                .addValue("dateEntry", dateEntry)
                .addValue("amount", amount)
                .addValue("details", details)
                .addValue("documentDni", documentDni)
                .addValue("nameLastname", nameLastname)
                .addValue("numVoucher", numVoucher));
    }

    // â”€â”€â”€ Reservar numero de voucher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica PaymentVoucher.generateAndReserveVoucher(): calcula el
     * siguiente correlativo "001-NNNNNN" a partir del MAX en voucher_temp
     * y lo reserva insertandolo (status queda en su default PENDING).
     *
     * @return el numero reservado, p.ej. "001-000042".
     */
    public String reservarVoucher() {
        Integer max = ftJdbc.queryForObject(
                "SELECT MAX(CAST(SUBSTRING(num_voucher, 5) AS UNSIGNED)) FROM voucher_temp",
                new MapSqlParameterSource(), Integer.class);
        int nuevaSecuencia = (max == null ? 0 : max) + 1;
        String numVoucher = String.format("001-%06d", nuevaSecuencia);

        ftJdbc.update("INSERT INTO voucher_temp (num_voucher) VALUES (:nv)",
                new MapSqlParameterSource("nv", numVoucher));
        return numVoucher;
    }

    // â”€â”€â”€ Limpieza de reservas no usadas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Replica PaymentVoucher.cleanUnusedVouchers(): borra las reservas
     * PENDING de voucher_temp. Devuelve cuantas filas se eliminaron.
     */
    public int borrarTempPendientes() {
        return ftJdbc.update("DELETE FROM voucher_temp WHERE status = 'PENDING'",
                new MapSqlParameterSource());
    }
}
