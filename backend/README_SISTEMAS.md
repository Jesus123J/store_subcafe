# Los dos sistemas y el backend unificado

Este documento explica cómo conviven las **dos aplicaciones** (planilla del
hospital y gestión de bodega), sus **dos bases de datos**, y el **backend
Spring Boot** que se conecta a ambas. Nada de lo existente se eliminó: el
backend solo **agrega** una capa de API sobre lo que ya funcionaba.

---

## 1. Panorama general

```
┌─────────────────────────┐        ┌──────────────────────────┐
│  FinantialTracker       │        │  Gestión Bodega          │
│  (Java Swing, planilla  │        │  (Flutter, punto de      │
│   del HSJ / Subcafae)   │        │   venta y almacén)       │
└───────────┬─────────────┘        └───────────┬──────────────┘
            │ JDBC directo                     │ REST (JWT)
            ▼                                  ▼
┌─────────────────────────┐        ┌──────────────────────────┐
│  BD: financialtracker1  │◄───────┤  Backend Spring Boot     │
│  (MariaDB/MySQL)        │  JDBC  │  (este proyecto)         │
└─────────────────────────┘ 2° DS  │  puerto 8080, /api       │
                                   └───────────┬──────────────┘
                                               │ JPA (primario)
                                               ▼
                                   ┌──────────────────────────┐
                                   │  BD: gestion_bodega      │
                                   │  (MariaDB/MySQL)         │
                                   └──────────────────────────┘
```

- **FinantialTracker** (`Documents\git project\FinantialTracker`): app de
  escritorio Swing que usa el Hospital San Juan de Dios para planilla:
  préstamos, abonos (descuentos), pagos, vouchers de pago y estadísticas de
  empleados. **En migración hacia el backend**: la lista de empleados y las
  estadísticas de empleado ya se consumen vía API REST (`ApiBackend.java`,
  con login JWT); si el backend no está corriendo, cae automáticamente al
  JDBC directo de siempre (fallback con los DAOs). Los demás módulos
  (préstamos, pagos, vouchers — las escrituras) siguen por JDBC directo
  hasta que el backend exponga esos endpoints.
- **Gestión Bodega** (`Documents\Proyeto_2026`): app Flutter (POS/almacén)
  que consume este backend por REST. Sus datos viven en `gestion_bodega`.
- **Backend** (`Documents\Proyeto_2026\backend`): Spring Boot 3.3 con **dos
  conexiones**:
  - *Primaria* (JPA + Flyway): `gestion_bodega` — todos los módulos de la
    bodega (ventas, compras, cajas, créditos, vales, puntos...).
  - *Secundaria* (JDBC, pool `FinancialTrackerPool`): `financialtracker1` —
    módulo `integracion/ft`, que empuja la deuda mensual de los trabajadores
    a la planilla y ahora también **expone en lectura** los datos de la
    planilla (empleados, préstamos, abonos, vouchers, estadísticas).

Los dos sistemas comparten a los **empleados**: la bodega no tiene tabla
propia de trabajadores — los lee en vivo de `financialtracker1.employees`
(endpoint `/api/trabajadores`), y cuando cierra el mes de créditos inserta
abonos en la planilla para que el descuento salga por boleta.

---

## 2. Base de datos `financialtracker1` (planilla HSJ)

Usada por la app Swing FinantialTracker y por el segundo datasource del
backend. Tablas (con filas aproximadas al momento de escribir esto):

| Tabla | Filas | Qué guarda |
|---|---|---|
| `employees` | ~1 046 | Empleados del hospital: `employee_id` (PK), `national_id` (DNI, único), nombre, género, estado (Nombrado/CAS), fecha de ingreso |
| `loan` | ~180 | Préstamos. **OJO:** `EmployeeID` guarda el **DNI** (no el id numérico). Estados: Pendiente/Aceptado/Denegado/Refinanciado + `StateLoan` (Pendiente/Pagado) |
| `loandetail` | ~2 411 | Cuotas de cada préstamo (intereses, fondo intangible, vencimientos) |
| `abono` | ~3 632 | Abonos/descuentos mensuales. **OJO:** `Employee_id` guarda el **id numérico** de `employees` (a diferencia de `loan`) |
| `abonodetail` | ~9 820 | Cuotas de cada abono con estado de pago (Pendiente/Parcial/Pagado) |
| `service_concept` | 32 | Catálogo de conceptos de servicio (a qué corresponde cada abono; incluye el concepto de consumo en bodega) |
| `registro` | ~4 072 | Registros de pago (cabecera) |
| `registerdetails` | ~6 598 | Detalle de los registros de pago |
| `voucher` | ~86 | Vouchers de pago / constancias de entrega (girado a, banco, cheque, monto) |
| `voucher_temp` | ~86 | Reserva temporal de números de voucher (estado PENDING/CONFIRMED) |
| `lote_carga` | 7 | Lotes de carga masiva de pagos |
| `lote_carga_abono` | 0 | Lotes de carga masiva de abonos (Excel y envíos de la bodega); permite revertir un lote completo |
| `historial_correcciones` | ~176 | Log de correcciones de pagos duplicados/huérfanos |
| `historial_reversiones` | 0 | Log de reversiones de pagos |
| `log_operaciones_masivas` | 0 | Log de operaciones masivas |
| `backup_pagos_antes_correccion` | 0 | Respaldo automático antes de correcciones masivas |
| `user` | — | Usuarios de la app Swing (login, roles) |

**Relaciones clave**: `abono.Employee_id → employees.employee_id` (numérico),
`loan.EmployeeID → employees.national_id` (DNI), `abonodetail.AbonoID →
abono.ID`, `loandetail.LoanID → loan.ID`, `abono.lote_id → lote_carga_abono.id`.

---

## 3. Base de datos `gestion_bodega` (bodega/POS)

Usada solo por el backend (JPA + migraciones Flyway `V1`–`V9`). La app
Flutter nunca toca la BD directo.

| Tabla | Qué guarda |
|---|---|
| `usuarios` | Usuarios del backend (admin/encargado/vendedor, login JWT) |
| `productos`, `producto_precios` | Catálogo de productos y su historial de precios |
| `proveedores` | Proveedores de la bodega |
| `compras`, `compra_detalle` | Compras a proveedores y sus líneas |
| `ventas`, `venta_detalle`, `venta_pagos` | Ventas, líneas de venta y formas de pago (soporta pago mixto) |
| `cajas`, `avances_efectivo` | Apertura/cierre de caja por turno y retiros de efectivo |
| `clientes` | Clientes de la bodega (para créditos y puntos) |
| `creditos_trabajadores`, `deuda_trabajadores` | Créditos fiados a trabajadores del hospital (identificados por DNI) y su deuda |
| `cierres_mensuales_creditos` | Cierres de mes de los créditos (lo que se envía a planilla) |
| `envios_financialtracker` | **Puente entre sistemas**: registro de cada envío de deuda a `financialtracker1` (qué lote de abonos se creó allá, estado, reversión) |
| `vales`, `vale_movimientos` | Vales de consumo |
| `reglas_puntos`, `movimientos_puntos`, `productos_canjeables` | Programa de puntos |
| `mermas` | Pérdidas de inventario |
| `configuracion` | Parámetros de la app |
| `auditoria` | Log de auditoría |
| `flyway_schema_history` | Control de migraciones (no tocar) |
| Vistas `v_stock_actual`, `v_ventas_con_pagos`, `v_creditos_del_mes`, `v_deuda_trabajadores_acumulada`, `v_puntos_por_cliente` | Consultas calculadas para reportes |

---

## 4. API del backend

Base: `http://localhost:8080/api` — todo requiere JWT salvo el login
(`POST /api/auth/login`). Swagger en `http://localhost:8080/api/swagger-ui.html`.

### Módulos de bodega (BD primaria)
Usuarios, proveedores, productos, compras, ventas, cajas, créditos, vales,
puntos, clientes, configuración y reportes — ver README.md principal.

### Integración con la planilla (BD secundaria `financialtracker1`)

**Escritura (ya existía):**

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/integracion/ft/enviar-cierre/{cierreId}` | Envía el cierre mensual de créditos como lote de abonos a la planilla |
| POST | `/integracion/ft/enviar-credito/{creditoId}` | Envía un crédito individual |
| POST | `/integracion/ft/revertir/{envioId}` | Revierte un envío (borra el lote de abonos si no tiene pagos) |
| GET | `/integracion/ft/envios` | Historial de envíos |
| GET | `/integracion/ft/health` | Estado de la conexión a la planilla |
| GET | `/trabajadores` | Lista dni + nombre desde `employees` (passthrough) |

**Lectura (NUEVO — espejo de lo que consulta la app Swing):**

| Método | Ruta | Qué devuelve |
|---|---|---|
| GET | `/integracion/ft/empleados` | Todos los empleados (dni, nombre, estado) |
| GET | `/integracion/ft/empleados/{dni}` | Detalle de un empleado |
| GET | `/integracion/ft/empleados/{dni}/prestamos` | Sus préstamos, todos los estados |
| GET | `/integracion/ft/empleados/{dni}/abonos` | Sus abonos con nombre del concepto |
| GET | `/integracion/ft/empleados/{dni}/estadisticas` | Totales, refinanciamientos, monto de abonos y distribución por estado (igual que el dashboard "ESTADISTICAS EMPLEADO" del Swing) |
| GET | `/integracion/ft/vouchers?limite=50` | Últimos vouchers de pago |
| GET | `/integracion/ft/conceptos` | Catálogo de conceptos de servicio |

Ejemplo:

```bash
# 1. Login
curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 2. Estadísticas de un empleado por DNI (con el token del paso 1)
curl -s http://localhost:8080/api/integracion/ft/empleados/08292183/estadisticas \
  -H "Authorization: Bearer <TOKEN>"
```

---

## 5. Configuración de las conexiones

En `src/main/resources/application.yml` (todo sobreescribible por variable
de entorno):

| Variable | Default | Qué configura |
|---|---|---|
| `DB_URL` / `DB_USER` / `DB_PASS` | `jdbc:mariadb://localhost:3306/gestion_bodega` / `bodega_user` / `bodega_pass` | BD primaria (bodega) |
| `FT_ENABLED` | `true` | Activa/desactiva el módulo de planilla (si está en `false`, sus endpoints devuelven 503 y el resto del backend funciona normal) |
| `FT_DB_URL` / `FT_DB_USER` / `FT_DB_PASS` | `jdbc:mariadb://localhost:3306/financialtracker1` / `root` / *(vacío)* | BD secundaria (planilla) |
| `FT_SERVICE_CONCEPT_ID` | `1` | Concepto de FT que representa "Consumo en bodega" |
| `FT_DIA_DESCUENTO` | `5` | Día del mes siguiente en que se descuenta el abono enviado |

La conexión a la planilla es **perezosa**: si `financialtracker1` está caída
al arrancar, el backend igual levanta y solo fallan los endpoints `/integracion/ft/*`
y `/trabajadores` cuando se usan.

```powershell
# Arrancar apuntando a las BDs locales reales
$env:FT_DB_USER = "root"; $env:FT_DB_PASS = "123456"
cd "C:\Users\Jesus Gutierrez\Documents\Proyeto_2026\backend"
mvn spring-boot:run
```

---

## 6. Migración del escritorio al backend

La app Swing consume el backend con `ApiBackend.java`
(`data/conexion/ApiBackend.java`): hace login JWT contra `/auth/login`
(configurable en `backend.properties` junto al JAR: `backend.url`,
`backend.user`, `backend.pass`) y consulta la API. **Si el backend está
caído, cada módulo migrado cae automáticamente al DAO/JDBC directo** — la
app nunca deja de funcionar.

**Migración COMPLETA (jul 2026)** — todos los DAOs del escritorio son
backend-first; el JDBC directo quedó solo como fallback automático cuando el
backend no responde:

| Módulo del escritorio | Estado |
|---|---|
| Empleados (`EmployeeDao`: CRUD completo, búsquedas, rangos) | ✅ `/integracion/ft/empleados-full/*` |
| Usuarios y login de la app (`UserDao`, BCrypt server-side) | ✅ `/integracion/ft/usuarios/*` |
| Estadísticas de empleado (`EmployeeStatsDao`) | ✅ `/integracion/ft/empleados/{dni}/estadisticas` |
| Préstamos (`LoanDao`, `LoanDetailsDao`: creación transaccional con SoliNum, refinanciamiento padre/hijo, cuotas, pagos de cuota) | ✅ `/integracion/ft/prestamos*` (20 endpoints) |
| Abonos (`AbonoDao`, `AbonoDetailsDao`, `LoteCargaAbonoDao`, `ServiceConceptDao`) | ✅ `/integracion/ft/abonos*`, `/lotes-abono/*`, `/conceptos/*` (26 endpoints) |
| Registro de pagos (`RegistroDao`: 47 operaciones — pagos completos, lotes, reversiones, correcciones de duplicados, huérfanos, edición, transferencias a voucher, últimos cambios) | ✅ `/integracion/ft/pagos/*` (47 endpoints) |
| Vouchers (`PaymentVoucher`: crear, editar, reservar número, limpiar temporales, listar) | ✅ `/integracion/ft/vouchers*` |

`Conexion.java` queda SOLO como **fallback automático** (si el backend está
caído, cada DAO cae al JDBC original con el mensaje "Backend no disponible,
usando conexion directa"). Nada se eliminó.

Nota técnica: los repositorios del módulo ft usan
`@ConditionalOnProperty(name = "integracion.financialtracker.enabled")` en
vez de `@ConditionalOnBean(name = "ftJdbc")` — la condición por bean dependía
del orden alfabético de escaneo de paquetes y descartaba los repos de
subpaquetes que se escanean antes que `FinancialTrackerConfig`.

## 7. Qué NO cambió

- El esquema de `financialtracker1` no se modificó: los endpoints nuevos son
  de **solo lectura** y las escrituras del backend siguen limitadas al flujo
  de envío de deuda (tablas `abono`, `abonodetail`, `lote_carga_abono`).
- La app Flutter y sus módulos de bodega siguen igual; solo se agregaron
  endpoints (y `GET /trabajadores` ahora incluye también `id` y
  `codigo_estado`, campos aditivos).
