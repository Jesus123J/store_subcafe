package com.thiago.gestionbodega.modules.integracion.ft.pagos;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * REGISTRO DE PAGOS de FinantialTracker (planilla del HSJ) via REST.
 * Espejo 1 a 1 de RegistroDao (app Swing): un endpoint por cada metodo
 * publico que toca la BD financialtracker1. Las lecturas son GET con query
 * params; las escrituras son POST/PUT y los flujos multi-paso (registro +
 * registerdetails + abonodetail/loandetail + historial) se ejecutan en UNA
 * transaccion server-side dentro de FtPagosRepository.
 *
 * Si la integracion esta desactivada
 * (integracion.financialtracker.enabled=false) los endpoints fallan con
 * mensaje claro (bean del repositorio ausente).
 */
@Tag(name = "Pagos FinantialTracker",
     description = "Registro de pagos de la planilla del HSJ: registros, reversion, lotes, correcciones, edicion y transferencias")
@RestController
@RequestMapping("/integracion/ft/pagos")
@RequiredArgsConstructor
public class FtPagosController {

    private final ObjectProvider<FtPagosRepository> repoProvider;

    // ─── Cuerpos de request ────────────────────────────────────────────

    /** Cuota (loandetail/abonodetail) con su monto, tal como la manda la UI. */
    public record CuotaRequest(Long id, Double monto) {
    }

    /** Pago completo: cabecera registro + cuotas de prestamos/bonos. */
    public record RegistroCompletoRequest(Integer empleadoId, Double amount, Integer loteId,
                                          List<CuotaRequest> prestamos, List<CuotaRequest> bonos) {
    }

    public record RegisterDetailRequest(Integer idRegistro, Long idBondDetails,
                                        Long idLoanDetails, Double amountPar) {
    }

    public record ReversionRequest(Integer registroId, String usuario, String motivo) {
    }

    public record LoteRequest(String nombreArchivo, String mes, String anio, String usuarioCarga) {
    }

    public record EstadisticasLoteRequest(Integer loteId, Integer cantidadRegistros, Double montoTotal) {
    }

    public record RegistroConLoteRequest(Integer empleadoId, Double amount, Integer loteId) {
    }

    public record LoteReversionRequest(Integer loteId, String usuario, String motivo) {
    }

    public record CorreccionRequest(String usuario, String motivo) {
    }

    public record ReorganizarRequest(Integer empleadoId, String usuario, String motivo) {
    }

    public record MontoDetalleRequest(Long idRegisterDetail, Boolean esPrestamo,
                                      Double montoAnterior, Double montoNuevo,
                                      String usuario, String motivo) {
    }

    public record EliminarDetalleRequest(Long idRegisterDetail, Boolean esPrestamo,
                                         Double monto, String usuario, String motivo) {
    }

    public record AgregarDetalleRequest(Integer registroId, Long cuotaDetailId, Double monto,
                                        String usuario, String motivo) {
    }

    public record TransferenciaRequest(Long rdIdOrigen, Long cuotaDetailId, Integer registroIdDestino,
                                       Double montoTransferir, String usuario, String motivo) {
    }

    public record VoucherEliminarRequest(Integer registroId, String usuario, String motivo) {
    }

    public record RevertirCambioRequest(Long historialId, String usuario) {
    }

    // ─── Lecturas (GET) ────────────────────────────────────────────────

    /** RegistroDao.findRegisterDetailsByEmployeeId */
    @GetMapping("/detalles-empleado")
    public ApiResponse<List<Map<String, Object>>> detallesEmpleado(
            @RequestParam String employeeId) {
        return ApiResponse.ok(repo().findRegisterDetailsByEmployeeId(employeeId));
    }

    /** RegistroDao.obtenerRegistrosPorEmpleado */
    @GetMapping("/registros-empleado")
    public ApiResponse<List<Map<String, Object>>> registrosEmpleado(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().obtenerRegistrosPorEmpleado(empleadoId));
    }

    /** RegistroDao.findByCodigo — 404 si no existe el recibo. */
    @GetMapping("/registro")
    public ApiResponse<Map<String, Object>> registroPorCodigo(@RequestParam String codigo) {
        return ApiResponse.ok(repo().findByCodigo(codigo)
                .orElseThrow(() -> new NotFoundException(
                        "No existe registro con código " + codigo + " en FinantialTracker")));
    }

    /** RegistroDao.obtenerDetallesPagoParaRevertir — HTML listo para la UI. */
    @GetMapping("/detalle-reversion")
    public ApiResponse<Map<String, Object>> detalleReversion(@RequestParam int registroId) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("html", repo().obtenerDetallesPagoParaRevertir(registroId));
        return ApiResponse.ok(data);
    }

    /** RegistroDao.obtenerLotesActivos */
    @GetMapping("/lotes-activos")
    public ApiResponse<List<Map<String, Object>>> lotesActivos() {
        return ApiResponse.ok(repo().obtenerLotesActivos());
    }

    /** RegistroDao.obtenerDetalleLoteParaRevertir — HTML listo para la UI. */
    @GetMapping("/lotes/detalle-reversion")
    public ApiResponse<Map<String, Object>> detalleLoteReversion(@RequestParam int loteId) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("html", repo().obtenerDetalleLoteParaRevertir(loteId));
        return ApiResponse.ok(data);
    }

    /** RegistroDao.buscarPagosDuplicadosPrestamos */
    @GetMapping("/duplicados/prestamos")
    public ApiResponse<List<Map<String, Object>>> duplicadosPrestamos() {
        return ApiResponse.ok(repo().buscarPagosDuplicadosPrestamos());
    }

    /** RegistroDao.buscarPagosDuplicadosAbonos */
    @GetMapping("/duplicados/abonos")
    public ApiResponse<List<Map<String, Object>>> duplicadosAbonos() {
        return ApiResponse.ok(repo().buscarPagosDuplicadosAbonos());
    }

    /** RegistroDao.buscarEmpleadosConRegistrosHuerfanos */
    @GetMapping("/huerfanos/empleados")
    public ApiResponse<List<Map<String, Object>>> empleadosConHuerfanos() {
        return ApiResponse.ok(repo().buscarEmpleadosConRegistrosHuerfanos());
    }

    /** RegistroDao.obtenerDetalleEmpleadoParaReorganizar */
    @GetMapping("/huerfanos/detalle-empleado")
    public ApiResponse<Map<String, Object>> detalleEmpleadoReorganizar(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().obtenerDetalleEmpleadoParaReorganizar(empleadoId));
    }

    /** RegistroDao.obtenerDetallesPagoParaEdicion */
    @GetMapping("/detalle-edicion")
    public ApiResponse<Map<String, Object>> detalleEdicion(@RequestParam int registroId) {
        return ApiResponse.ok(repo().obtenerDetallesPagoParaEdicion(registroId));
    }

    /** RegistroDao.obtenerDetallesCompletoPago */
    @GetMapping("/detalle-completo")
    public ApiResponse<Map<String, Object>> detalleCompleto(@RequestParam int registroId) {
        return ApiResponse.ok(repo().obtenerDetallesCompletoPago(registroId));
    }

    /** RegistroDao.buscarCuotasPrestamosPendientesEmpleado */
    @GetMapping("/cuotas/prestamos-pendientes")
    public ApiResponse<List<Map<String, Object>>> cuotasPrestamosPendientes(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().buscarCuotasPrestamosPendientesEmpleado(empleadoId));
    }

    /** RegistroDao.buscarCuotasAbonosPendientesEmpleado */
    @GetMapping("/cuotas/abonos-pendientes")
    public ApiResponse<List<Map<String, Object>>> cuotasAbonosPendientes(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().buscarCuotasAbonosPendientesEmpleado(empleadoId));
    }

    /** RegistroDao.buscarCuotasPrestamoPorSolicitud */
    @GetMapping("/cuotas/prestamos-por-solicitud")
    public ApiResponse<List<Map<String, Object>>> cuotasPrestamoPorSolicitud(
            @RequestParam String soliNum) {
        return ApiResponse.ok(repo().buscarCuotasPrestamoPorSolicitud(soliNum));
    }

    /** RegistroDao.buscarCuotasAbonoPorSolicitud */
    @GetMapping("/cuotas/abonos-por-solicitud")
    public ApiResponse<List<Map<String, Object>>> cuotasAbonoPorSolicitud(
            @RequestParam String soliNum) {
        return ApiResponse.ok(repo().buscarCuotasAbonoPorSolicitud(soliNum));
    }

    /** RegistroDao.buscarTodasCuotasPrestamosEmpleado */
    @GetMapping("/cuotas/prestamos-todas")
    public ApiResponse<List<Map<String, Object>>> todasCuotasPrestamos(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().buscarTodasCuotasPrestamosEmpleado(empleadoId));
    }

    /** RegistroDao.buscarTodasCuotasAbonosEmpleado */
    @GetMapping("/cuotas/abonos-todas")
    public ApiResponse<List<Map<String, Object>>> todasCuotasAbonos(
            @RequestParam int empleadoId) {
        return ApiResponse.ok(repo().buscarTodasCuotasAbonosEmpleado(empleadoId));
    }

    /** RegistroDao.buscarCuotasPrestamosConVoucher */
    @GetMapping("/cuotas/prestamos-con-voucher")
    public ApiResponse<List<Map<String, Object>>> cuotasPrestamosConVoucher(
            @RequestParam int empleadoId,
            @RequestParam(required = false) String soliNum,
            @RequestParam(defaultValue = "false") boolean mostrarTodas) {
        return ApiResponse.ok(repo().buscarCuotasPrestamosConVoucher(soliNum, empleadoId, mostrarTodas));
    }

    /** RegistroDao.buscarCuotasAbonosConVoucher */
    @GetMapping("/cuotas/abonos-con-voucher")
    public ApiResponse<List<Map<String, Object>>> cuotasAbonosConVoucher(
            @RequestParam int empleadoId,
            @RequestParam(required = false) String soliNum,
            @RequestParam(defaultValue = "false") boolean mostrarTodas) {
        return ApiResponse.ok(repo().buscarCuotasAbonosConVoucher(soliNum, empleadoId, mostrarTodas));
    }

    /** RegistroDao.obtenerCodigosSolicitudesPrestamos */
    @GetMapping("/codigos/prestamos")
    public ApiResponse<List<String>> codigosPrestamos() {
        return ApiResponse.ok(repo().obtenerCodigosSolicitudesPrestamos());
    }

    /** RegistroDao.obtenerCodigosSolicitudesAbonos */
    @GetMapping("/codigos/abonos")
    public ApiResponse<List<String>> codigosAbonos() {
        return ApiResponse.ok(repo().obtenerCodigosSolicitudesAbonos());
    }

    /** RegistroDao.obtenerCodigosTickets */
    @GetMapping("/codigos/tickets")
    public ApiResponse<List<String>> codigosTickets() {
        return ApiResponse.ok(repo().obtenerCodigosTickets());
    }

    /** RegistroDao.obtenerCodigosSolicitudesPrestamosPorEmpleado */
    @GetMapping("/codigos/prestamos-empleado")
    public ApiResponse<List<String>> codigosPrestamosEmpleado(@RequestParam int empleadoId) {
        return ApiResponse.ok(repo().obtenerCodigosSolicitudesPrestamosPorEmpleado(empleadoId));
    }

    /** RegistroDao.obtenerCodigosSolicitudesAbonosPorEmpleado */
    @GetMapping("/codigos/abonos-empleado")
    public ApiResponse<List<String>> codigosAbonosEmpleado(@RequestParam int empleadoId) {
        return ApiResponse.ok(repo().obtenerCodigosSolicitudesAbonosPorEmpleado(empleadoId));
    }

    /** RegistroDao.obtenerUltimosCambios */
    @GetMapping("/ultimos-cambios")
    public ApiResponse<List<Map<String, Object>>> ultimosCambios(
            @RequestParam(defaultValue = "20") int limite) {
        return ApiResponse.ok(repo().obtenerUltimosCambios(limite));
    }

    // ─── Escrituras (POST/PUT) ─────────────────────────────────────────

    /** RegistroDao.insertRegisterDetail — INSERT suelto en registerdetails. */
    @PostMapping("/register-detail")
    public ApiResponse<Map<String, Object>> insertarRegisterDetail(
            @RequestBody RegisterDetailRequest body) {
        boolean insertado = repo().insertRegisterDetail(
                body.idRegistro(), body.idBondDetails(), body.idLoanDetails(), body.amountPar());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("insertado", insertado);
        return ApiResponse.ok(data, insertado ? "Detalle registrado" : "No se pudo registrar el detalle");
    }

    /**
     * RegistroDao.insertarRegistroCompleto (ambos overloads) — pago completo
     * transaccional. resultado: 1 = ok, 3 = error SQL (codigos del DAO).
     */
    @PostMapping("/registro-completo")
    public ApiResponse<Map<String, Object>> registroCompleto(
            @RequestBody RegistroCompletoRequest body) {
        int idRegistro = repo().insertarRegistroCompleto(
                body.empleadoId(), body.amount(),
                aCuotas(body.prestamos()), aCuotas(body.bonos()));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("resultado", idRegistro > 0 ? 1 : 3);
        data.put("idRegistro", idRegistro);
        return ApiResponse.ok(data, idRegistro > 0 ? "Pago registrado" : "Error al registrar pago");
    }

    /** RegistroDao.insertarRegistroCompletoConLote — igual pero con lote_id + codigo P/. */
    @PostMapping("/registro-completo-lote")
    public ApiResponse<Map<String, Object>> registroCompletoConLote(
            @RequestBody RegistroCompletoRequest body) {
        int idRegistro = repo().insertarRegistroCompletoConLote(
                body.empleadoId(), body.amount(), body.loteId(),
                aCuotas(body.prestamos()), aCuotas(body.bonos()));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("resultado", idRegistro > 0 ? 1 : 3);
        data.put("idRegistro", idRegistro);
        return ApiResponse.ok(data, idRegistro > 0 ? "Pago registrado" : "Error al registrar pago");
    }

    /** RegistroDao.revertirPago — reversion completa transaccional. */
    @PostMapping("/reversion")
    public ApiResponse<Map<String, Object>> revertirPago(@RequestBody ReversionRequest body) {
        boolean revertido = repo().revertirPago(body.registroId(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("revertido", revertido);
        return ApiResponse.ok(data, revertido ? "Pago revertido" : "No se pudo revertir el pago");
    }

    /** RegistroDao.crearLoteCarga */
    @PostMapping("/lotes")
    public ApiResponse<Map<String, Object>> crearLote(@RequestBody LoteRequest body) {
        int loteId = repo().crearLoteCarga(
                body.nombreArchivo(), body.mes(), body.anio(), body.usuarioCarga());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("loteId", loteId);
        return ApiResponse.ok(data, loteId > 0 ? "Lote creado" : "No se pudo crear el lote");
    }

    /** RegistroDao.actualizarEstadisticasLote */
    @PutMapping("/lotes/estadisticas")
    public ApiResponse<Map<String, Object>> actualizarEstadisticasLote(
            @RequestBody EstadisticasLoteRequest body) {
        repo().actualizarEstadisticasLote(
                body.loteId(), body.cantidadRegistros(), body.montoTotal());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("loteId", body.loteId());
        return ApiResponse.ok(data, "Estadísticas del lote actualizadas");
    }

    /** RegistroDao.insertarRegistroConLote */
    @PostMapping("/registro-con-lote")
    public ApiResponse<Map<String, Object>> registroConLote(
            @RequestBody RegistroConLoteRequest body) {
        int idRegistro = repo().insertarRegistroConLote(
                body.empleadoId(), body.amount(), body.loteId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("idRegistro", idRegistro);
        return ApiResponse.ok(data, idRegistro > 0 ? "Registro insertado" : "No se pudo insertar el registro");
    }

    /** RegistroDao.revertirLoteCarga — reversion masiva transaccional. */
    @PostMapping("/lotes/reversion")
    public ApiResponse<Map<String, Object>> revertirLote(@RequestBody LoteReversionRequest body) {
        boolean revertido = repo().revertirLoteCarga(body.loteId(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("revertido", revertido);
        return ApiResponse.ok(data, revertido ? "Lote revertido" : "No se pudo revertir el lote");
    }

    /** RegistroDao.corregirPagosDuplicadosPrestamos */
    @PostMapping("/correccion/prestamos")
    public ApiResponse<Map<String, Object>> corregirDuplicadosPrestamos(
            @RequestBody CorreccionRequest body) {
        int corregidos = repo().corregirPagosDuplicadosPrestamos(body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("corregidos", corregidos);
        return ApiResponse.ok(data, "Corrección de préstamos ejecutada");
    }

    /** RegistroDao.corregirPagosDuplicadosAbonos */
    @PostMapping("/correccion/abonos")
    public ApiResponse<Map<String, Object>> corregirDuplicadosAbonos(
            @RequestBody CorreccionRequest body) {
        int corregidos = repo().corregirPagosDuplicadosAbonos(body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("corregidos", corregidos);
        return ApiResponse.ok(data, "Corrección de abonos ejecutada");
    }

    /** RegistroDao.reorganizarPagosEmpleado */
    @PostMapping("/huerfanos/reorganizar")
    public ApiResponse<Map<String, Object>> reorganizarPagos(@RequestBody ReorganizarRequest body) {
        int reorganizados = repo().reorganizarPagosEmpleado(
                body.empleadoId(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("reorganizados", reorganizados);
        return ApiResponse.ok(data, "Reorganización ejecutada");
    }

    /** RegistroDao.eliminarRegistrosVacios */
    @PostMapping("/registros-vacios/limpiar")
    public ApiResponse<Map<String, Object>> eliminarRegistrosVacios() {
        int eliminados = repo().eliminarRegistrosVacios();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eliminados", eliminados);
        return ApiResponse.ok(data, "Registros vacíos eliminados");
    }

    /** RegistroDao.actualizarMontoDetallePago */
    @PutMapping("/detalle/monto")
    public ApiResponse<Map<String, Object>> actualizarMontoDetalle(
            @RequestBody MontoDetalleRequest body) {
        boolean actualizado = repo().actualizarMontoDetallePago(
                body.idRegisterDetail(), Boolean.TRUE.equals(body.esPrestamo()),
                body.montoAnterior(), body.montoNuevo(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("actualizado", actualizado);
        return ApiResponse.ok(data, actualizado ? "Monto actualizado" : "No se pudo actualizar el monto");
    }

    /** RegistroDao.eliminarDetallePago (POST porque DELETE no lleva body). */
    @PostMapping("/detalle/eliminar")
    public ApiResponse<Map<String, Object>> eliminarDetalle(
            @RequestBody EliminarDetalleRequest body) {
        boolean eliminado = repo().eliminarDetallePago(
                body.idRegisterDetail(), Boolean.TRUE.equals(body.esPrestamo()),
                body.monto(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eliminado", eliminado);
        return ApiResponse.ok(data, eliminado ? "Detalle eliminado" : "No se pudo eliminar el detalle");
    }

    /** RegistroDao.agregarDetallePrestamoARegistro */
    @PostMapping("/detalle/prestamo")
    public ApiResponse<Map<String, Object>> agregarDetallePrestamo(
            @RequestBody AgregarDetalleRequest body) {
        boolean agregado = repo().agregarDetallePrestamoARegistro(
                body.registroId(), body.cuotaDetailId(), body.monto(),
                body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("agregado", agregado);
        return ApiResponse.ok(data, agregado ? "Detalle de préstamo agregado" : "No se pudo agregar el detalle");
    }

    /** RegistroDao.agregarDetalleAbonoARegistro */
    @PostMapping("/detalle/abono")
    public ApiResponse<Map<String, Object>> agregarDetalleAbono(
            @RequestBody AgregarDetalleRequest body) {
        boolean agregado = repo().agregarDetalleAbonoARegistro(
                body.registroId(), body.cuotaDetailId(), body.monto(),
                body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("agregado", agregado);
        return ApiResponse.ok(data, agregado ? "Detalle de abono agregado" : "No se pudo agregar el detalle");
    }

    /** RegistroDao.transferirPagoPrestamoAVoucher */
    @PostMapping("/transferencia/prestamo")
    public ApiResponse<Map<String, Object>> transferirPrestamo(
            @RequestBody TransferenciaRequest body) {
        boolean transferido = repo().transferirPagoPrestamoAVoucher(
                body.rdIdOrigen(), body.cuotaDetailId(), body.registroIdDestino(),
                body.montoTransferir(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("transferido", transferido);
        return ApiResponse.ok(data, transferido ? "Pago transferido" : "No se pudo transferir el pago");
    }

    /** RegistroDao.transferirPagoAbonoAVoucher */
    @PostMapping("/transferencia/abono")
    public ApiResponse<Map<String, Object>> transferirAbono(
            @RequestBody TransferenciaRequest body) {
        boolean transferido = repo().transferirPagoAbonoAVoucher(
                body.rdIdOrigen(), body.cuotaDetailId(), body.registroIdDestino(),
                body.montoTransferir(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("transferido", transferido);
        return ApiResponse.ok(data, transferido ? "Pago transferido" : "No se pudo transferir el pago");
    }

    /** RegistroDao.eliminarVoucherSiVacio */
    @PostMapping("/voucher/eliminar-si-vacio")
    public ApiResponse<Map<String, Object>> eliminarVoucherSiVacio(
            @RequestBody VoucherEliminarRequest body) {
        boolean eliminado = repo().eliminarVoucherSiVacio(body.registroId(), body.usuario());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eliminado", eliminado);
        return ApiResponse.ok(data, eliminado ? "Voucher vacío eliminado" : "El voucher no estaba vacío");
    }

    /** RegistroDao.eliminarVoucherCompleto */
    @PostMapping("/voucher/eliminar-completo")
    public ApiResponse<Map<String, Object>> eliminarVoucherCompleto(
            @RequestBody VoucherEliminarRequest body) {
        boolean eliminado = repo().eliminarVoucherCompleto(
                body.registroId(), body.usuario(), body.motivo());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eliminado", eliminado);
        return ApiResponse.ok(data, eliminado ? "Voucher eliminado" : "No se pudo eliminar el voucher");
    }

    /** RegistroDao.revertirCambio */
    @PostMapping("/cambios/revertir")
    public ApiResponse<Map<String, Object>> revertirCambio(
            @RequestBody RevertirCambioRequest body) {
        boolean revertido = repo().revertirCambio(body.historialId(), body.usuario());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("revertido", revertido);
        return ApiResponse.ok(data, revertido ? "Cambio revertido" : "No se pudo revertir el cambio");
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FtPagosRepository repo() {
        FtPagosRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }

    private static List<FtPagosRepository.DetalleCuota> aCuotas(List<CuotaRequest> cuotas) {
        List<FtPagosRepository.DetalleCuota> out = new ArrayList<>();
        if (cuotas != null) {
            for (CuotaRequest c : cuotas) {
                out.add(new FtPagosRepository.DetalleCuota(c.id(), c.monto()));
            }
        }
        return out;
    }
}
