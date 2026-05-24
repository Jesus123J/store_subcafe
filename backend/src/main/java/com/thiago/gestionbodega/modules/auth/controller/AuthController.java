package com.thiago.gestionbodega.modules.auth.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.auth.dto.LoginRequest;
import com.thiago.gestionbodega.modules.auth.dto.LoginResponse;
import com.thiago.gestionbodega.modules.auth.service.AuthService;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Autenticacion", description = "Login y manejo de sesion")
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService service;

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return ApiResponse.ok(service.login(req), "Login exitoso");
    }
}
