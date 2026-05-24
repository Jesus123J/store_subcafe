package com.thiago.gestionbodega.modules.usuarios.service;

import com.thiago.gestionbodega.common.exception.BusinessException;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import com.thiago.gestionbodega.modules.usuarios.dto.ActualizarUsuarioRequest;
import com.thiago.gestionbodega.modules.usuarios.dto.CrearUsuarioRequest;
import com.thiago.gestionbodega.modules.usuarios.dto.UsuarioDto;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UsuarioService {

    private final UsuarioRepository repository;
    private final PasswordEncoder passwordEncoder;

    public List<UsuarioDto> listar() {
        return repository.findAll().stream().map(UsuarioDto::from).toList();
    }

    public UsuarioDto obtener(UUID id) {
        return UsuarioDto.from(getOrThrow(id));
    }

    @Transactional
    public UsuarioDto crear(CrearUsuarioRequest req) {
        if (repository.existsByUsername(req.username())) {
            throw new BusinessException("Ya existe un usuario con username: " + req.username());
        }
        Usuario u = Usuario.builder()
                .username(req.username())
                .passwordHash(passwordEncoder.encode(req.password()))
                .nombreCompleto(req.nombreCompleto())
                .rol(req.rol())
                .activo(true)
                .build();
        return UsuarioDto.from(repository.save(u));
    }

    @Transactional
    public UsuarioDto actualizar(UUID id, ActualizarUsuarioRequest req) {
        Usuario u = getOrThrow(id);
        u.setNombreCompleto(req.nombreCompleto());
        u.setRol(req.rol());
        u.setActivo(req.activo());
        return UsuarioDto.from(repository.save(u));
    }

    @Transactional
    public void eliminar(UUID id) {
        Usuario u = getOrThrow(id);
        u.setActivo(false);            // soft delete
        repository.save(u);
    }

    private Usuario getOrThrow(UUID id) {
        return repository.findById(id)
                .orElseThrow(() -> new NotFoundException("Usuario no encontrado: " + id));
    }
}
