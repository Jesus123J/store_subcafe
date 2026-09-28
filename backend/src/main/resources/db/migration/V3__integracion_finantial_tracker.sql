-- ============================================================
-- V3 — Integracion con FinantialTracker (misma base de datos)
-- ============================================================
-- La BD financialtracker1 contiene las tablas del sistema de prestamos
-- (employees, loan, abono, registro, service_concept, ...). La tienda usa
-- `employees` como padron de trabajadores: cada trabajador se refleja en
-- `clientes` (vales, puntos, credito) enlazado por `empleado_id`.
--
-- NO se crea FOREIGN KEY hacia `employees`: esa tabla la administra
-- FinantialTracker y sus respaldos hacen DROP TABLE + CREATE TABLE
-- (un FK desde la tienda romperia la restauracion).
-- ============================================================

-- 1) clientes: DNI de 8 digitos o carnet de extranjeria de 9 (FT usa VARCHAR(15))
ALTER TABLE clientes
    MODIFY dni VARCHAR(15) NOT NULL;

-- 2) clientes: enlace y datos que vienen de FinantialTracker
ALTER TABLE clientes
    ADD COLUMN empleado_id       INT          NULL     COMMENT 'employees.employee_id en FinantialTracker' AFTER activo,
    ADD COLUMN nombre_original   VARCHAR(200) NULL     COMMENT 'employees.fullName tal cual (APELLIDOS NOMBRES)' AFTER empleado_id,
    ADD COLUMN condicion_laboral VARCHAR(20)  NULL     COMMENT 'Nombrado | CAS (employees.employment_status)' AFTER nombre_original,
    ADD COLUMN origen            VARCHAR(20)  NOT NULL DEFAULT 'MANUAL' COMMENT 'MANUAL | FINANTIAL' AFTER condicion_laboral,
    ADD COLUMN sincronizado_en   TIMESTAMP(6) NULL     COMMENT 'Ultima sincronizacion desde employees' AFTER origen,
    ADD UNIQUE KEY uk_clientes_empleado (empleado_id),
    ADD CONSTRAINT chk_clientes_origen CHECK (origen IN ('MANUAL', 'FINANTIAL'));

-- 3) Vista de solo lectura sobre el padron de FinantialTracker, con el
--    estado de sincronizacion hacia `clientes`.
CREATE OR REPLACE VIEW v_empleados_finantial AS
SELECT e.employee_id                       AS empleado_id,
       e.national_id                       AS dni,
       e.fullName                          AS nombre_completo,
       e.employment_status                 AS condicion_laboral,
       e.employment_status_code            AS codigo_condicion,
       e.start_date                        AS fecha_ingreso,
       e.updated_at                        AS actualizado_en_finantial,
       c.id                                AS cliente_id,
       (c.id IS NOT NULL)                  AS sincronizado
FROM employees e
LEFT JOIN clientes c ON c.empleado_id = e.employee_id;
