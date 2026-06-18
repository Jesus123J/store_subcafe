package com.thiago.gestionbodega.modules.creditos.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.creditos.dto.CierreMensualResultDto;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Cierre mensual de creditos.
 *
 * Flujo (segun requerimiento de Karina):
 *   - Los creditos del mes (1 al 30/31) se ACUMULAN sin descontar
 *   - Al cierre, se SUMAN por trabajador y se trasladan a la tabla
 *     deuda_trabajadores (planilla)
 *   - Los creditos se marcan como cerrados con fecha
 *   - El proximo mes empieza desde cero
 *
 * El cierre lo dispara MANUALMENTE el administrador desde la UI cuando
 * llega fin de mes.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CierreCreditosService {

    private final NamedParameterJdbcTemplate jdbc;
    private final UsuarioRepository usuarioRepo;

    /** Cierra el periodo (anio, mes) actual o el indicado. */
    @Transactional
    public CierreMensualResultDto cerrarMes(String username, Integer anio, Integer mes) {
        Usuario admin = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        LocalDate hoy = LocalDate.now();
        int periodoAnio = anio != null ? anio : hoy.getYear();
        int periodoMes = mes != null ? mes : hoy.getMonthValue();

        // 1) Verificar que no se haya cerrado ya
        var yaCerrado = jdbc.queryForObject(
                "SELECT COUNT(*) FROM cierres_mensuales_creditos WHERE anio = :a AND mes = :m",
                new MapSqlParameterSource().addValue("a", periodoAnio).addValue("m", periodoMes),
                Long.class);
        if (yaCerrado != null && yaCerrado > 0) {
            throw new BusinessException(
                    "El periodo " + periodoMes + "/" + periodoAnio + " ya fue cerrado anteriormente");
        }

        // 2) Agregar creditos del periodo por trabajador
        String sqlAgg = """
                SELECT trabajador_id, COALESCE(SUM(monto), 0) AS total
                FROM creditos_trabajadores
                WHERE cerrado = FALSE
                  AND periodo_anio = :a
                  AND periodo_mes = :m
                GROUP BY trabajador_id
                HAVING SUM(monto) > 0
                """;
        List<Map<String, Object>> totales = jdbc.queryForList(sqlAgg,
                new MapSqlParameterSource()
                        .addValue("a", periodoAnio)
                        .addValue("m", periodoMes));

        if (totales.isEmpty()) {
            throw new BusinessException(
                    "No hay creditos pendientes en " + periodoMes + "/" + periodoAnio + " para cerrar");
        }

        BigDecimal montoTotalGeneral = BigDecimal.ZERO;

        // 3) Por cada trabajador, sumar a su deuda_trabajadores
        for (var row : totales) {
            // En MySQL los UUID se almacenan como CHAR(36) → vuelven como String
            String trabajadorId = String.valueOf(row.get("trabajador_id"));
            BigDecimal monto = (BigDecimal) row.get("total");
            montoTotalGeneral = montoTotalGeneral.add(monto);

            // UPSERT MySQL: si ya tenia deuda acumulada, sumamos
            jdbc.update("""
                    INSERT INTO deuda_trabajadores (trabajador_id, monto_total, actualizada_en)
                    VALUES (:tid, :monto, NOW())
                    ON DUPLICATE KEY UPDATE
                      monto_total = monto_total + VALUES(monto_total),
                      actualizada_en = NOW()
                    """,
                    new MapSqlParameterSource()
                            .addValue("tid", trabajadorId)
                            .addValue("monto", monto));
        }

        // 4) Marcar los creditos del periodo como cerrados
        int creditosCerrados = jdbc.update("""
                UPDATE creditos_trabajadores
                   SET cerrado = TRUE, cerrado_en = NOW()
                 WHERE cerrado = FALSE
                   AND periodo_anio = :a
                   AND periodo_mes = :m
                """,
                new MapSqlParameterSource().addValue("a", periodoAnio).addValue("m", periodoMes));

        // 5) Registrar el cierre en el historico
        UUID cierreId = UUID.randomUUID();
        OffsetDateTime ahora = OffsetDateTime.now();
        jdbc.update("""
                INSERT INTO cierres_mensuales_creditos
                  (id, anio, mes, fecha_cierre, cerrado_por, trabajadores_afectados, monto_total)
                VALUES (:id, :a, :m, :fecha, :userId, :trabajadores, :monto)
                """,
                new MapSqlParameterSource()
                        .addValue("id", cierreId.toString())
                        .addValue("a", periodoAnio)
                        .addValue("m", periodoMes)
                        .addValue("fecha", ahora)
                        .addValue("userId", admin.getId().toString())
                        .addValue("trabajadores", totales.size())
                        .addValue("monto", montoTotalGeneral));

        log.info("Cierre creditos {}/{}: {} trabajadores, S/. {}, {} creditos",
                periodoMes, periodoAnio, totales.size(), montoTotalGeneral, creditosCerrados);

        return CierreMensualResultDto.builder()
                .anio(periodoAnio)
                .mes(periodoMes)
                .fechaCierre(ahora)
                .trabajadoresAfectados(totales.size())
                .montoTotal(montoTotalGeneral)
                .creditosCerrados(creditosCerrados)
                .build();
    }

    /** Lista de creditos del mes actual agrupados por trabajador. */
    public List<Map<String, Object>> creditosDelMes() {
        return jdbc.queryForList("""
                SELECT trabajador_id, dni, nombre_completo,
                       cantidad_consumos, monto_pendiente, ultimo_consumo,
                       anio, mes
                FROM v_creditos_del_mes
                ORDER BY monto_pendiente DESC
                """, new MapSqlParameterSource());
    }

    /** Deuda acumulada (planilla) por trabajador. */
    public List<Map<String, Object>> deudaAcumulada() {
        return jdbc.queryForList("""
                SELECT trabajador_id, dni, nombre_completo,
                       deuda_acumulada, actualizada_en
                FROM v_deuda_trabajadores_acumulada
                ORDER BY deuda_acumulada DESC
                """, new MapSqlParameterSource());
    }

    /** Historico de cierres mensuales. */
    public List<Map<String, Object>> historialCierres() {
        return jdbc.queryForList("""
                SELECT id, anio, mes, fecha_cierre,
                       trabajadores_afectados, monto_total
                FROM cierres_mensuales_creditos
                ORDER BY anio DESC, mes DESC
                """, new MapSqlParameterSource());
    }
}
