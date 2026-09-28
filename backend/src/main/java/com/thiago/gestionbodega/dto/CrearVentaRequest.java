package com.thiago.gestionbodega.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

/**
 * Venta del POS. La suma de pagos debe coincidir con el total de los items.
 * Si algun pago es CREDITO, debe traer el clienteId de un TRABAJADOR
 * (cliente con es_trabajador = true): la deuda se registra a su nombre y
 * al cerrar el mes se exporta a FinantialTracker. Un cliente externo no
 * puede usar CREDITO: para el solo se registra la venta.
 */
public record CrearVentaRequest(
        @NotEmpty(message = "La venta debe tener al menos un item") @Valid List<VentaItemRequest> items,
        @NotEmpty(message = "La venta debe tener al menos un pago") @Valid List<VentaPagoDto> pagos,
        @Size(max = 300) String observacion,
        /** Trabajador identificado (opcional): acumula puntos. Si hay pago CREDITO y viene null, se usa ese trabajador. */
        UUID clienteId
) {}
