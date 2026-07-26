package com.thiago.gestionbodega.modules.integracion.ft;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Log de consumo de la integracion con FinantialTracker: registra cada
 * request a /api/integracion/ft/** y /api/trabajadores con metodo, ruta,
 * status y duracion. Sirve para auditar que el escritorio Swing (u otro
 * cliente) esta consumiendo la API y cuanto tarda cada operacion.
 *
 * Ejemplo de linea:
 *   FT-API GET /api/integracion/ft/prestamos -> 200 (34 ms)
 */
@Component
public class FtRequestLogFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger("integracion.ft.requests");

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return !(path.startsWith("/api/integracion/ft") || path.startsWith("/api/trabajadores"));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        long inicio = System.currentTimeMillis();
        try {
            filterChain.doFilter(request, response);
        } finally {
            String query = request.getQueryString();
            log.info("FT-API {} {}{} -> {} ({} ms)",
                    request.getMethod(),
                    request.getRequestURI(),
                    query == null ? "" : "?" + query,
                    response.getStatus(),
                    System.currentTimeMillis() - inicio);
        }
    }
}
