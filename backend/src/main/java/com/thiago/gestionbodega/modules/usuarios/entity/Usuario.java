package com.thiago.gestionbodega.modules.usuarios.entity;

import com.thiago.gestionbodega.common.audit.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "usuarios")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Usuario extends BaseEntity {

    @Column(name = "username", unique = true, nullable = false, length = 50)
    private String username;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "nombre_completo", nullable = false, length = 150)
    private String nombreCompleto;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "rol", nullable = false, columnDefinition = "rol_usuario")
    private RolUsuario rol;

    @Column(name = "activo", nullable = false)
    private boolean activo;
}
