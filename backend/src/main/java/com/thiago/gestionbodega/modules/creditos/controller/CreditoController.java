package com.thiago.gestionbodega.modules.creditos.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.creditos.entity.CreditoTrabajador;
import com.thiago.gestionbodega.modules.creditos.repository.CreditoTrabajadorRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Creditos")
@RestController
@RequestMapping("/creditos")
@RequiredArgsConstructor
public class CreditoController {

    private final CreditoTrabajadorRepository repository;

    @GetMapping
    public ApiResponse<List<CreditoTrabajador>> listar() {
        return ApiResponse.ok(repository.findAll());
    }
}
