package com.thiago.gestionbodega.modules.integracion.ft;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.integracion.ft.dto.EnvioResultDto;
import com.thiago.gestionbodega.modules.integracion.ft.dto.EnvioResumenDto;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Envia la deuda mensual (o individual) de la bodega al FinantialTracker.
 *
 * Los trabajadores viven en FT (tabla employees) — la bodega solo guarda
 * el DNI en {@code creditos_trabajadores.trabajador_dni}. Al enviar, se
 * agrupa por DNI, se valida que existan como employees en FT, y se
 * insertan los abonos.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnBean(FinancialTrackerRepository.class)
public class FinancialTrackerService {

    private final FinancialTrackerRepository ftRepo;
    private final FinancialTrackerProperties props;
    private final NamedParameterJdbcTemplate jdbc;  // BD principal (bodega)
    private final UsuarioRepository usuarioRepo;

    // ─── ENVIAR CIERRE COMPLETO ────────────────────────────────────────

    @Transactional
    public EnvioResultDto enviarCierre(UUID cierreId, String username) {
        Usuario admin = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));

        // 1) Verificar cierre
        Map<String, Object> cierre = jdbc.queryForMap("""
                SELECT id, anio, mes FROM cierres_mensuales_creditos WHERE id = :id
                """, new MapSqlParameterSource("id", cierreId.toString()));
        int anio = (int) cierre.get("anio");
        int mes  = (int) cierre.get("mes");

        // 2) Bloquear reenvio
        Integer yaEnviado = jdbc.queryForObject("""
                SELECT COUNT(*) FROM envios_financialtracker
                 WHERE cierre_id = :cid AND estado = 'ACTIVO'
                """, new MapSqlParameterSource("cid", cierreId.toString()), Integer.class);
        if (yaEnviado != null && yaEnviado > 0) {
            throw new BusinessException(
                    "El cierre " + mes + "/" + anio + " ya fue enviado. "
                    + "Reviertelo antes de reenviar.");
        }

        // 3) Agrupar creditos por DNI (sin JOIN — el DNI vive en la tabla)
        List<Map<String, Object>> filas = jdbc.queryForList("""
                SELECT c.trabajador_dni AS dni,
                       COALESCE(SUM(c.monto), 0) AS monto_total
                  FROM creditos_trabajadores c
                 WHERE c.periodo_anio = :a
                   AND c.periodo_mes  = :m
                   AND c.cerrado      = TRUE
                 GROUP BY c.trabajador_dni
                HAVING SUM(c.monto) > 0
                """,
                new MapSqlParameterSource().addValue("a", anio).addValue("m", mes));

        if (filas.isEmpty()) {
            throw new BusinessException("El cierre no tiene creditos para enviar");
        }

        // 4) Validar todos los DNI en FT antes de crear el lote
        List<String> noEncontrados = new ArrayList<>();
        for (Map<String, Object> f : filas) {
            String dni = (String) f.get("dni");
            if (ftRepo.findEmployeeIdByDni(dni).isEmpty()) {
                noEncontrados.add(dni);
            }
        }
        if (!noEncontrados.isEmpty()) {
            throw new BusinessException(
                    "Los siguientes DNI no existen en la planilla del hospital. "
                    + "Registralos primero en FinantialTracker:\n - "
                    + String.join("\n - ", noEncontrados));
        }

        // 5) Verificar service_concept
        if (!ftRepo.existeServiceConcept(props.getServiceConceptId())) {
            throw new BusinessException(
                    "El service_concept_id=" + props.getServiceConceptId()
                    + " no existe en FinantialTracker. Crealo primero o ajusta la config.");
        }

        // 6) Crear lote
        String nombreLote = "Bodega Sub Cafe - " + mesToLabel(mes) + " " + anio;
        int loteIdFt = ftRepo.crearLote(nombreLote, filas.size());
        log.info("Lote {} creado en FT para cierre {}/{}", loteIdFt, mes, anio);

        // 7) Insertar abonos + detail
        BigDecimal montoTotal = BigDecimal.ZERO;
        LocalDate paymentDate = primerPaymentDateSiguienteMes(anio, mes);
        for (Map<String, Object> f : filas) {
            String dni = (String) f.get("dni");
            BigDecimal monto = (BigDecimal) f.get("monto_total");
            int employeeId = ftRepo.findEmployeeIdByDni(dni).orElseThrow();

            int abonoId = ftRepo.insertarAbono(
                    employeeId, props.getServiceConceptId(), loteIdFt,
                    monto, 1, paymentDate);
            ftRepo.insertarAbonoDetails(abonoId, 1, monto, paymentDate);

            montoTotal = montoTotal.add(monto);
        }

        // 8) Registrar envio
        UUID envioId = UUID.randomUUID();
        OffsetDateTime ahora = OffsetDateTime.now();
        jdbc.update("""
                INSERT INTO envios_financialtracker
                    (id, cierre_id, lote_id_ft, service_concept_id, fecha,
                     enviado_por, trabajadores_enviados, monto_total, estado)
                VALUES
                    (:id, :cid, :lote, :sci, :fecha, :userId, :trabajadores, :monto, 'ACTIVO')
                """,
                new MapSqlParameterSource()
                        .addValue("id", envioId.toString())
                        .addValue("cid", cierreId.toString())
                        .addValue("lote", loteIdFt)
                        .addValue("sci", props.getServiceConceptId())
                        .addValue("fecha", ahora)
                        .addValue("userId", admin.getId().toString())
                        .addValue("trabajadores", filas.size())
                        .addValue("monto", montoTotal));

        log.info("Envio {} registrado: cierre {}/{} -> lote FT {}, {} trabajadores, S/. {}",
                envioId, mes, anio, loteIdFt, filas.size(), montoTotal);

        return EnvioResultDto.builder()
                .id(envioId)
                .loteIdFt(loteIdFt)
                .trabajadoresEnviados(filas.size())
                .montoTotal(montoTotal)
                .fecha(ahora)
                .estado("ACTIVO")
                .dnisNoEncontrados(List.of())
                .build();
    }

    // ─── ENVIAR CREDITO INDIVIDUAL ─────────────────────────────────────

    @Transactional
    public EnvioResultDto enviarCreditoIndividual(UUID creditoId, String username) {
        Usuario admin = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + username));

        // 1) Verificar credito
        Map<String, Object> row = jdbc.queryForMap("""
                SELECT c.id, c.trabajador_dni AS dni, c.monto
                  FROM creditos_trabajadores c
                 WHERE c.id = :id
                """, new MapSqlParameterSource("id", creditoId.toString()));

        Integer yaEnviado = jdbc.queryForObject("""
                SELECT COUNT(*) FROM envios_financialtracker
                 WHERE credito_id = :cid AND estado = 'ACTIVO'
                """, new MapSqlParameterSource("cid", creditoId.toString()), Integer.class);
        if (yaEnviado != null && yaEnviado > 0) {
            throw new BusinessException("Este credito ya fue enviado individualmente");
        }

        String dni = (String) row.get("dni");
        BigDecimal monto = (BigDecimal) row.get("monto");

        // 2) Validar DNI en FT
        int employeeId = ftRepo.findEmployeeIdByDni(dni)
                .orElseThrow(() -> new BusinessException(
                        "El trabajador con DNI " + dni + " no existe en la planilla del hospital"));

        // 3) Crear lote de 1 fila
        LocalDate paymentDate = primerPaymentDateSiguienteMes(
                LocalDate.now().getYear(), LocalDate.now().getMonthValue());
        String nombreLote = "Bodega Sub Cafe - " + dni + " (individual)";
        int loteIdFt = ftRepo.crearLote(nombreLote, 1);

        int abonoId = ftRepo.insertarAbono(
                employeeId, props.getServiceConceptId(), loteIdFt, monto, 1, paymentDate);
        ftRepo.insertarAbonoDetails(abonoId, 1, monto, paymentDate);

        // 4) Registrar en bodega
        UUID envioId = UUID.randomUUID();
        OffsetDateTime ahora = OffsetDateTime.now();
        jdbc.update("""
                INSERT INTO envios_financialtracker
                    (id, credito_id, lote_id_ft, service_concept_id, fecha,
                     enviado_por, trabajadores_enviados, monto_total, estado)
                VALUES
                    (:id, :cid, :lote, :sci, :fecha, :userId, 1, :monto, 'ACTIVO')
                """,
                new MapSqlParameterSource()
                        .addValue("id", envioId.toString())
                        .addValue("cid", creditoId.toString())
                        .addValue("lote", loteIdFt)
                        .addValue("sci", props.getServiceConceptId())
                        .addValue("fecha", ahora)
                        .addValue("userId", admin.getId().toString())
                        .addValue("monto", monto));

        return EnvioResultDto.builder()
                .id(envioId).loteIdFt(loteIdFt)
                .trabajadoresEnviados(1).montoTotal(monto)
                .fecha(ahora).estado("ACTIVO")
                .dnisNoEncontrados(List.of())
                .build();
    }

    // ─── REVERTIR ──────────────────────────────────────────────────────

    @Transactional
    public void revertirEnvio(UUID envioId, String username, String motivo) {
        Usuario admin = usuarioRepo.findByUsername(username)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado"));

        Map<String, Object> envio = jdbc.queryForMap("""
                SELECT id, lote_id_ft, estado FROM envios_financialtracker WHERE id = :id
                """, new MapSqlParameterSource("id", envioId.toString()));

        if (!"ACTIVO".equals(envio.get("estado"))) {
            throw new BusinessException("El envio ya esta REVERTIDO");
        }

        int loteIdFt = (int) envio.get("lote_id_ft");

        int borrados = ftRepo.borrarAbonosDeLote(loteIdFt);
        log.info("Revertiendo envio {}: {} abonos borrados del lote FT {}",
                envioId, borrados, loteIdFt);

        ftRepo.marcarLoteRevertido(loteIdFt, motivo != null ? motivo : "Revertido desde bodega");

        jdbc.update("""
                UPDATE envios_financialtracker
                   SET estado = 'REVERTIDO',
                       motivo_reversion = :motivo,
                       fecha_reversion = :fecha,
                       revertido_por = :userId
                 WHERE id = :id
                """,
                new MapSqlParameterSource()
                        .addValue("id", envioId.toString())
                        .addValue("motivo", motivo)
                        .addValue("fecha", OffsetDateTime.now())
                        .addValue("userId", admin.getId().toString()));
    }

    // ─── HISTORIAL ─────────────────────────────────────────────────────

    public List<EnvioResumenDto> historial() {
        return jdbc.query("""
                SELECT id, cierre_id, credito_id, lote_id_ft, fecha,
                       trabajadores_enviados, monto_total, estado,
                       motivo_reversion, fecha_reversion
                  FROM envios_financialtracker
                 ORDER BY fecha DESC
                 LIMIT 100
                """, (rs, rowNum) -> EnvioResumenDto.builder()
                        .id(UUID.fromString(rs.getString("id")))
                        .cierreId(rs.getString("cierre_id") != null
                                ? UUID.fromString(rs.getString("cierre_id")) : null)
                        .creditoId(rs.getString("credito_id") != null
                                ? UUID.fromString(rs.getString("credito_id")) : null)
                        .loteIdFt(rs.getInt("lote_id_ft"))
                        .fecha(rs.getObject("fecha", OffsetDateTime.class))
                        .trabajadoresEnviados(rs.getInt("trabajadores_enviados"))
                        .montoTotal(rs.getBigDecimal("monto_total"))
                        .estado(rs.getString("estado"))
                        .motivoReversion(rs.getString("motivo_reversion"))
                        .fechaReversion(rs.getObject("fecha_reversion", OffsetDateTime.class))
                        .build());
    }

    public boolean health() {
        return ftRepo.ping();
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private LocalDate primerPaymentDateSiguienteMes(int anio, int mes) {
        LocalDate base = LocalDate.of(anio, mes, 1).plusMonths(1);
        int dia = Math.min(props.getDiaDescuento(), 28);
        return base.withDayOfMonth(dia);
    }

    private static String mesToLabel(int mes) {
        String[] labels = {"enero", "febrero", "marzo", "abril", "mayo", "junio",
                "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"};
        return labels[mes - 1];
    }
}
