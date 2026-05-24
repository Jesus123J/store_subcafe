package com.thiago.gestionbodega.modules.auth.service;

import com.thiago.gestionbodega.modules.auth.dto.LoginRequest;
import com.thiago.gestionbodega.modules.auth.dto.LoginResponse;
import com.thiago.gestionbodega.modules.usuarios.dto.UsuarioDto;
import com.thiago.gestionbodega.modules.usuarios.entity.Usuario;
import com.thiago.gestionbodega.modules.usuarios.repository.UsuarioRepository;
import com.thiago.gestionbodega.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;

    @Value("${app.jwt.expiration-ms}")
    private long jwtExpirationMs;

    public LoginResponse login(LoginRequest req) {
        Usuario user = usuarioRepository.findByUsername(req.username())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        if (!user.isActivo()) {
            throw new DisabledException("Usuario inactivo");
        }

        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new BadCredentialsException("Credenciales invalidas");
        }

        String token = tokenProvider.generateToken(
                user.getId(),
                user.getUsername(),
                user.getRol().name()
        );

        log.info("Login exitoso: {} ({})", user.getUsername(), user.getRol());

        return new LoginResponse(
                token,
                jwtExpirationMs / 1000,
                UsuarioDto.from(user)
        );
    }
}
