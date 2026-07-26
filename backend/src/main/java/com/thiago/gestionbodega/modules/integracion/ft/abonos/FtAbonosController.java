package com.thiago.gestionbodega.modules.integracion.ft.abonos;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.DeleteMapping;
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
 * API de LECTURA + ESCRITURA del modulo ABONOS de FinantialTracker.
 *
 * Un endpoint por metodo de {@link FtAbonosRepository}, que a su vez replica
 * el SQL exacto de los DAOs Swing (AbonoDao, AbonoDetailsDao,
 * LoteCargaAbonoDao, ServiceConceptDao). La app Swing consume estos endpoints
 * primero y cae a su JDBC directo si el backend no responde.
 *
 * OJO rutas: GET /integracion/ft/conceptos y GET /integracion/ft/vouchers ya
 * existen en FtConsultaController — aqui solo se agregan escrituras y
 * lecturas con subrutas distintas ("/conceptos/completos", etc).
 *
 * Si la integracion esta desactivada (integracion.financialtracker.enabled=false)
 * todos los endpoints responden 503 con mensaje claro.
 */
@Tag(name = "Abonos FinantialTracker",
     description = "CRUD de abonos, cuotas, lotes de carga y conceptos de la planilla del HSJ")
@RestController
@RequestMapping("/integracion/ft")
@RequiredArgsConstructor
public class FtAbonosController {

    private final ObjectProvider<FtAbonosRepository> repoProvider;

    // ═══ Abonos (AbonoDao) ═════════════════════════════════════════════

    /** AbonoDao.findAllAbonos() */
    @GetMapping("/abonos")
    public ApiResponse<List<Map<String, Object>>> listar() {
        return ApiResponse.ok(repo().listarAbonos());
    }

    /** AbonoDao.findAbonoById(int) */
    @GetMapping("/abonos/{id}")
    public ApiResponse<Map<String, Object>> porId(@PathVariable int id) {
        return ApiResponse.ok(repo().buscarAbonoPorId(id)
                .orElseThrow(() -> new NotFoundException(
                        "No existe abono con ID " + id + " en FinantialTracker")));
    }

    /** AbonoDao.insertAbono(AbonoTb) — devuelve el id generado (SoliNum = LPAD(id,8,'0')). */
    @PostMapping("/abonos")
    public ApiResponse<Map<String, Object>> insertar(@RequestBody Map<String, Object> abono) {
        Integer id = repo().insertarAbono(abono);
        return ApiResponse.ok(mapa("id", id), "Abono registrado");
    }

    /** AbonoDao.updateAbono(AbonoTb) */
    @PutMapping("/abonos/{id}")
    public ApiResponse<Map<String, Object>> actualizar(@PathVariable int id,
                                                       @RequestBody Map<String, Object> abono) {
        return ApiResponse.ok(mapa("actualizado", repo().actualizarAbono(id, abono)));
    }

    /** AbonoDao.deleteAbono(int) */
    @DeleteMapping("/abonos/{id}")
    public ApiResponse<Map<String, Object>> eliminar(@PathVariable int id) {
        return ApiResponse.ok(mapa("borrado", repo().eliminarAbono(id)));
    }

    /** AbonoDao.renounceAbono — 404 si el SoliNum no existe; renunciado=false si ya estaba pagado. */
    @PutMapping("/abonos/soli/{soliNum}/renuncia")
    public ApiResponse<Map<String, Object>> renunciar(@PathVariable String soliNum,
                                                      @RequestBody Map<String, Object> body) {
        Boolean renunciado = repo()
                .renunciarAbono(soliNum, reqInt(body, "modifiedBy"), str(body, "modifiedAt"))
                .orElseThrow(() -> new NotFoundException(
                        "No existe abono con SoliNum " + soliNum + " en FinantialTracker"));
        return ApiResponse.ok(mapa("renunciado", renunciado));
    }

    /** AbonoDao.deleteAbonoIfNotUsed — 404 si no existe; {borrado,motivo?} si tiene pagos. */
    @DeleteMapping("/abonos/soli/{soliNum}")
    public ApiResponse<Map<String, Object>> eliminarPorSoli(@PathVariable String soliNum) {
        return ApiResponse.ok(repo().eliminarAbonoSiNoUsado(soliNum)
                .orElseThrow(() -> new NotFoundException(
                        "No existe abono con SoliNum " + soliNum + " en FinantialTracker")));
    }

    /** AbonoDao.getListAbonoBySoli(String) — cuotas del abono por SoliNum. */
    @GetMapping("/abonos/soli/{soliNum}/detalles")
    public ApiResponse<List<Map<String, Object>>> detallesPorSoli(@PathVariable String soliNum) {
        return ApiResponse.ok(repo().detallesPorSoliNum(soliNum));
    }

    /** AbonoDao.hasPendingAbono(String, String) */
    @GetMapping("/abonos/pendiente")
    public ApiResponse<Map<String, Object>> tienePendiente(@RequestParam String employeeId,
                                                           @RequestParam String conceptoId) {
        return ApiResponse.ok(mapa("pendiente", repo().tienePendiente(employeeId, conceptoId)));
    }

    /** AbonoDao.findAbonosByEmployeeAndCurrentYear(String) — solo status 'Pendiente'. */
    @GetMapping("/abonos/pendientes/{employeeId}")
    public ApiResponse<List<Map<String, Object>>> pendientesPorEmpleado(
            @PathVariable String employeeId) {
        return ApiResponse.ok(repo().abonosPendientesPorEmpleado(employeeId));
    }

    /** AbonoDao.getAvailableDates — buckets {anio, mes, total}; el texto lo arma la app. */
    @GetMapping("/abonos/fechas-disponibles")
    public ApiResponse<List<Map<String, Object>>> fechasDisponibles(
            @RequestParam int conceptoId, @RequestParam String codigoEmpleado) {
        return ApiResponse.ok(repo().fechasDisponibles(conceptoId, codigoEmpleado));
    }

    /** AbonoDao.getListAbonoTByConcepAndCodeEm — fecha opcional (yyyy-MM-dd) filtra YEAR/MONTH. */
    @GetMapping("/abonos/por-concepto")
    public ApiResponse<List<Map<String, Object>>> porConcepto(
            @RequestParam int conceptoId,
            @RequestParam String codigoEmpleado,
            @RequestParam(required = false) String fecha) {
        return ApiResponse.ok(repo().abonosPorConcepto(conceptoId, codigoEmpleado, fecha));
    }

    /** AbonoDao.getListAbonoTByConcepAndCodeEmRange — rango de fechas yyyy-MM-dd. */
    @GetMapping("/abonos/por-concepto/rango")
    public ApiResponse<List<Map<String, Object>>> porConceptoRango(
            @RequestParam int conceptoId,
            @RequestParam String codigoEmpleado,
            @RequestParam String inicio,
            @RequestParam String fin) {
        return ApiResponse.ok(repo().abonosPorConceptoRango(conceptoId, codigoEmpleado, inicio, fin));
    }

    /** AbonoDao.findAllAbonos(Date, Date) — rango sobre DATE(CreatedAt). */
    @GetMapping("/abonos/rango")
    public ApiResponse<List<Map<String, Object>>> porRango(@RequestParam String inicio,
                                                           @RequestParam String fin) {
        return ApiResponse.ok(repo().abonosPorRango(inicio, fin));
    }

    /** AbonoDao.getLastAbonos(int) — offset para scroll infinito. */
    @GetMapping("/abonos/ultimos")
    public ApiResponse<List<Map<String, Object>>> ultimos(
            @RequestParam(defaultValue = "10") int limite,
            @RequestParam(defaultValue = "0") int offset) {
        return ApiResponse.ok(repo().ultimosAbonos(limite, Math.max(offset, 0)));
    }

    /** AbonoDao.getAllSoliNums() */
    @GetMapping("/abonos/solinums")
    public ApiResponse<List<String>> soliNums() {
        return ApiResponse.ok(repo().listarSoliNums());
    }

    // ═══ Cuotas (AbonoDetailsDao) ══════════════════════════════════════

    /** AbonoDetailsDao.getAllAbonoDetails() */
    @GetMapping("/abonos-detalle")
    public ApiResponse<List<Map<String, Object>>> listarDetalles() {
        return ApiResponse.ok(repo().listarDetalles());
    }

    /** AbonoDetailsDao.insertAbonoDetail(AbonoTb, int) — genera las N cuotas. */
    @PostMapping("/abonos-detalle")
    public ApiResponse<Map<String, Object>> insertarDetalles(@RequestBody Map<String, Object> body) {
        int dues = reqInt(body, "dues");
        repo().insertarDetalles(
                reqInt(body, "abonoId"),
                dues,
                reqDouble(body, "monthly"),
                str(body, "paymentDate"),
                reqInt(body, "usuario"));
        return ApiResponse.ok(mapa("generadas", dues), "Cuotas generadas");
    }

    /** AbonoDetailsDao.updateLoanStateByLoandetailId — aplica pago parcial/total en transaccion. */
    @PutMapping("/abonos-detalle/{id}/pago")
    public ApiResponse<Map<String, Object>> aplicarPago(@PathVariable long id,
                                                        @RequestBody Map<String, Object> body) {
        repo().aplicarPagoDetalle(id, reqDouble(body, "monthly"), reqDouble(body, "payment"));
        return ApiResponse.ok(mapa("aplicado", true), "Pago aplicado");
    }

    /** AbonoDetailsDao.getAbonoDetailById(Integer) — historial con descripcion del concepto. */
    @GetMapping("/abonos-detalle/{id}/historial")
    public ApiResponse<List<Map<String, Object>>> historialDetalle(@PathVariable int id) {
        return ApiResponse.ok(repo().historialDetalle(id));
    }

    /** AbonoDetailsDao.findAbonoDetailsByAbonoId(int) */
    @GetMapping("/abonos-detalle/por-abono/{abonoId}")
    public ApiResponse<List<Map<String, Object>>> detallesPorAbono(@PathVariable int abonoId) {
        return ApiResponse.ok(repo().detallesPorAbonoId(abonoId));
    }

    // ═══ Lotes de carga (LoteCargaAbonoDao) ════════════════════════════

    /** LoteCargaAbonoDao.crearLote(LoteCargaAbonoTb) — lote ACTIVO, devuelve id. */
    @PostMapping("/lotes-abono")
    public ApiResponse<Map<String, Object>> crearLote(@RequestBody Map<String, Object> body) {
        Integer id = repo().crearLote(
                str(body, "fechaCreacion"),
                optInt(body, "usuarioId"),
                str(body, "nombreArchivo"),
                reqInt(body, "cantidadAbonos"));
        return ApiResponse.ok(mapa("id", id), "Lote creado");
    }

    /** LoteCargaAbonoDao.actualizarCantidad(int, int) */
    @PutMapping("/lotes-abono/{id}/cantidad")
    public ApiResponse<Map<String, Object>> actualizarCantidad(@PathVariable int id,
                                                               @RequestBody Map<String, Object> body) {
        repo().actualizarCantidadLote(id, reqInt(body, "cantidad"));
        return ApiResponse.ok(mapa("actualizado", true));
    }

    /** LoteCargaAbonoDao.findLotesActivos() — ultimos 50 lotes ACTIVOS. */
    @GetMapping("/lotes-abono/activos")
    public ApiResponse<List<Map<String, Object>>> lotesActivos() {
        return ApiResponse.ok(repo().lotesActivos());
    }

    /** LoteCargaAbonoDao.countAbonosUsados(int) */
    @GetMapping("/lotes-abono/{id}/abonos-usados")
    public ApiResponse<Map<String, Object>> abonosUsados(@PathVariable int id) {
        return ApiResponse.ok(mapa("usados", repo().contarAbonosUsados(id)));
    }

    /** LoteCargaAbonoDao.revertirLote(int, int, String) — transaccional, devuelve borrados. */
    @PostMapping("/lotes-abono/{id}/revertir")
    public ApiResponse<Map<String, Object>> revertirLote(@PathVariable int id,
                                                         @RequestBody Map<String, Object> body) {
        int borrados = repo().revertirLote(id, reqInt(body, "usuarioId"), str(body, "motivo"));
        return ApiResponse.ok(mapa("abonosBorrados", borrados), "Lote revertido");
    }

    // ═══ Conceptos (ServiceConceptDao) ═════════════════════════════════
    // GET /integracion/ft/conceptos (resumen) vive en FtConsultaController.

    /** ServiceConceptDao.insert(ServiceConceptTb) — escritura sobre la ruta base. */
    @PostMapping("/conceptos")
    public ApiResponse<Map<String, Object>> insertarConcepto(@RequestBody Map<String, Object> body) {
        repo().insertarConcepto(body);
        return ApiResponse.ok(mapa("insertado", true), "Concepto registrado");
    }

    /** ServiceConceptDao.findServiceConceptByCodigo(String) */
    @GetMapping("/conceptos/codigo/{codigo}")
    public ApiResponse<Map<String, Object>> conceptoPorCodigo(@PathVariable String codigo) {
        return ApiResponse.ok(repo().buscarConceptoPorCodigo(codigo)
                .orElseThrow(() -> new NotFoundException(
                        "No existe concepto con codigo " + codigo + " en FinantialTracker")));
    }

    /** ServiceConceptDao.deleteServiceConceptIfNotUsed — 404 si el codigo no existe. */
    @DeleteMapping("/conceptos/codigo/{codigo}")
    public ApiResponse<Map<String, Object>> eliminarConcepto(@PathVariable String codigo) {
        return ApiResponse.ok(repo().eliminarConceptoSiNoUsado(codigo)
                .orElseThrow(() -> new NotFoundException(
                        "No existe concepto con codigo " + codigo + " en FinantialTracker")));
    }

    /** ServiceConceptDao.getAllServiceConcepts() — catalogo con todas las columnas. */
    @GetMapping("/conceptos/completos")
    public ApiResponse<List<Map<String, Object>>> conceptosCompletos() {
        return ApiResponse.ok(repo().listarConceptosCompletos());
    }

    /** ServiceConceptDao.getAllConceptDescriptions() — codigo + description para autocompletado. */
    @GetMapping("/conceptos/descripciones")
    public ApiResponse<List<Map<String, Object>>> conceptosDescripciones() {
        return ApiResponse.ok(repo().codigosYDescripciones());
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FtAbonosRepository repo() {
        FtAbonosRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }

    private static Map<String, Object> mapa(String clave, Object valor) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put(clave, valor);
        return out;
    }

    private static String str(Map<String, Object> body, String campo) {
        Object v = body.get(campo);
        return v == null ? null : v.toString();
    }

    private static int reqInt(Map<String, Object> body, String campo) {
        Integer v = optInt(body, campo);
        if (v == null) {
            throw new IllegalArgumentException("Falta el campo obligatorio '" + campo + "'");
        }
        return v;
    }

    private static Integer optInt(Map<String, Object> body, String campo) {
        Object v = body.get(campo);
        if (v == null) return null;
        if (v instanceof Number n) return n.intValue();
        return Integer.valueOf(v.toString());
    }

    private static double reqDouble(Map<String, Object> body, String campo) {
        Object v = body.get(campo);
        if (v == null) {
            throw new IllegalArgumentException("Falta el campo obligatorio '" + campo + "'");
        }
        if (v instanceof Number n) return n.doubleValue();
        return Double.parseDouble(v.toString());
    }
}
