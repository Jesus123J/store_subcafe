package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.GuardarProveedorRequest;
import com.thiago.gestionbodega.dto.ProveedorDto;
import com.thiago.gestionbodega.entity.Proveedor;
import com.thiago.gestionbodega.exception.BusinessException;
import com.thiago.gestionbodega.exception.NotFoundException;
import com.thiago.gestionbodega.repository.ProveedorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProveedorService {

    private final ProveedorRepository repo;

    public List<ProveedorDto> listar() {
        return repo.findAll().stream()
                .sorted(Comparator.comparing(Proveedor::getRazonSocial, String.CASE_INSENSITIVE_ORDER))
                .map(ProveedorDto::from).toList();
    }

    @Transactional
    public ProveedorDto crear(GuardarProveedorRequest req) {
        if (repo.findByRuc(req.ruc()).isPresent()) {
            throw new BusinessException("Ya existe un proveedor con RUC " + req.ruc());
        }
        Proveedor p = Proveedor.builder()
                .razonSocial(req.razonSocial().trim())
                .ruc(req.ruc())
                .direccion(blankToNull(req.direccion()))
                .telefono(blankToNull(req.telefono()))
                .activo(req.activo() == null || req.activo())
                .build();
        return ProveedorDto.from(repo.save(p));
    }

    @Transactional
    public ProveedorDto actualizar(UUID id, GuardarProveedorRequest req) {
        Proveedor p = repo.findById(id).orElseThrow(() -> new NotFoundException("Proveedor no encontrado"));
        repo.findByRuc(req.ruc()).filter(o -> !o.getId().equals(id)).ifPresent(o -> {
            throw new BusinessException("Ya existe otro proveedor con RUC " + req.ruc());
        });
        p.setRazonSocial(req.razonSocial().trim());
        p.setRuc(req.ruc());
        p.setDireccion(blankToNull(req.direccion()));
        p.setTelefono(blankToNull(req.telefono()));
        if (req.activo() != null) p.setActivo(req.activo());
        return ProveedorDto.from(repo.save(p));
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
