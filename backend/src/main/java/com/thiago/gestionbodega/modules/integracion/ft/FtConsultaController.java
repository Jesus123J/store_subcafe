package com.thiago.gestionbodega.modules.integracion.ft;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * API de SOLO LECTURA sobre la BD financialtracker1 (planilla del HSJ).
 *
 * Expone via REST lo mismo que la app Swing FinantialTracker consulta con
 * sus DAOs: empleados, prestamos, abonos, vouchers, conceptos y las
 * estadisticas agregadas por empleado. No escribe nada — las escrituras
 * siguen viviendo en la app Swing (planilla) y en el push de deuda de la
 * bodega (FinancialTrackerController).
 *
 * Si la integracion esta desactivada (integracion.financialtracker.enabled=false)
 * todos los endpoints responden 503 con mensaje claro.
 */
@Tag(name = "Consulta FinantialTracker",
     description = "Lectura de la planilla del HSJ: empleados, prestamos, abonos, vouchers")
@RestController
@RequestMapping("/integracion/ft")
@RequiredArgsConstructor
public class FtConsultaController {

    private final ObjectProvider<FinancialTrackerRepository> repoProvider;

    @GetMapping("/empleados")
    public ApiResponse<List<Map<String, Object>>> empleados() {
        return ApiResponse.ok(repo().listarEmpleados());
    }

    @GetMapping("/empleados/{dni}")
    public ApiResponse<Map<String, Object>> empleado(@PathVariable String dni) {
        return ApiResponse.ok(repo().buscarEmpleadoPorDni(dni)
                .orElseThrow(() -> new NotFoundException(
                        "No existe empleado con DNI " + dni + " en FinantialTracker")));
    }

    @GetMapping("/empleados/{dni}/prestamos")
    public ApiResponse<List<Map<String, Object>>> prestamos(@PathVariable String dni) {
        verificarEmpleado(dni);
        return ApiResponse.ok(repo().listarPrestamosPorDni(dni));
    }

    @GetMapping("/empleados/{dni}/abonos")
    public ApiResponse<List<Map<String, Object>>> abonos(@PathVariable String dni) {
        verificarEmpleado(dni);
        return ApiResponse.ok(repo().listarAbonosPorDni(dni));
    }

    /**
     * Estadisticas agregadas del empleado — espejo del dashboard
     * "ESTADISTICAS EMPLEADO" de la app Swing (EmployeeStatsDao):
     * totales, refinanciamientos, y distribucion por estado.
     */
    @GetMapping("/empleados/{dni}/estadisticas")
    public ApiResponse<Map<String, Object>> estadisticas(@PathVariable String dni) {
        FinancialTrackerRepository repo = repo();
        Map<String, Object> empleado = repo.buscarEmpleadoPorDni(dni)
                .orElseThrow(() -> new NotFoundException(
                        "No existe empleado con DNI " + dni + " en FinantialTracker"));

        List<Map<String, Object>> prestamos = repo.listarPrestamosPorDni(dni);
        List<Map<String, Object>> abonos = repo.listarAbonosPorDni(dni);

        long refinanciamientos = prestamos.stream()
                .filter(p -> {
                    Object ref = p.get("refinanciaA");
                    return ref instanceof Number n && n.intValue() > 0;
                })
                .count();

        double montoTotalAbonos = abonos.stream()
                .map(a -> a.get("montoMensual"))
                .filter(Number.class::isInstance)
                .mapToDouble(m -> ((Number) m).doubleValue())
                .sum();

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("empleado", empleado);
        stats.put("totalPrestamos", prestamos.size());
        stats.put("totalRefinanciamientos", refinanciamientos);
        stats.put("totalAbonos", abonos.size());
        stats.put("montoTotalAbonos", montoTotalAbonos);
        stats.put("prestamosPorEstado", contarPor(prestamos, "estado"));
        stats.put("abonosPorEstado", contarPor(abonos, "estado"));
        stats.put("prestamosPorMes", contarPorMes(prestamos, "creadoEn"));
        stats.put("abonosPorMes", contarPorMes(abonos, "creadoEn"));
        return ApiResponse.ok(stats);
    }

    @GetMapping("/vouchers")
    public ApiResponse<List<Map<String, Object>>> vouchers(
            @RequestParam(defaultValue = "50") int limite) {
        return ApiResponse.ok(repo().listarVouchers(Math.min(Math.max(limite, 1), 500)));
    }

    @GetMapping("/conceptos")
    public ApiResponse<List<Map<String, Object>>> conceptos() {
        return ApiResponse.ok(repo().listarConceptos());
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FinancialTrackerRepository repo() {
        FinancialTrackerRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }

    private void verificarEmpleado(String dni) {
        if (repo().buscarEmpleadoPorDni(dni).isEmpty()) {
            throw new NotFoundException(
                    "No existe empleado con DNI " + dni + " en FinantialTracker");
        }
    }

    private static Map<String, Long> contarPor(List<Map<String, Object>> filas, String campo) {
        Map<String, Long> conteo = new HashMap<>();
        for (Map<String, Object> fila : filas) {
            Object valor = fila.get(campo);
            if (valor != null) {
                conteo.merge(valor.toString(), 1L, Long::sum);
            }
        }
        return conteo;
    }

    /**
     * Agrupa por mes calendario los ultimos 12 meses, buckets "MMM yyyy"
     * en espanol y en orden cronologico (mismo formato que usa el dashboard
     * Swing de FinantialTracker para sus graficos de barras).
     */
    private static Map<String, Integer> contarPorMes(List<Map<String, Object>> filas, String campo) {
        java.time.format.DateTimeFormatter fmt =
                java.time.format.DateTimeFormatter.ofPattern("MMM yyyy", new java.util.Locale("es"));
        java.time.YearMonth ahora = java.time.YearMonth.now();
        Map<String, Integer> resultado = new LinkedHashMap<>();
        for (int i = 11; i >= 0; i--) {
            resultado.put(ahora.minusMonths(i).atDay(1).format(fmt), 0);
        }
        for (Map<String, Object> fila : filas) {
            java.time.LocalDate fecha = aFecha(fila.get(campo));
            if (fecha == null) continue;
            java.time.YearMonth ym = java.time.YearMonth.from(fecha);
            if (ym.isBefore(ahora.minusMonths(11)) || ym.isAfter(ahora)) continue;
            resultado.merge(ym.atDay(1).format(fmt), 1, Integer::sum);
        }
        return resultado;
    }

    /** Las columnas de fecha en FT llegan como Date, Timestamp o varchar. */
    private static java.time.LocalDate aFecha(Object valor) {
        if (valor == null) return null;
        if (valor instanceof java.sql.Date d) return d.toLocalDate();
        if (valor instanceof java.sql.Timestamp t) return t.toLocalDateTime().toLocalDate();
        if (valor instanceof java.time.LocalDate ld) return ld;
        if (valor instanceof java.time.LocalDateTime ldt) return ldt.toLocalDate();
        String s = valor.toString();
        if (s.length() < 10) return null;
        try {
            return java.time.LocalDate.parse(s.substring(0, 10));
        } catch (Exception e) {
            return null;
        }
    }
}
