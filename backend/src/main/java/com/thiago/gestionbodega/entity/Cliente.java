package com.thiago.gestionbodega.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "clientes")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Cliente extends BaseEntity {

    /** DNI (8 digitos) o carnet de extranjeria (9). Mismo largo que employees.national_id. */
    @Column(name = "dni", unique = true, nullable = false, length = 15)
    private String dni;

    @Column(name = "nombres", nullable = false, length = 150)
    private String nombres;

    @Column(name = "apellidos", nullable = false, length = 150)
    private String apellidos;

    @Column(name = "telefono", length = 20)
    private String telefono;

    @Column(name = "es_trabajador", nullable = false)
    private boolean esTrabajador;

    @Column(name = "activo", nullable = false)
    private boolean activo;

    // ─── Enlace con FinantialTracker (tabla employees, misma BD) ───

    /** employees.employee_id. NULL si el cliente se creo a mano en la tienda. */
    @Column(name = "empleado_id", unique = true)
    private Integer empleadoId;

    /** employees.fullName sin transformar (formato APELLIDOS NOMBRES). */
    @Column(name = "nombre_original", length = 200)
    private String nombreOriginal;

    /** Nombrado | CAS. */
    @Column(name = "condicion_laboral", length = 20)
    private String condicionLaboral;

    /** MANUAL | FINANTIAL. */
    @Column(name = "origen", nullable = false, length = 20)
    @Builder.Default
    private String origen = "MANUAL";

    @Column(name = "sincronizado_en")
    private OffsetDateTime sincronizadoEn;

    public String getNombreCompleto() {
        return nombres + " " + apellidos;
    }
}
