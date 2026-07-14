package com.thiago.gestionbodega.modules.integracion.ft;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Passthrough puro a la tabla employees de FinantialTracker.
 *
 * La bodega NO tiene tabla local de trabajadores. Cuando el frontend
 * necesita la lista, este endpoint la lee directo de FT en vivo. Sin
 * conexion a FT -> 503 con mensaje claro.
 *
 * Devuelve solo dni + nombreCompleto — nada mas (no cargo, no estado
 * de empleo, no fecha de ingreso: eso vive en FT y no nos importa aca).
 */
@Tag(name = "Trabajadores",
     description = "Lectura passthrough desde FinantialTracker.employees")
@RestController
@RequestMapping("/trabajadores")
@RequiredArgsConstructor
public class TrabajadoresController {

    private final ObjectProvider<FinancialTrackerRepository> ftRepoProvider;

    @GetMapping
    public ApiResponse<List<Map<String, Object>>> listar() {
        FinancialTrackerRepository ftRepo = ftRepoProvider.getIfAvailable();
        if (ftRepo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada. "
                    + "La lista de trabajadores requiere conexion al sistema de planilla.");
        }
        return ApiResponse.ok(ftRepo.listarEmpleados());
    }
}
