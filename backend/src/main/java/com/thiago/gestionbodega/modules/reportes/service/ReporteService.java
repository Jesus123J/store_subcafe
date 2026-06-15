package com.thiago.gestionbodega.modules.reportes.service;

import com.thiago.gestionbodega.modules.reportes.dto.*;
import com.thiago.gestionbodega.modules.reportes.repository.ReporteRepository;
import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Date;
import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReporteService {

    private final ReporteRepository repo;

    public VentasDiariasDto ventasDiarias(LocalDate desde, LocalDate hasta) {
        BigDecimal total = repo.totalVentasEnRango(desde, hasta);
        long cantidad = repo.cantidadTransacciones(desde, hasta);
        BigDecimal ticket = cantidad == 0
                ? BigDecimal.ZERO
                : total.divide(BigDecimal.valueOf(cantidad), 2, RoundingMode.HALF_UP);

        // Inicializar todas las formas de pago en 0 para que el grafico siempre
        // las muestre aunque no haya datos
        Map<String, BigDecimal> porForma = new LinkedHashMap<>();
        for (FormaPago f : FormaPago.values()) {
            porForma.put(f.name(), BigDecimal.ZERO);
        }
        porForma.putAll(repo.totalPorFormaPago(desde, hasta));

        Map<String, BigDecimal> porTurno = new LinkedHashMap<>();
        porTurno.put("DIA", BigDecimal.ZERO);
        porTurno.put("NOCHE", BigDecimal.ZERO);
        porTurno.putAll(repo.totalPorTurno(desde, hasta));

        List<VentasDiariasDto.SerieDiariaDto> serie = repo.serieDiaria(desde, hasta)
                .stream()
                .map(row -> new VentasDiariasDto.SerieDiariaDto(
                        ((Date) row.get("dia")).toLocalDate(),
                        (BigDecimal) row.get("total")))
                .toList();

        return VentasDiariasDto.builder()
                .desde(desde)
                .hasta(hasta)
                .totalGeneral(total)
                .cantidadTransacciones(cantidad)
                .ticketPromedio(ticket)
                .porFormaPago(porForma)
                .porTurno(porTurno)
                .serieDiaria(serie)
                .build();
    }

    public List<StockProductoDto> stockActual() {
        return repo.stockActual().stream().map(this::toStockDto).toList();
    }

    public List<StockProductoDto> stockBajo() {
        return repo.stockBajo().stream().map(this::toStockDto).toList();
    }

    public List<TopProductoDto> topProductos(LocalDate desde, LocalDate hasta, int limit) {
        return repo.topProductos(desde, hasta, limit).stream()
                .map(row -> TopProductoDto.builder()
                        .productoId((UUID) row.get("producto_id"))
                        .descripcion((String) row.get("descripcion"))
                        .cantidadVendida((BigDecimal) row.get("cantidad_vendida"))
                        .totalFacturado((BigDecimal) row.get("total_facturado"))
                        .build())
                .toList();
    }

    private StockProductoDto toStockDto(Map<String, Object> row) {
        return StockProductoDto.builder()
                .id((UUID) row.get("id"))
                .codigo((String) row.get("codigo"))
                .descripcion((String) row.get("descripcion"))
                .stock((BigDecimal) row.get("stock"))
                .stockMinimo((BigDecimal) row.get("stock_minimo"))
                .costo((BigDecimal) row.get("costo"))
                .precioVenta((BigDecimal) row.get("precio_venta"))
                .valoracion((BigDecimal) row.get("valoracion"))
                .bajoMinimo(Boolean.TRUE.equals(row.get("bajo_minimo")))
                .build();
    }
}
