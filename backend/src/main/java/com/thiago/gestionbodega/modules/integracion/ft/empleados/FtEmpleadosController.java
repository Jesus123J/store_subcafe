package com.thiago.gestionbodega.modules.integracion.ft.empleados;

import com.thiago.gestionbodega.common.dto.ApiResponse;
import com.thiago.gestionbodega.common.exception.NotFoundException;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.sql.SQLException;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * CRUD completo de empleados y usuarios de la BD financialtracker1,
 * espejo 1:1 del EmployeeDao y el UserDao de la app Swing FinantialTracker.
 *
 * Rutas:
 *  - /integracion/ft/empleados-full/** (espejo de EmployeeDao) — con sufijo
 *    "-full" para NO chocar con las de solo lectura ya existentes en
 *    FtConsultaController (/integracion/ft/empleados y
 *    /integracion/ft/empleados/{dni}).
 *  - /integracion/ft/usuarios/** (espejo de UserDao).
 *
 * Contrasenas: el UserDao original usa org.mindrot.jbcrypt (BCrypt $2a$).
 * Aqui se usa org.springframework.security.crypto.bcrypt.BCrypt, que es
 * compatible binariamente con esos hashes (checkpw/hashpw/gensalt(12)).
 *
 * Si la integracion esta desactivada (integracion.financialtracker.enabled=false)
 * los endpoints responden con error claro (IllegalStateException).
 */
@Tag(name = "Empleados FinantialTracker",
     description = "CRUD de empleados y usuarios de la planilla del HSJ "
             + "(espejo del EmployeeDao y UserDao Swing)")
@RestController
@RequestMapping("/integracion/ft")
@RequiredArgsConstructor
public class FtEmpleadosController {

    private final ObjectProvider<FtEmpleadosRepository> repoProvider;

    // ─── Empleados: lecturas ───────────────────────────────────────────

    /** EmployeeDao.findAll(): lista completa (sin super admins). */
    @GetMapping("/empleados-full")
    public ApiResponse<List<Map<String, Object>>> listar() {
        return ApiResponse.ok(repo().listarTodos());
    }

    /** EmployeeDao.findById(Integer). */
    @GetMapping("/empleados-full/por-id/{id}")
    public ApiResponse<Map<String, Object>> porId(@PathVariable int id) {
        return ApiResponse.ok(repo().buscarPorId(id)
                .orElseThrow(() -> new NotFoundException(
                        "No existe empleado con id " + id + " en FinantialTracker")));
    }

    /** EmployeeDao.findById(String dni). */
    @GetMapping("/empleados-full/por-dni/{dni}")
    public ApiResponse<Map<String, Object>> porDni(@PathVariable String dni) {
        return ApiResponse.ok(repo().buscarPorDni(dni)
                .orElseThrow(() -> new NotFoundException(
                        "No existe empleado con DNI " + dni + " en FinantialTracker")));
    }

    /** EmployeeDao.findEmployeesByFullName(). */
    @GetMapping("/empleados-full/buscar")
    public ApiResponse<List<Map<String, Object>>> buscar(@RequestParam String nombre) {
        return ApiResponse.ok(repo().buscarPorNombre(nombre));
    }

    /** EmployeeDao.getEmployeesByDateRange(). Fechas ISO yyyy-MM-dd. */
    @GetMapping("/empleados-full/rango")
    public ApiResponse<List<Map<String, Object>>> rango(@RequestParam String inicio,
                                                        @RequestParam String fin) {
        return ApiResponse.ok(repo().listarPorRango(
                LocalDate.parse(inicio), LocalDate.parse(fin)));
    }

    /** EmployeeDao.getLastEmployees() — offset para scroll infinito. */
    @GetMapping("/empleados-full/ultimos")
    public ApiResponse<List<Map<String, Object>>> ultimos(
            @RequestParam(defaultValue = "10") int limite,
            @RequestParam(defaultValue = "0") int offset) {
        return ApiResponse.ok(repo().listarUltimos(
                Math.min(Math.max(limite, 1), 500), Math.max(offset, 0)));
    }

    /** EmployeeDao.getAllEmployeeDniNames(): pares {dni, nombre}. */
    @GetMapping("/empleados-full/dni-nombres")
    public ApiResponse<List<Map<String, Object>>> dniNombres() {
        return ApiResponse.ok(repo().listarDniNombres());
    }

    // ─── Empleados: escrituras ─────────────────────────────────────────

    /**
     * EmployeeDao.create(). Body: fullName, nationalId, gender,
     * employmentStatus, employmentStatusCode, startDate (yyyy-MM-dd).
     * Devuelve {id} generado.
     */
    @PostMapping("/empleados-full")
    public ApiResponse<Map<String, Object>> crear(@RequestBody Map<String, Object> body) {
        int id = repo().crear(
                texto(body, "fullName"),
                texto(body, "nationalId"),
                texto(body, "gender"),
                texto(body, "employmentStatus"),
                texto(body, "employmentStatusCode"),
                LocalDate.parse(texto(body, "startDate")));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("id", id);
        return ApiResponse.ok(data, "Empleado creado");
    }

    /**
     * EmployeeDao.updateEmploymentStatusByDNI(). Body: {estado}.
     * Devuelve {actualizado} — false si el DNI no existe (sin 404, igual
     * que el original que solo mira filas afectadas).
     */
    @PutMapping("/empleados-full/{dni}/estado")
    public ApiResponse<Map<String, Object>> actualizarEstado(@PathVariable String dni,
                                                             @RequestBody Map<String, Object> body) {
        boolean actualizado = repo().actualizarEstadoPorDni(dni, texto(body, "estado"));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("actualizado", actualizado);
        return ApiResponse.ok(data);
    }

    /**
     * EmployeeDao.updateEmployee(). Body: nuevoDni, fullName, gender,
     * employmentStatus, startDate (yyyy-MM-dd). Transaccional: si cambia el
     * DNI tambien actualiza loan.EmployeeID y loan.GuarantorId.
     */
    @PutMapping("/empleados-full/{dni}")
    public ApiResponse<Map<String, Object>> actualizar(@PathVariable String dni,
                                                       @RequestBody Map<String, Object> body) {
        try {
            repo().actualizarEmpleado(
                    dni,
                    texto(body, "nuevoDni"),
                    texto(body, "fullName"),
                    texto(body, "gender"),
                    texto(body, "employmentStatus"),
                    LocalDate.parse(texto(body, "startDate")));
        } catch (SQLException e) {
            throw new IllegalStateException("Error al actualizar el empleado: " + e.getMessage(), e);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("actualizado", true);
        return ApiResponse.ok(data, "Empleado actualizado");
    }

    /**
     * EmployeeDao.deleteEmployeeIfNotUsed(): elimina solo si el empleado no
     * tiene prestamos, abonos ni usuarios asociados. Nunca responde 404:
     * devuelve {eliminado, motivo} para que el cliente Swing muestre los
     * mismos dialogos que el DAO original.
     * motivo: NO_ENCONTRADO | EN_USO | null.
     */
    @DeleteMapping("/empleados-full/{dni}")
    public ApiResponse<Map<String, Object>> eliminar(@PathVariable String dni) {
        FtEmpleadosRepository repo = repo();
        Map<String, Object> data = new LinkedHashMap<>();

        Optional<Integer> idOpt = repo.buscarIdPorDni(dni);
        if (idOpt.isEmpty()) {
            data.put("eliminado", false);
            data.put("motivo", "NO_ENCONTRADO");
            return ApiResponse.ok(data);
        }

        int employeeId = idOpt.get();
        boolean sinUsos = repo.contarPrestamosPorDni(dni) == 0
                && repo.contarAbonosPorEmployeeId(employeeId) == 0
                && repo.contarUsuariosPorDni(dni) == 0;
        if (!sinUsos) {
            data.put("eliminado", false);
            data.put("motivo", "EN_USO");
            return ApiResponse.ok(data);
        }

        data.put("eliminado", repo.eliminarPorId(employeeId));
        return ApiResponse.ok(data);
    }

    // ─── Usuarios (espejo de UserDao) ──────────────────────────────────

    /** UserDao.getAllUsers(): usuarios con el nombre del empleado asociado. */
    @GetMapping("/usuarios")
    public ApiResponse<List<Map<String, Object>>> listarUsuarios() {
        return ApiResponse.ok(repo().listarUsuarios());
    }

    /** UserDao.isUsernameTaken(). Devuelve {existe}. */
    @GetMapping("/usuarios/{username}/existe")
    public ApiResponse<Map<String, Object>> existeUsuario(@PathVariable String username) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("existe", repo().existeUsername(username));
        return ApiResponse.ok(data);
    }

    /**
     * UserDao.getUserByUsername(username, password): login. Body:
     * {username, password}. Verifica la contrasena contra el hash BCrypt
     * almacenado (compatible con jbcrypt). Nunca responde 404 ni 401 de
     * negocio: {autenticado:false} tanto si el usuario no existe como si
     * la contrasena no coincide (el DAO original devuelve null en ambos
     * casos), para no filtrar cual de los dos fallo.
     */
    @PostMapping("/usuarios/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody Map<String, Object> body) {
        String username = texto(body, "username");
        String password = texto(body, "password");

        Map<String, Object> data = new LinkedHashMap<>();
        Optional<Map<String, Object>> filaOpt = repo().buscarUsuarioPorUsername(username);
        if (filaOpt.isEmpty()) {
            data.put("autenticado", false);
            return ApiResponse.ok(data);
        }

        Map<String, Object> fila = filaOpt.get();
        String hash = fila.get("password") == null ? null : fila.get("password").toString();
        boolean ok = hash != null && password != null && BCrypt.checkpw(password, hash);
        if (!ok) {
            data.put("autenticado", false);
            return ApiResponse.ok(data);
        }

        Map<String, Object> usuario = new LinkedHashMap<>(fila);
        usuario.remove("password"); // jamas devolver el hash
        data.put("autenticado", true);
        data.put("usuario", usuario);
        return ApiResponse.ok(data);
    }

    /**
     * UserDao.createUser(username, password, idEmployee, state). Body:
     * {username, password, idEmployee, rol} — OJO: el parametro "state" del
     * DAO original en realidad se inserta en la columna rol; la columna
     * state siempre queda en '1'. La password se hashea aqui con BCrypt
     * gensalt(12), igual que el original. Devuelve {creado, motivo} con
     * motivo USERNAME_EN_USO cuando el nombre ya existe (sin 409, para que
     * el Swing muestre el mismo dialogo del DAO original).
     */
    @PostMapping("/usuarios")
    public ApiResponse<Map<String, Object>> crearUsuario(@RequestBody Map<String, Object> body) {
        FtEmpleadosRepository repo = repo();
        String username = texto(body, "username");

        Map<String, Object> data = new LinkedHashMap<>();
        if (repo.existeUsername(username)) {
            data.put("creado", false);
            data.put("motivo", "USERNAME_EN_USO");
            return ApiResponse.ok(data);
        }

        String hash = BCrypt.hashpw(texto(body, "password"), BCrypt.gensalt(12));
        int idEmployee = Integer.parseInt(texto(body, "idEmployee"));
        boolean creado = repo.crearUsuario(username, hash, idEmployee, texto(body, "rol"));
        data.put("creado", creado);
        return ApiResponse.ok(data, creado ? "Usuario creado" : "No se pudo crear el usuario");
    }

    /**
     * UserDao.toggleUserState(): alterna state 1 -> 0 / 0 -> 1. Sin body.
     * Devuelve {cambiado, motivo} con motivo SUPER_ADMIN (state 9, no se
     * toca) | NO_ENCONTRADO | SIN_CAMBIO | null, para que el Swing muestre
     * los mismos dialogos que el DAO original.
     */
    @PutMapping("/usuarios/{username}/toggle-estado")
    public ApiResponse<Map<String, Object>> toggleEstadoUsuario(@PathVariable String username) {
        FtEmpleadosRepository repo = repo();
        Map<String, Object> data = new LinkedHashMap<>();

        Optional<Integer> estadoOpt = repo.estadoUsuario(username);
        if (estadoOpt.isEmpty()) {
            data.put("cambiado", false);
            data.put("motivo", "NO_ENCONTRADO");
            return ApiResponse.ok(data);
        }
        int estado = estadoOpt.get();
        if (estado == 9) {
            data.put("cambiado", false);
            data.put("motivo", "SUPER_ADMIN");
            return ApiResponse.ok(data);
        }

        int nuevoEstado = (estado == 1) ? 0 : 1; // mismo toggle del original
        boolean cambiado = repo.actualizarEstadoUsuario(username, nuevoEstado);
        data.put("cambiado", cambiado);
        if (!cambiado) {
            data.put("motivo", "SIN_CAMBIO");
        }
        return ApiResponse.ok(data);
    }

    /**
     * UserDao.updateUserPassword(). Body: {password} (en claro; se hashea
     * aqui con BCrypt gensalt(12)). Devuelve {actualizado, motivo} con
     * motivo SUPER_ADMIN cuando state = 9 (protegido, igual que el
     * original); actualizado=false sin motivo si el username no existe.
     */
    @PutMapping("/usuarios/{username}/password")
    public ApiResponse<Map<String, Object>> actualizarPasswordUsuario(
            @PathVariable String username, @RequestBody Map<String, Object> body) {
        FtEmpleadosRepository repo = repo();
        Map<String, Object> data = new LinkedHashMap<>();

        Optional<Integer> estadoOpt = repo.estadoUsuario(username);
        if (estadoOpt.isPresent() && estadoOpt.get() == 9) {
            data.put("actualizado", false);
            data.put("motivo", "SUPER_ADMIN");
            return ApiResponse.ok(data);
        }

        String hash = BCrypt.hashpw(texto(body, "password"), BCrypt.gensalt(12));
        data.put("actualizado", repo.actualizarPasswordUsuario(username, hash));
        return ApiResponse.ok(data);
    }

    /**
     * UserDao.updateUserRole(). Body: {rol}. Devuelve {actualizado, motivo}
     * con motivo SUPER_ADMIN cuando state = 9 (protegido).
     */
    @PutMapping("/usuarios/{username}/rol")
    public ApiResponse<Map<String, Object>> actualizarRolUsuario(
            @PathVariable String username, @RequestBody Map<String, Object> body) {
        FtEmpleadosRepository repo = repo();
        Map<String, Object> data = new LinkedHashMap<>();

        Optional<Integer> estadoOpt = repo.estadoUsuario(username);
        if (estadoOpt.isPresent() && estadoOpt.get() == 9) {
            data.put("actualizado", false);
            data.put("motivo", "SUPER_ADMIN");
            return ApiResponse.ok(data);
        }

        data.put("actualizado", repo.actualizarRolUsuario(username, texto(body, "rol")));
        return ApiResponse.ok(data);
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    private FtEmpleadosRepository repo() {
        FtEmpleadosRepository repo = repoProvider.getIfAvailable();
        if (repo == null) {
            throw new IllegalStateException(
                    "Integracion con FinantialTracker desactivada "
                    + "(integracion.financialtracker.enabled=false)");
        }
        return repo;
    }

    private static String texto(Map<String, Object> body, String campo) {
        Object valor = body.get(campo);
        return valor == null ? null : valor.toString();
    }
}
