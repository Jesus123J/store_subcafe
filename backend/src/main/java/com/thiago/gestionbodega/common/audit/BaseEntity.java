package com.thiago.gestionbodega.common.audit;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Base de las entidades: id UUID + auditoria automatica.
 *
 * En MySQL/MariaDB el UUID se guarda como CHAR(36). Usamos {@link SqlTypes#CHAR}
 * para forzar a Hibernate a almacenarlo como string y que coincida con la
 * columna {@code CHAR(36)} definida en las migraciones.
 */
@Getter
@Setter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @Id
    @GeneratedValue
    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "id", updatable = false, nullable = false, length = 36)
    private UUID id;

    @CreatedDate
    @Column(name = "creado_en", nullable = false, updatable = false)
    private OffsetDateTime creadoEn;

    @LastModifiedDate
    @Column(name = "actualizado_en")
    private OffsetDateTime actualizadoEn;
}
