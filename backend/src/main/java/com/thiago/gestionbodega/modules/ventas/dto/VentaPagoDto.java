package com.thiago.gestionbodega.modules.ventas.dto;

import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import com.thiago.gestionbodega.modules.ventas.entity.VentaPago;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Representa un pago parcial de una venta. Una venta tiene una lista
 * de estos pagos cuya suma debe coincidir con el total.
 */
@Builder
public record VentaPagoDto(
        UUID id,
        @NotNull FormaPago formaPago,
        @NotNull @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0") BigDecimal monto,
        String codigoOperacion,
        UUID trabajadorCreditoId,
        Integer orden
) {

    public static VentaPagoDto from(VentaPago p) {
        return VentaPagoDto.builder()
                .id(p.getId())
                .formaPago(p.getFormaPago())
                .monto(p.getMonto())
                .codigoOperacion(p.getCodigoOperacion())
                .trabajadorCreditoId(p.getTrabajadorCredito() != null ? p.getTrabajadorCredito().getId() : null)
                .orden(p.getOrden())
                .build();
    }
}
