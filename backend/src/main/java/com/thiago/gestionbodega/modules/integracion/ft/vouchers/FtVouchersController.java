package com.thiago.gestionbodega.modules.integracion.ft.vouchers;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Escrituras del modulo de VOUCHERS de FinantialTracker (constancias de
 * entrega de la planilla del HSJ). Espejo REST de PaymentVoucher (Swing):
 * crear/confirmar voucher, actualizarlo, reservar el correlativo y limpiar
 * reservas no usadas.
 *
 * El GET de listado ya existe en FtConsultaController
 * (GET /integracion/ft/vouchers) — aqui solo van POST/PUT/DELETE bajo la
 * misma ruta, sin colision de mappings.
 *
 * Si la integracion esta desactivada
 * (integracion.financialtracker.enabled=false) los endpoints fallan con
 * mensaje claro (bean del repositorio ausente).
 */
@Tag(name = "Vouchers FinantialTracker",
     description = "Escritura de vouchers de la planilla del HSJ: crear, actualizar, reservar numero y limpiar reservas")
@RestController
@RequestMapping("/integracion/ft/vouchers")
@RequiredArgsConstructor
public class FtVouchersController {

    private final ObjectProvider<FtVouchersRepository> repoProvider;

    /**
     * Body compartido por POST (crear) y PUT (actualizar). dateEntry viaja
     * como texto "yyyy-MM-dd" porque la columna date_entry es varchar.
     */
    public record VoucherRequest(
            String numVoucher,
            String numAccount,
            String numCheck,
            String bank,
            String dateEntry,
            Double amount,
            String details,
            String documentDni,
            String nameLastname,
            Integer userId) {
    }

    /**
     * Crea el voucher definitivo: confirma la reserva en voucher_temp y
     * hace el INSERT en voucher, transaccional server-side.
     */
    @PostMapping
    public ApiResponse<Map<String, Object>> crear(@RequestBody VoucherRequest body)
            throws SQLException {
        int filas = repo().crearVoucher(
                body.numVoucher(), body.numAccount(), body.numCheck(), body.bank(),
                body.dateEntry(), body.amount(), body.details(),
                body.documentDni(), body.nameLastname(), body.userId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("numVoucher", body.numVoucher());
        data.put("filasAfectadas", filas);
        return ApiResponse.ok(data, "Voucher registrado");
    }

    /** Actualiza un voucher existente; 404 si el num_voucher no existe. */
    @PutMapping("/{numVoucher}")
    public ApiResponse<Map<String, Object>> actualizar(@PathVariable String numVoucher,
                                                       @RequestBody VoucherRequest body) {
        int filas = repo().actualizarVoucher(
                numVoucher, body.numAccount(), body.numCheck(), body.bank(),
                body.dateEntry(), body.amount(), body.details(),
                body.documentDni(), body.nameLastname());
        if (filas == 0) {
            throw new NotFoundException(
                    "No existe voucher " + numVoucher + " en FinantialTracker");
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("numVoucher", numVoucher);
        data.put("filasAfectadas", filas);
        return ApiResponse.ok(data, "Voucher actualizado");
    }

    /** Reserva el siguiente correlativo "001-NNNNNN" en voucher_temp. */
    @PostMapping("/reservar")
    public ApiResponse<Map<String, Object>> reservar() {
        String numVoucher = repo().reservarVoucher();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("numVoucher", numVoucher);
        return ApiResponse.ok(data, "Numero de voucher reservado");
    }

    /** Borra las reservas PENDING de voucher_temp (limpieza de no usados). */
    @DeleteMapping("/temp-pendientes")
    public ApiResponse<Map<String, Object>> limpiarPendientes() {
        int eliminados = repo().borrarTempPendientes();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("eliminados", eliminados);
        return ApiResponse.ok(data, "Reservas pendientes eliminadas");
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FtVouchersRepository repo() {
        FtVouchersRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }
}
