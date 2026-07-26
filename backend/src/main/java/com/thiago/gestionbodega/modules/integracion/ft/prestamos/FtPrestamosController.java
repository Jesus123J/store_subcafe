package com.thiago.gestionbodega.modules.integracion.ft.prestamos;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * API del modulo de PRESTAMOS de FinantialTracker (planilla del HSJ).
 * Espejo REST de LoanDao y LoanDetailsDao (Swing): un endpoint por cada
 * metodo publico que toca BD, bajo /integracion/ft/prestamos (tabla loan) y
 * /integracion/ft/prestamos-detalle (tabla loandetail).
 *
 * No choca con GET /integracion/ft/empleados/{dni}/prestamos de
 * FtConsultaController (otra ruta base).
 *
 * Los flujos multi-paso (crear prestamo con refinanciamiento + SoliNum %08d;
 * cambio de estado padre/hijo; aplicar pago de cuota) son transaccionales
 * server-side en FtPrestamosRepository. Los dialogos/confirmaciones del flujo
 * createLoanWithStateValidation siguen siendo client-side: la app consulta
 * pendiente-check / activo / monto-pendiente y recien entonces hace el POST.
 *
 * Si la integracion esta desactivada
 * (integracion.financialtracker.enabled=false) los endpoints fallan con
 * mensaje claro (bean del repositorio ausente).
 */
@Tag(name = "Prestamos FinantialTracker",
     description = "Prestamos y cuotas de la planilla del HSJ: listados, resumenes, creacion con refinanciamiento, estados y pagos")
@RestController
@RequestMapping("/integracion/ft")
@RequiredArgsConstructor
public class FtPrestamosController {

    private final ObjectProvider<FtPrestamosRepository> repoProvider;

    // ─── Request bodies ────────────────────────────────────────────────

    /**
     * Body del POST /prestamos. Fechas como texto: paymentDate/createdAt
     * "yyyy-MM-dd", modifiedAt "yyyy-MM-dd HH:mm:ss" (nullable).
     * refinanciarLoanId != null dispara el UPDATE del prestamo padre a
     * Refinanciado/Pagado dentro de la misma transaccion (handleRefinancing).
     */
    public record PrestamoRequest(
            String employeeId,
            String guarantorId,
            Double requestedAmount,
            Double amountWithdrawn,
            Integer dues,
            String paymentDate,
            String state,
            Integer refinanceParentId,
            Integer createdBy,
            String createdAt,
            String modifiedAt,
            Integer modifiedBy,
            String type,
            String paymentResponsibility,
            Integer refinanciarLoanId) {
    }

    /** Body del PUT /prestamos/{soliNum}/estado (updateSoliNumStatus). */
    public record EstadoRequest(String status, Integer userModifi) {
    }

    /** Body del PUT /prestamos-detalle/{id}/pago (updateLoanStateByLoandetailId). */
    public record PagoDetalleRequest(Double monthlyFeeValue, Double newPayment) {
    }

    /** Body del POST /prestamos-detalle (insertMultipleLoanDetails). */
    public record DetallesRequest(
            Integer loanId,
            Integer dues,
            String paymentDate,
            Double totalInterest,
            Double totalIntangibleFund,
            Double monthlyCapitalInstallment,
            Double monthlyInterestFee,
            Double monthlyIntangibleFundFee,
            Double monthlyFeeValue,
            Integer usuario) {
    }

    // ═══ /prestamos — LoanDao ══════════════════════════════════════════

    /** LoanDao.getAllSoliNums — autocompletado de numeros de solicitud. */
    @GetMapping("/prestamos/soli-nums")
    public ApiResponse<List<String>> soliNums() {
        return ApiResponse.ok(repo().listarSoliNums());
    }

    /** LoanDao.getAllLoans. */
    @GetMapping("/prestamos")
    public ApiResponse<List<Map<String, Object>>> todos() {
        return ApiResponse.ok(repo().listarPrestamos());
    }

    /** LoanDao.findLoansByEmployeeId (employeeId = DNI, solicitante o aval). */
    @GetMapping("/prestamos/por-empleado")
    public ApiResponse<List<Map<String, Object>>> porEmpleado(@RequestParam String employeeId) {
        return ApiResponse.ok(repo().prestamosPorEmpleado(employeeId));
    }

    /** LoanDao.getLoansByDateRange (fechas "yyyy-MM-dd"). */
    @GetMapping("/prestamos/por-rango")
    public ApiResponse<List<Map<String, Object>>> porRango(@RequestParam String inicio,
                                                           @RequestParam String fin) {
        return ApiResponse.ok(repo().prestamosPorRango(inicio, fin));
    }

    /** LoanDao.searchLoan — resumen con nombres y primera cuota. */
    @GetMapping("/prestamos/resumen/por-soli")
    public ApiResponse<List<Map<String, Object>>> resumenPorSoli(@RequestParam String soliNum) {
        return ApiResponse.ok(repo().resumenPorSoli(soliNum));
    }

    /** LoanDao.getLastLoans — ultimos N resumenes (offset para scroll infinito). */
    @GetMapping("/prestamos/resumen/ultimos")
    public ApiResponse<List<Map<String, Object>>> resumenUltimos(
            @RequestParam int limite,
            @RequestParam(defaultValue = "0") int offset) {
        return ApiResponse.ok(repo().resumenUltimos(limite, Math.max(offset, 0)));
    }

    /** LoanDao.getAllLoanss — resumenes por rango DATE(CreatedAt). */
    @GetMapping("/prestamos/resumen/por-rango")
    public ApiResponse<List<Map<String, Object>>> resumenPorRango(@RequestParam String inicio,
                                                                  @RequestParam String fin) {
        return ApiResponse.ok(repo().resumenPorRango(inicio, fin));
    }

    /** LoanDao.fillLoanTable — filas del listado principal. */
    @GetMapping("/prestamos/tabla")
    public ApiResponse<List<Map<String, Object>>> tabla() {
        return ApiResponse.ok(repo().tablaPrestamos());
    }

    /** LoanDao.hasLoanInState (helper de createLoanWithStateValidation). */
    @GetMapping("/prestamos/pendiente-check")
    public ApiResponse<Map<String, Object>> pendienteCheck(@RequestParam String employeeId,
                                                           @RequestParam String state) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("tiene", repo().tienePrestamoEnEstado(employeeId, state));
        return ApiResponse.ok(data);
    }

    /**
     * LoanDao.findLatestLoanByState (helper de createLoanWithStateValidation).
     * 404 = el empleado no tiene prestamo activo en ese estado.
     */
    @GetMapping("/prestamos/activo")
    public ApiResponse<Map<String, Object>> activo(@RequestParam String employeeId,
                                                   @RequestParam String state) {
        return ApiResponse.ok(repo().prestamoActivo(employeeId, state)
                .orElseThrow(() -> new NotFoundException(
                        "No hay prestamo " + state + " pendiente para el empleado " + employeeId)));
    }

    /** LoanDao.findLoan(int idLoan). */
    @GetMapping("/prestamos/por-id/{id}")
    public ApiResponse<Map<String, Object>> porId(@PathVariable int id) {
        return ApiResponse.ok(repo().buscarPorId(id)
                .orElseThrow(() -> new NotFoundException(
                        "No existe prestamo con ID " + id + " en FinantialTracker")));
    }

    /** LoanDao.findLoan(String numSoli). */
    @GetMapping("/prestamos/por-soli/{numSoli}")
    public ApiResponse<Map<String, Object>> porSoli(@PathVariable String numSoli) {
        return ApiResponse.ok(repo().buscarPorSoli(numSoli)
                .orElseThrow(() -> new NotFoundException(
                        "No existe prestamo con SoliNum " + numSoli + " en FinantialTracker")));
    }

    /**
     * LoanDao.createLoanWithStateValidation (tramo de insercion):
     * refinanciamiento del padre (opcional) + INSERT + SoliNum %08d en una
     * sola transaccion. Devuelve {id, soliNum}.
     */
    @PostMapping("/prestamos")
    public ApiResponse<Map<String, Object>> crear(@RequestBody PrestamoRequest body) {
        Map<String, Object> data = repo().crearPrestamo(
                body.employeeId(), body.guarantorId(),
                body.requestedAmount(), body.amountWithdrawn(),
                body.dues(), body.paymentDate(), body.state(),
                body.refinanceParentId(), body.createdBy(), body.createdAt(),
                body.modifiedAt(), body.modifiedBy(), body.type(),
                body.paymentResponsibility(), body.refinanciarLoanId());
        return ApiResponse.ok(data, "Prestamo registrado");
    }

    /**
     * LoanDao.updateSoliNumStatus — transaccion padre/hijo de
     * refinanciamiento. 404 si el SoliNum no existe (la app lo convierte en
     * la misma SQLException del DAO original).
     */
    @PutMapping("/prestamos/{soliNum}/estado")
    public ApiResponse<Map<String, Object>> actualizarEstado(@PathVariable String soliNum,
                                                             @RequestBody EstadoRequest body) {
        boolean encontrado = repo().actualizarEstadoPrestamo(
                soliNum, body.status(), body.userModifi());
        if (!encontrado) {
            throw new NotFoundException(
                    "No se encontró ningún préstamo con SoliNum = " + soliNum);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("soliNum", soliNum);
        data.put("status", body.status());
        return ApiResponse.ok(data, "Estado del prestamo actualizado");
    }

    /**
     * LoanDao.updatePaymentResponsibility — valida aval y estados antes de
     * pasar a 'GUARANTOR'. 404 si el SoliNum no existe; si no cumple, el
     * motivo va en data.resultado (SIN_AVAL | NO_CUMPLE) y la app muestra
     * el dialogo correspondiente.
     */
    @PutMapping("/prestamos/{soliNum}/responsabilidad-pago")
    public ApiResponse<Map<String, Object>> responsabilidadPago(@PathVariable String soliNum) {
        return ApiResponse.ok(repo().cambiarResponsabilidadPago(soliNum)
                .orElseThrow(() -> new NotFoundException(
                        "No existe prestamo con SoliNum " + soliNum + " en FinantialTracker")));
    }

    /**
     * LoanDetailsDao.updatePaymentResponsibilityToGuarantor — pase directo
     * (sin validaciones) de toda la deuda al aval, con ModifiedAt = NOW().
     */
    @PutMapping("/prestamos/{soliNum}/responsabilidad-aval")
    public ApiResponse<Map<String, Object>> responsabilidadAval(@PathVariable String soliNum) {
        int filas = repo().pasarResponsabilidadAval(soliNum);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("soliNum", soliNum);
        data.put("filasAfectadas", filas);
        return ApiResponse.ok(data, "Responsabilidad de pago pasada al aval");
    }

    // ═══ /prestamos-detalle — LoanDetailsDao ═══════════════════════════

    /** LoanDetailsDao.getAllLoanDetails. */
    @GetMapping("/prestamos-detalle")
    public ApiResponse<List<Map<String, Object>>> detalles() {
        return ApiResponse.ok(repo().listarDetalles());
    }

    /** LoanDetailsDao.findLoanDetailsByLoanId. */
    @GetMapping("/prestamos-detalle/por-prestamo")
    public ApiResponse<List<Map<String, Object>>> detallesPorPrestamo(@RequestParam int loanId) {
        return ApiResponse.ok(repo().detallesPorPrestamo(loanId));
    }

    /** LoanDetailsDao.insertMultipleLoanDetails — genera las N cuotas. */
    @PostMapping("/prestamos-detalle")
    public ApiResponse<Map<String, Object>> crearDetalles(@RequestBody DetallesRequest body) {
        repo().insertarDetalles(
                body.loanId(), body.dues(), body.paymentDate(),
                body.totalInterest(), body.totalIntangibleFund(),
                body.monthlyCapitalInstallment(), body.monthlyInterestFee(),
                body.monthlyIntangibleFundFee(), body.monthlyFeeValue(),
                body.usuario());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("loanId", body.loanId());
        data.put("cuotas", body.dues());
        return ApiResponse.ok(data, "Cuotas del prestamo registradas");
    }

    /**
     * LoanDetailsDao.updateLoanStateByLoandetailId — aplica el pago a la
     * cuota y cierra el loan si todas quedan pagadas (transaccional).
     */
    @PutMapping("/prestamos-detalle/{id}/pago")
    public ApiResponse<Map<String, Object>> aplicarPago(@PathVariable long id,
                                                        @RequestBody PagoDetalleRequest body) {
        repo().aplicarPagoDetalle(id, body.monthlyFeeValue(), body.newPayment());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("loandetailId", id);
        return ApiResponse.ok(data, "Pago aplicado a la cuota");
    }

    /** LoanDetailsDao.calcularMontoPendientePorLoanId. */
    @GetMapping("/prestamos-detalle/monto-pendiente")
    public ApiResponse<Map<String, Object>> montoPendiente(@RequestParam int loanId) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("monto", repo().montoPendiente(loanId));
        return ApiResponse.ok(data);
    }

    /** LoanDetailsDao.getLoanDetailById — historial de una cuota. */
    @GetMapping("/prestamos-detalle/{id}/historial")
    public ApiResponse<Map<String, Object>> historialDetalle(@PathVariable int id) {
        return ApiResponse.ok(repo().historialDetalle(id)
                .orElseThrow(() -> new NotFoundException(
                        "No existe detalle de prestamo con ID " + id + " en FinantialTracker")));
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FtPrestamosRepository repo() {
        FtPrestamosRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }
}
