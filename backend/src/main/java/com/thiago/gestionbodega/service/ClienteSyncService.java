package com.thiago.gestionbodega.service;

import com.thiago.gestionbodega.dto.ImportResultDto;
import com.thiago.gestionbodega.entity.Cliente;
import com.thiago.gestionbodega.repository.ClienteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;

/**
 * Sincroniza el padron de trabajadores de FinantialTracker (tabla
 * {@code employees}, misma base de datos) hacia {@code clientes}.
 *
 * Reglas:
 *  - Enlace principal por {@code empleado_id}; si no existe, por DNI
 *    (clientes creados a mano antes de la sincronizacion).
 *  - Nunca borra clientes. Si un empleado desaparece de employees, el
 *    cliente queda tal cual (sus vales/puntos siguen siendo validos).
 *  - Los datos de la tienda que no vienen de FT (telefono, activo) se
 *    conservan.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ClienteSyncService {

    /** Particulas que forman parte de un apellido compuesto (DEL POZO, DE LA CRUZ, ...). */
    private static final Set<String> PARTICULAS = Set.of(
            "DE", "DEL", "LA", "LAS", "LOS", "Y", "SAN", "SANTA", "DA", "DI", "VAN", "VON", "VDA");

    private final NamedParameterJdbcTemplate jdbc;
    private final ClienteRepository clienteRepo;

    public List<Map<String, Object>> listarEmpleados(boolean soloPendientes) {
        String sql = """
                SELECT empleado_id, dni, nombre_completo, condicion_laboral,
                       fecha_ingreso, cliente_id, sincronizado
                FROM v_empleados_finantial
                """ + (soloPendientes ? "WHERE sincronizado = 0\n" : "") + """
                ORDER BY nombre_completo
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }

    public Map<String, Object> resumen() {
        Long empleados = jdbc.queryForObject(
                "SELECT COUNT(*) FROM employees", new MapSqlParameterSource(), Long.class);
        Long sincronizados = jdbc.queryForObject(
                "SELECT COUNT(*) FROM v_empleados_finantial WHERE sincronizado = 1",
                new MapSqlParameterSource(), Long.class);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("empleadosFinantial", empleados);
        out.put("sincronizados", sincronizados);
        out.put("pendientes", (empleados == null ? 0 : empleados) - (sincronizados == null ? 0 : sincronizados));
        out.put("clientesManuales", clienteRepo.countByOrigen("MANUAL"));
        out.put("clientesTotal", clienteRepo.count());
        return out;
    }

    @Transactional
    public ImportResultDto sincronizarDesdeFinantial() {
        List<Map<String, Object>> empleados = jdbc.queryForList("""
                SELECT employee_id, fullName, national_id, employment_status
                FROM employees
                ORDER BY employee_id
                """, new MapSqlParameterSource());

        int creados = 0, actualizados = 0, errores = 0;
        List<String> mensajes = new ArrayList<>();
        OffsetDateTime ahora = OffsetDateTime.now();

        for (Map<String, Object> e : empleados) {
            Integer empleadoId = ((Number) e.get("employee_id")).intValue();
            String dni = Objects.toString(e.get("national_id"), "").trim();
            String fullName = Objects.toString(e.get("fullName"), "").trim();
            String condicion = Objects.toString(e.get("employment_status"), "").trim();
            try {
                if (dni.isEmpty() || fullName.isEmpty()) {
                    errores++;
                    mensajes.add("Empleado " + empleadoId + ": DNI o nombre vacio");
                    continue;
                }
                String[] partes = separarNombre(fullName);   // [apellidos, nombres]

                Cliente c = clienteRepo.findByEmpleadoId(empleadoId)
                        .or(() -> clienteRepo.findByDni(dni))
                        .orElse(null);
                boolean nuevo = (c == null);
                if (nuevo) {
                    c = Cliente.builder().activo(true).build();
                }
                c.setEmpleadoId(empleadoId);
                c.setDni(dni);
                c.setApellidos(partes[0]);
                c.setNombres(partes[1]);
                c.setNombreOriginal(fullName);
                c.setCondicionLaboral(condicion.isEmpty() ? null : condicion);
                c.setEsTrabajador(true);
                c.setOrigen("FINANTIAL");
                c.setSincronizadoEn(ahora);
                clienteRepo.save(c);
                if (nuevo) creados++; else actualizados++;
            } catch (Exception ex) {
                errores++;
                mensajes.add("Empleado " + empleadoId + " (" + dni + "): " + ex.getMessage());
            }
        }

        log.info("Sincronizacion FinantialTracker -> clientes: {} creados, {} actualizados, {} errores",
                creados, actualizados, errores);

        return ImportResultDto.builder()
                .total(empleados.size())
                .creados(creados)
                .actualizados(actualizados)
                .errores(errores)
                .mensajesError(mensajes)
                .build();
    }

    /**
     * Separa "APELLIDO_PATERNO APELLIDO_MATERNO NOMBRES..." en [apellidos, nombres].
     * Maneja apellidos compuestos con particulas (ACOSTA DEL POZO ERICK) y el
     * apellido de casada (BENAVENTE MONTORO DE RETO ZOILA). El nombre original
     * se conserva en {@code nombre_original} por si la heuristica se equivoca.
     */
    static String[] separarNombre(String fullName) {
        List<String> t = new ArrayList<>(Arrays.asList(fullName.trim().split("\\s+")));
        if (t.size() <= 1) return new String[]{fullName.trim(), ""};
        if (t.size() == 2) return new String[]{t.get(0), t.get(1)};

        int i = 0;
        // dos "unidades" de apellido (una unidad = particulas opcionales + palabra)
        for (int unidad = 0; unidad < 2 && i < t.size() - 1; unidad++) {
            while (i < t.size() - 1 && PARTICULAS.contains(t.get(i))) i++;
            i++;
        }
        // apellido de casada: "... DE <APELLIDO>" justo despues de los dos apellidos
        if (i < t.size() - 1 && (t.get(i).equals("DE") || t.get(i).equals("VDA"))) {
            int j = i;
            while (j < t.size() - 1 && PARTICULAS.contains(t.get(j))) j++;
            if (j < t.size() - 1) i = j + 1;
        }
        String apellidos = String.join(" ", t.subList(0, i));
        String nombres = String.join(" ", t.subList(i, t.size()));
        return new String[]{apellidos, nombres};
    }
}
