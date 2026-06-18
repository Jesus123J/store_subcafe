package com.thiago.gestionbodega.modules.proveedores.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.proveedores.dto.ActualizarProveedorRequest;
import com.thiago.gestionbodega.modules.proveedores.dto.CrearProveedorRequest;
import com.thiago.gestionbodega.modules.proveedores.dto.ProveedorDto;
import com.thiago.gestionbodega.modules.proveedores.entity.Proveedor;
import com.thiago.gestionbodega.modules.proveedores.repository.ProveedorRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProveedorService {

    private final ProveedorRepository repo;

    public List<ProveedorDto> listar() {
        return repo.findAll().stream().map(ProveedorDto::from).toList();
    }

    public ProveedorDto obtener(UUID id) {
        return ProveedorDto.from(buscar(id));
    }

    @Transactional
    public ProveedorDto crear(CrearProveedorRequest req) {
        repo.findByRuc(req.ruc()).ifPresent(p -> {
            throw new BusinessException("Ya existe un proveedor con RUC: " + req.ruc());
        });

        Proveedor p = Proveedor.builder()
                .razonSocial(req.razonSocial().trim())
                .ruc(req.ruc())
                .direccion(blankToNull(req.direccion()))
                .telefono(blankToNull(req.telefono()))
                .activo(true)
                .build();
        p = repo.save(p);

        log.info("Proveedor creado: {} (RUC {})", p.getRazonSocial(), p.getRuc());
        return ProveedorDto.from(p);
    }

    /**
     * Actualiza razon social, direccion, telefono, activo. El RUC NO se cambia
     * (es la clave fiscal del proveedor).
     */
    @Transactional
    public ProveedorDto actualizar(UUID id, ActualizarProveedorRequest req) {
        Proveedor p = buscar(id);
        p.setRazonSocial(req.razonSocial().trim());
        p.setDireccion(blankToNull(req.direccion()));
        p.setTelefono(blankToNull(req.telefono()));
        p.setActivo(req.activo());
        p = repo.save(p);
        log.info("Proveedor actualizado: {}", p.getRazonSocial());
        return ProveedorDto.from(p);
    }

    /**
     * Borrado logico: activo=false. Preservamos referencias historicas en compras.
     */
    @Transactional
    public void desactivar(UUID id) {
        Proveedor p = buscar(id);
        p.setActivo(false);
        repo.save(p);
        log.info("Proveedor desactivado: {}", p.getRazonSocial());
    }

    private Proveedor buscar(UUID id) {
        return repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Proveedor no encontrado: " + id));
    }

    private static String blankToNull(String s) {
        if (s == null) return null;
        s = s.trim();
        return s.isEmpty() ? null : s;
    }
}
