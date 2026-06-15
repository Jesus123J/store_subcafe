package com.thiago.gestionbodega.modules.clientes.controller;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.clientes.dto.ClienteDto;
import com.thiago.gestionbodega.modules.clientes.dto.ImportResultDto;
import com.thiago.gestionbodega.modules.clientes.entity.Cliente;
import com.thiago.gestionbodega.modules.clientes.repository.ClienteRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Tag(name = "Clientes", description = "Trabajadores y clientes del negocio")
@RestController
@RequestMapping("/clientes")
@RequiredArgsConstructor
public class ClienteController {

    private final ClienteRepository repo;

    @GetMapping
    public ApiResponse<List<ClienteDto>> listar(@RequestParam(required = false) String q) {
        List<Cliente> data = (q == null || q.isBlank())
                ? repo.findAll()
                : repo.buscar(q.trim());
        return ApiResponse.ok(data.stream().map(ClienteDto::from).toList());
    }

    @GetMapping("/{id}")
    public ApiResponse<ClienteDto> obtener(@PathVariable UUID id) {
        Cliente c = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Cliente no encontrado"));
        return ApiResponse.ok(ClienteDto.from(c));
    }

    @PostMapping
    @Transactional
    public ResponseEntity<ApiResponse<ClienteDto>> crear(@Valid @RequestBody ClienteDto dto) {
        if (repo.existsByDni(dto.dni())) {
            throw new BusinessException("Ya existe un cliente con DNI: " + dto.dni());
        }
        Cliente c = Cliente.builder()
                .dni(dto.dni())
                .nombres(dto.nombres())
                .apellidos(dto.apellidos())
                .telefono(dto.telefono())
                .esTrabajador(dto.esTrabajador())
                .activo(true)
                .build();
        return ResponseEntity.status(201).body(
            ApiResponse.ok(ClienteDto.from(repo.save(c)), "Cliente creado"));
    }

    /**
     * Importacion masiva. Body: lista de clientes.
     * Idempotente: si el DNI ya existe, actualiza los datos.
     */
    @PostMapping("/import")
    @Transactional
    public ApiResponse<ImportResultDto> importar(@RequestBody List<ClienteDto> lista) {
        int creados = 0, actualizados = 0, errores = 0;
        List<String> mensajes = new ArrayList<>();

        for (int i = 0; i < lista.size(); i++) {
            ClienteDto dto = lista.get(i);
            try {
                if (dto.dni() == null || !dto.dni().matches("\\d{8}")) {
                    errores++;
                    mensajes.add("Fila " + (i + 1) + ": DNI invalido");
                    continue;
                }
                if (dto.nombres() == null || dto.nombres().isBlank()) {
                    errores++;
                    mensajes.add("Fila " + (i + 1) + ": nombres vacios");
                    continue;
                }
                Cliente existente = repo.findByDni(dto.dni()).orElse(null);
                if (existente != null) {
                    existente.setNombres(dto.nombres());
                    existente.setApellidos(dto.apellidos());
                    existente.setTelefono(dto.telefono());
                    existente.setEsTrabajador(dto.esTrabajador());
                    repo.save(existente);
                    actualizados++;
                } else {
                    repo.save(Cliente.builder()
                            .dni(dto.dni())
                            .nombres(dto.nombres())
                            .apellidos(dto.apellidos())
                            .telefono(dto.telefono())
                            .esTrabajador(dto.esTrabajador())
                            .activo(true)
                            .build());
                    creados++;
                }
            } catch (Exception e) {
                errores++;
                mensajes.add("Fila " + (i + 1) + ": " + e.getMessage());
            }
        }

        return ApiResponse.ok(ImportResultDto.builder()
                .total(lista.size())
                .creados(creados)
                .actualizados(actualizados)
                .errores(errores)
                .mensajesError(mensajes)
                .build());
    }
}
