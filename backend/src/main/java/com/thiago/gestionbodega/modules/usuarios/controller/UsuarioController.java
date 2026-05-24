package com.thiago.gestionbodega.modules.usuarios.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.usuarios.dto.ActualizarUsuarioRequest;
import com.thiago.gestionbodega.modules.usuarios.dto.CrearUsuarioRequest;
import com.thiago.gestionbodega.modules.usuarios.dto.UsuarioDto;
import com.thiago.gestionbodega.modules.usuarios.service.UsuarioService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "Usuarios", description = "Gestion de usuarios del sistema")
@RestController
@RequestMapping("/usuarios")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('ADMINISTRADOR', 'ENCARGADO')")
public class UsuarioController {

    private final UsuarioService service;

    @GetMapping
    public ApiResponse<List<UsuarioDto>> listar() {
        return ApiResponse.ok(service.listar());
    }

    @GetMapping("/{id}")
    public ApiResponse<UsuarioDto> obtener(@PathVariable UUID id) {
        return ApiResponse.ok(service.obtener(id));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public ResponseEntity<ApiResponse<UsuarioDto>> crear(@Valid @RequestBody CrearUsuarioRequest req) {
        UsuarioDto creado = service.crear(req);
        return ResponseEntity.status(201).body(ApiResponse.ok(creado, "Usuario creado"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public ApiResponse<UsuarioDto> actualizar(@PathVariable UUID id, @Valid @RequestBody ActualizarUsuarioRequest req) {
        return ApiResponse.ok(service.actualizar(id, req), "Usuario actualizado");
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMINISTRADOR')")
    public ApiResponse<Void> eliminar(@PathVariable UUID id) {
        service.eliminar(id);
        return ApiResponse.ok(null, "Usuario desactivado");
    }
}
