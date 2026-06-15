package com.thiago.gestionbodega.modules.reportes.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.reportes.dto.StockProductoDto;
import com.thiago.gestionbodega.modules.reportes.dto.TopProductoDto;
import com.thiago.gestionbodega.modules.reportes.dto.VentasDiariasDto;
import com.thiago.gestionbodega.modules.reportes.service.ReporteService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@Tag(name = "Reportes", description = "Dashboard de ventas, stock y top productos")
@RestController
@RequestMapping("/reportes")
@RequiredArgsConstructor
public class ReporteController {

    private final ReporteService service;

    /**
     * Reporte agregado de ventas en un rango de fechas (default: ultimos 7 dias).
     */
    @GetMapping("/ventas-diarias")
    public ApiResponse<VentasDiariasDto> ventasDiarias(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta
    ) {
        LocalDate fin = hasta != null ? hasta : LocalDate.now();
        LocalDate inicio = desde != null ? desde : fin.minusDays(6);
        return ApiResponse.ok(service.ventasDiarias(inicio, fin));
    }

    @GetMapping("/stock")
    public ApiResponse<List<StockProductoDto>> stock() {
        return ApiResponse.ok(service.stockActual());
    }

    @GetMapping("/stock-bajo")
    public ApiResponse<List<StockProductoDto>> stockBajo() {
        return ApiResponse.ok(service.stockBajo());
    }

    @GetMapping("/top-productos")
    public ApiResponse<List<TopProductoDto>> topProductos(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta,
            @RequestParam(defaultValue = "10") int limit
    ) {
        LocalDate fin = hasta != null ? hasta : LocalDate.now();
        LocalDate inicio = desde != null ? desde : fin.minusDays(29); // ultimos 30 dias por default
        return ApiResponse.ok(service.topProductos(inicio, fin, limit));
    }
}
