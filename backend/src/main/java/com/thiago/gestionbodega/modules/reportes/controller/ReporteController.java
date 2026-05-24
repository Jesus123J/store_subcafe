package com.thiago.gestionbodega.modules.reportes.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.Map;

@Tag(name = "Reportes")
@RestController
@RequestMapping("/reportes")
public class ReporteController {

    @GetMapping("/ventas-diarias")
    public ApiResponse<Map<String, Object>> ventasDiarias(
            @RequestParam(required = false) LocalDate fecha
    ) {
        // TODO: implementar query agregada por forma_pago y turno
        return ApiResponse.ok(Map.of(
                "fecha", fecha != null ? fecha : LocalDate.now(),
                "pendiente", "Implementacion en progreso"
        ));
    }

    @GetMapping("/stock")
    public ApiResponse<Map<String, Object>> stockActual() {
        // TODO: implementar reporte de stock con costo y precio
        return ApiResponse.ok(Map.of("pendiente", "Implementacion en progreso"));
    }
}
