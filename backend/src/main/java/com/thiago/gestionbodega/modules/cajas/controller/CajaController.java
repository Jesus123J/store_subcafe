package com.thiago.gestionbodega.modules.cajas.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.modules.cajas.entity.Caja;
import com.thiago.gestionbodega.modules.cajas.repository.CajaRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Cajas")
@RestController
@RequestMapping("/cajas")
@RequiredArgsConstructor
public class CajaController {

    private final CajaRepository repository;

    @GetMapping
    public ApiResponse<List<Caja>> listar() {
        return ApiResponse.ok(repository.findAll());
    }
}
