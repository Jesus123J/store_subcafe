package com.thiago.gestionbodega.modules.integracion.ft;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.integracion.ft.dto.EnvioResultDto;
import com.thiago.gestionbodega.modules.integracion.ft.dto.EnvioResumenDto;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Endpoints para enviar la deuda mensual (o individual) desde la bodega
 * hacia FinantialTracker (planilla del HSJ).
 *
 * Si la integracion esta desactivada (integracion.financialtracker.enabled=false),
 * el {@link FinancialTrackerService} no se instancia y todos los endpoints
 * devuelven 503 Service Unavailable.
 */
@Tag(name = "Integracion FinantialTracker",
     description = "Push de deuda mensual a la planilla del HSJ")
@RestController
@RequestMapping("/integracion/ft")
@RequiredArgsConstructor
public class FinancialTrackerController {

    private final ObjectProvider<FinancialTrackerService> serviceProvider;

    @PostMapping("/enviar-cierre/{cierreId}")
    public ResponseEntity<ApiResponse<EnvioResultDto>> enviarCierre(
            @PathVariable UUID cierreId,
            @AuthenticationPrincipal String username) {
        FinancialTrackerService svc = requireEnabled();
        return ResponseEntity.status(201).body(
                ApiResponse.ok(svc.enviarCierre(cierreId, username),
                        "Cierre enviado a FinantialTracker"));
    }

    @PostMapping("/enviar-credito/{creditoId}")
    public ResponseEntity<ApiResponse<EnvioResultDto>> enviarCredito(
            @PathVariable UUID creditoId,
            @AuthenticationPrincipal String username) {
        FinancialTrackerService svc = requireEnabled();
        return ResponseEntity.status(201).body(
                ApiResponse.ok(svc.enviarCreditoIndividual(creditoId, username),
                        "Credito enviado a FinantialTracker"));
    }

    @PostMapping("/revertir/{envioId}")
    public ApiResponse<Void> revertir(
            @PathVariable UUID envioId,
            @RequestBody(required = false) Map<String, String> body,
            @AuthenticationPrincipal String username) {
        FinancialTrackerService svc = requireEnabled();
        String motivo = body != null ? body.get("motivo") : null;
        svc.revertirEnvio(envioId, username, motivo);
        return ApiResponse.ok(null, "Envio revertido");
    }

    @GetMapping("/envios")
    public ApiResponse<List<EnvioResumenDto>> historial() {
        return ApiResponse.ok(requireEnabled().historial());
    }

    /**
     * Sincroniza empleados de FT hacia clientes (bodega) como
     * trabajadores. Solo crea los DNI que no existen aun.
     */
    @PostMapping("/sync-empleados")
    public ApiResponse<Map<String, Integer>> sincronizarEmpleados() {
        return ApiResponse.ok(
                requireEnabled().sincronizarEmpleadosDesdeFt(),
                "Empleados sincronizados desde FinantialTracker");
    }

    @GetMapping("/health")
    public ApiResponse<Map<String, Object>> health() {
        FinancialTrackerService svc = serviceProvider.getIfAvailable();
        boolean enabled = svc != null;
        boolean db = enabled && svc.health();
        return ApiResponse.ok(Map.of(
                "enabled", enabled,
                "dbReachable", db
        ));
    }

    private FinancialTrackerService requireEnabled() {
        FinancialTrackerService svc = serviceProvider.getIfAvailable();
        if (svc == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return svc;
    }
}
