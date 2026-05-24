package com.thiago.gestionbodega.modules.compras.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.compras.entity.Compra;
import com.thiago.gestionbodega.modules.compras.repository.CompraRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Compras")
@RestController
@RequestMapping("/compras")
@RequiredArgsConstructor
public class CompraController {

    private final CompraRepository repository;

    @GetMapping
    public ApiResponse<List<Compra>> listar() {
        return ApiResponse.ok(repository.findAll());
    }
}
