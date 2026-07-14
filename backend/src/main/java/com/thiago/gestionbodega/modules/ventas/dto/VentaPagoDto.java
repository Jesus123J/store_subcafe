package com.thiago.gestionbodega.modules.ventas.dto;

import com.thiago.gestionbodega.modules.ventas.entity.FormaPago;
import com.thiago.gestionbodega.modules.ventas.entity.VentaPago;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Pago parcial de una venta. Cuando forma_pago = CREDITO,
 * trabajadorCreditoDni identifica al trabajador en FinantialTracker.
 */
@Builder
public record VentaPagoDto(
        UUID id,
        @NotNull FormaPago formaPago,
        @NotNull @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0") BigDecimal monto,
        String codigoOperacion,
        String trabajadorCreditoDni,
        Integer orden
) {

    public static VentaPagoDto from(VentaPago p) {
        return VentaPagoDto.builder()
                .id(p.getId())
                .formaPago(p.getFormaPago())
                .monto(p.getMonto())
                .codigoOperacion(p.getCodigoOperacion())
                .trabajadorCreditoDni(p.getTrabajadorCreditoDni())
                .orden(p.getOrden())
                .build();
    }
}
