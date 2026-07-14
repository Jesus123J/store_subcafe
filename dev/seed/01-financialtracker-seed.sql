-- ============================================================
-- SEED de FinantialTracker (BD del hospital)
-- ============================================================
-- Corre esto en tu MariaDB local, base financialtracker1.
--
--   mysql -u root financialtracker1 < dev/seed/01-financialtracker-seed.sql
--
-- O pegalo directo en MySQL Workbench.
-- ============================================================

USE financialtracker1;

-- ------------------------------------------------------------
-- 1. Empleado de prueba con DNI 12345678
--    (debe coincidir con el cliente-trabajador de la bodega)
-- ------------------------------------------------------------
INSERT INTO employees (fullName, national_id, gender, employment_status,
                       employment_status_code, start_date)
SELECT 'JUAN PEREZ TEST', '12345678', 'HOMBRE', 'NOMBRADO', '2154', '2024-01-01'
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE national_id = '12345678');

-- ------------------------------------------------------------
-- 2. Segundo empleado para probar pago mixto
-- ------------------------------------------------------------
INSERT INTO employees (fullName, national_id, gender, employment_status,
                       employment_status_code, start_date)
SELECT 'MARIA GARCIA TEST', '87654321', 'MUJER', 'CAS', '2028', '2024-03-15'
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE national_id = '87654321');

-- ------------------------------------------------------------
-- 3. Concepto de servicio para descuentos de bodega
--    Ajusta este ID en application.yml de la bodega:
--    integracion.financialtracker.service-concept-id
-- ------------------------------------------------------------
INSERT INTO service_concept (description, sale_price, cost_price, priority,
                             unid, priority_concept, createdBy, createdAt, codigo)
SELECT 'CONSUMO BODEGA', 0, 0, 0, 0, 'Primero', 1, '2026-07-13', 'BODEGA01'
WHERE NOT EXISTS (SELECT 1 FROM service_concept WHERE description = 'CONSUMO BODEGA');

-- ============================================================
-- Verificacion
-- ============================================================
SELECT '======== EMPLEADOS DEMO ========' AS info;
SELECT employee_id, national_id, fullName, employment_status
  FROM employees WHERE national_id IN ('12345678', '87654321');

SELECT '======== CONCEPTO CREADO ========' AS info;
SELECT ID, description, codigo FROM service_concept WHERE description = 'CONSUMO BODEGA';

SELECT '' AS ' ';
SELECT CONCAT('CONFIGURA en application.yml de la bodega: FT_SERVICE_CONCEPT_ID=',
              (SELECT ID FROM service_concept WHERE description = 'CONSUMO BODEGA'))
  AS proximo_paso;
