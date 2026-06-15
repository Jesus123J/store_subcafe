package com.thiago.gestionbodega.modules.compras.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record CrearCompraRequest(
        @NotNull UUID proveedorId,
        @Size(max = 50) String nroDocumento,
        String observaciones,
        @NotEmpty(message = "La compra debe tener al menos un item") @Valid List<CompraDetalleRequest> items
) {}
