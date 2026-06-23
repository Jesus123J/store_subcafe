package com.thiago.gestionbodega.modules.ventas.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record CrearVentaRequest(
        @NotEmpty @Valid List<VentaDetalleRequest> items,
        @NotEmpty @Valid List<VentaPagoRequest> pagos
) {}
