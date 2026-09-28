# Backend — Gestión Bodega API

API REST en **Spring Boot 3.3 + Java 17+ + MySQL 8** para el sistema de la tienda (Sub Cafe).

> **Una sola base de datos.** El backend se conecta a la misma base MySQL que usa
> FinantialTracker (`subcafe_manager_hsj`): base `financialtracker1` en el contenedor
> Docker `mysql-proyectos` (`~/Desktop/me/mysql-db`). Las tablas de la tienda
> (`usuarios`, `productos`, `ventas`, …) conviven con las de préstamos
> (`employees`, `loan`, `abono`, …) sin chocar.

---

## 🏛️ Arquitectura (por capas, carpetas simples)

```
┌─────────────────────────────────────────────┐
│  controller/   — endpoints HTTP (REST)       │
│         ↓                                   │
│  service/      — lógica de negocio           │
│         ↓                                   │
│  repository/   — acceso a BD (Spring Data)   │
│         ↓                                   │
│  entity/       — tablas (JPA)                │
└─────────────────────────────────────────────┘
         🔒 security/ (JWT) intercepta todas las requests
```

Misma idea que `subcafe_manager_hsj` (`controller/`, `data/dao`, `data/entity`, `model/`):
**todos los controladores en una carpeta, todos los servicios en otra, etc.**

```
backend/
├── pom.xml
├── mvnw / mvnw.cmd          ← Maven Wrapper (no hace falta instalar Maven)
├── run.sh / run.cmd         ← arrancar en local con un solo comando
└── src/main/
    ├── java/com/thiago/gestionbodega/
    │   ├── GestionBodegaApplication.java   ← @SpringBootApplication
    │   ├── config/       SecurityConfig, OpenApiConfig, FlywayConfig, JpaAuditingConfig
    │   ├── security/     JwtTokenProvider, JwtAuthenticationFilter
    │   ├── controller/   AuthController, UsuarioController, ProductoController, VentaController,
    │   │                 CompraController, CajaController, CreditoController, ClienteController,
    │   │                 ValeController, PuntosController, ReporteController, ConfiguracionController,
    │   │                 ProveedorController
    │   ├── service/      AuthService, UsuarioService, CajaService, CompraService, ValeService,
    │   │                 CierreCreditosService, ReporteService
    │   ├── repository/   Un JpaRepository por entidad + ReporteRepository (JdbcTemplate)
    │   ├── entity/       Usuario, Producto, Venta, Caja, Vale, ... y sus enums (RolUsuario, FormaPago, ...)
    │   ├── dto/          Requests / responses de la API + ApiResponse<T>
    │   └── exception/    GlobalExceptionHandler, BusinessException, NotFoundException
    └── resources/
        ├── application.yml
        ├── application-local.yml.example
        └── db/migration/
            ├── V1__schema_inicial.sql              ← todas las tablas y vistas (MySQL)
            ├── V2__seed_data.sql                   ← admin + configuración + datos de ejemplo
            ├── V3__integracion_finantial_tracker.sql ← enlace clientes ↔ employees (FinantialTracker)
            └── V4__deudores_y_union_finantial.sql    ← deudas por trabajador, ventas con crédito, detalle de cierre
```

**Tecnologías:** Spring Boot 3.3.5 · Spring Web + Validation · Spring Data JPA + Hibernate 6 ·
Spring Security 6 + JWT (jjwt 0.12) · MySQL 8 (Connector/J) · Flyway 10 · Lombok · SpringDoc OpenAPI.

---

## 🚀 Ejecutar en local

### 1. Requisitos
- **JDK 17 o 21** (en esta Mac: `/usr/libexec/java_home -V`).
- **Docker** con el contenedor MySQL de `~/Desktop/me/mysql-db`.
- Maven **no** hace falta: el proyecto trae `mvnw`.

### 2. Encender la base de datos (la misma de FinantialTracker)

```bash
cd ~/Desktop/me/mysql-db
docker compose up -d          # contenedor "mysql-proyectos", puerto 3306
docker ps                     # debe salir mysql-proyectos ... Up
```

| Campo | Valor por defecto |
|---|---|
| Host / puerto | `localhost:3306` |
| Base de datos | `financialtracker1` |
| Usuario / clave | `root` / `123456` |

### 3. Arrancar el backend

```bash
cd backend
./run.sh            # macOS / Linux  (elige solo un JDK 17/21 y ejecuta ./mvnw spring-boot:run)
run.cmd             # Windows
```

Al arrancar, **Flyway crea las tablas de la tienda** dentro de `financialtracker1`
(`V1__schema_inicial.sql`, `V2__seed_data.sql`). Las tablas de préstamos no se tocan:
la línea base de Flyway es la versión 0 y solo administra sus propias migraciones.

Servidor: **`http://localhost:8080/api`** · Swagger: **`http://localhost:8080/api/swagger-ui.html`**

### 4. Cambiar la conexión (opcional)

`application.yml` lee variables de entorno con defaults para local:

```yaml
datasource:
  url: ${DB_URL:jdbc:mysql://localhost:3306/financialtracker1?...}
  username: ${DB_USER:root}
  password: ${DB_PASS:123456}
```

- **Otra PC / servidor en LAN:** `export DB_URL="jdbc:mysql://192.168.1.50:3306/financialtracker1?useSSL=false&allowPublicKeyRetrieval=true&connectionTimeZone=America/Lima&forceConnectionTimeZoneToSession=true"`
- **Perfil local:** copia `application-local.yml.example` → `application-local.yml` y arranca con `./run.sh local`.
- **Producción:** define `DB_PASS` y `JWT_SECRET` (`openssl rand -base64 48`) como variables de entorno.

---

## 🗄️ Base de datos (MySQL)

Convenciones usadas en `V1__schema_inicial.sql`:

| Concepto | Tipo en MySQL | Nota |
|---|---|---|
| Identificadores | `CHAR(36)` (UUID legible) | Hibernate: `preferred_uuid_jdbc_type: CHAR` |
| Enums (rol, turno, forma_pago…) | `VARCHAR(20)` + `CHECK` | Antes eran `CREATE TYPE ... AS ENUM` de PostgreSQL |
| Fechas | `TIMESTAMP(6)` | La sesión JDBC trabaja en `America/Lima` |
| Booleanos | `BOOLEAN` | |
| JSON de auditoría | `JSON` | |

Vistas: `v_stock_actual`, `v_ventas_con_pagos`, `v_puntos_por_cliente`, `v_creditos_del_mes`,
`v_deuda_trabajadores_acumulada`.

**Migraciones:** nunca edites una migración ya aplicada; crea `V3__lo_que_sea.sql`.
`FlywayConfig` ejecuta `repair()` antes de `migrate()` en desarrollo (desactivar con `FLYWAY_REPAIR=false`).

Consultar desde la terminal:

```bash
docker exec -it mysql-proyectos mysql -uroot -p123456 financialtracker1
SHOW TABLES;
SELECT username, rol FROM usuarios;
SELECT * FROM flyway_schema_history;
```

> En DBeaver / TablePlus: driver properties `allowPublicKeyRetrieval=TRUE`, `useSSL=FALSE`
> y `serverTimezone=America/Lima` para ver las horas en hora de Perú.

---

## 🔗 Integración con FinantialTracker (misma base de datos)

La base `financialtracker1` se cargó con el respaldo real del sistema de préstamos
(`27-09-26.sql`: 1046 empleados, 180 préstamos, 3562 abonos, 4068 registros de pago, 29 conceptos).
La tienda **no toca** esas tablas; solo las lee.

| Qué | Dónde |
|---|---|
| Padrón de trabajadores del hospital | tabla `employees` (de FinantialTracker) |
| Trabajadores en la tienda (vales, puntos, crédito) | tabla `clientes`, enlazada por `clientes.empleado_id` = `employees.employee_id` |
| Vista de apoyo | `v_empleados_finantial` (empleado + si ya es cliente) |
| Sincronizar padrón → clientes | `POST /api/clientes/finantial/sincronizar` (admin / encargado) |

La sincronización es **idempotente**: crea los clientes que faltan, actualiza nombre / DNI /
condición laboral (Nombrado, CAS) de los existentes, nunca borra y conserva teléfono y estado
`activo` puestos desde la tienda. El nombre original (`APELLIDOS NOMBRES`) se guarda en
`clientes.nombre_original`; `apellidos` / `nombres` se separan con una heurística que entiende
apellidos compuestos (DEL POZO, DE LA CRUZ) y de casada (… DE RETO).

Reglas importantes:
- **Sin FOREIGN KEY** de `clientes` hacia `employees`: los respaldos de FinantialTracker hacen
  `DROP TABLE` + `CREATE TABLE`, y un FK desde la tienda rompería la restauración.
- Para restaurar un respaldo nuevo de FinantialTracker basta con importarlo en la misma BD;
  las tablas de la tienda no se ven afectadas (el dump solo trae las 17 tablas de préstamos).
  Luego se vuelve a ejecutar la sincronización.
- Los nombres de FK/CHECK/índices son únicos por base de datos en MySQL: los de la tienda llevan
  prefijo de tabla para no chocar con los de FinantialTracker.

### Deudores: quién debe y cómo llega a FinantialTracker

```
Venta en el POS (POST /ventas)
 ├─ cliente EXTERNO  → pagos EFECTIVO / YAPE / PLIN / NIUBIZ → solo se registra la venta
 └─ TRABAJADOR      → pago CREDITO + clienteId (cliente con es_trabajador)
                       → creditos_trabajadores (cliente_id, monto, venta_id, periodo)
                       → aparece en la pestaña Deudores / v_deudores
Cierre de mes (POST /creditos/cerrar-mes)
 ├─ suma por trabajador → deuda_trabajadores (acumulada)
 ├─ una fila por trabajador → cierre_creditos_detalle (monto, ft_abono_id, ft_error)
 └─ exportación a FinantialTracker:  DESACTIVADA por ahora
      (configuracion finantial.exportar_al_cerrar = false)
```

Cuando se active la unión (`finantial.exportar_al_cerrar = true`, o manualmente con
`POST /deudores/cierres/{id}/exportar-finantial`), cada fila del detalle se convierte en un
`abono` de 1 cuota en FinantialTracker con el concepto `finantial.concepto_abono_id`
(por defecto **8 = DESCUENTOS CREDITO BAZAR**), `status = Pendiente`,
`discount_from = BOLETA DE HABERES` y `paymentDate` = último día del mes siguiente al cerrado,
igual que lo hace la pantalla "Abonos" de FinantialTracker. El `abono.ID` queda guardado en
`cierre_creditos_detalle.ft_abono_id` para no duplicar y para ver desde la tienda si ya se pagó.
Mientras la unión esté apagada, **nada se escribe en las tablas de FinantialTracker**.

Reglas de negocio:
- Un pago CREDITO sin `clienteId`, o con un cliente que no es trabajador activo, se rechaza (400).
- La suma de pagos debe coincidir con el total (tolerancia 0.01).
- Una venta cuya deuda ya entró en un cierre no se puede anular (la deuda ya viajó / viajará a planilla).
- `POST /deudores/consumos` anota una deuda a mano (consumo que no pasó por el POS).

```bash
# Restaurar un respaldo nuevo de FinantialTracker en la BD compartida
docker exec -i mysql-proyectos mysql -uroot -p123456 < ~/Downloads/respaldo.sql
# Luego, con el backend arriba y un token de admin:
curl -X POST http://localhost:8080/api/clientes/finantial/sincronizar -H "Authorization: Bearer $TOKEN"
```

---

## 🔐 Autenticación

```http
POST /api/auth/login
Content-Type: application/json

{ "username": "admin", "password": "admin123" }
```

Respuesta: `{ "success": true, "data": { "token": "eyJ...", "expiresIn": 28800, "usuario": {...} } }`.
Luego enviar `Authorization: Bearer <token>` en cada request.

| Usuario | Contraseña | Rol |
|---------|------------|-----|
| `admin` | `admin123` | ADMINISTRADOR |
| `encargado1` | `admin123` | ENCARGADO |
| `vendedor1` | `admin123` | VENDEDOR |

> ⚠️ Cambiar las contraseñas en producción.

---

## 📚 Endpoints

| Método | Ruta | Rol mínimo | Descripción |
|--------|------|-----------|-------------|
| POST | `/auth/login` | público | Autenticación |
| GET/POST/PUT/DELETE | `/usuarios` | ENCARGADO / ADMIN | Usuarios del sistema |
| GET | `/productos` | autenticado | Productos activos |
| GET | `/proveedores` | autenticado | Proveedores |
| GET/POST | `/compras` · `/compras/{id}` | autenticado | Compras (actualizan stock y precio) |
| GET/POST | `/ventas` · `/ventas/{id}` · `/ventas/{id}/anular` | autenticado / ENCARGADO | POS: venta con pago mixto; CREDITO solo a trabajadores |
| GET/POST/DELETE | `/deudores` · `/deudores/resumen` · `/deudores/{clienteId}` · `/deudores/consumos` · `/deudores/cierres/{id}` · `/deudores/cierres/{id}/exportar-finantial` · `/deudores/finantial/abonos` | autenticado / ENCARGADO | Deudores (trabajadores con crédito) y unión con FinantialTracker |
| GET/POST | `/cajas` · `/cajas/abrir` · `/cajas/abierta` · `/cajas/{id}/cerrar` · `/cajas/{id}/avances` | autenticado | Turnos de caja |
| GET/POST | `/clientes` · `/clientes/import` | autenticado | Trabajadores / clientes |
| GET/POST | `/clientes/finantial/resumen` · `/clientes/finantial/empleados?pendientes=true` · `/clientes/finantial/sincronizar` | autenticado / ENCARGADO | Padrón de FinantialTracker y sincronización a clientes |
| GET/POST | `/vales` · `/vales/emitir` · `/vales/{id}/anular` | autenticado | Vales |
| GET | `/puntos/saldos` · `/puntos/saldo/{id}` · `/puntos/movimientos/{id}` · `/puntos/canjeables` · `/puntos/regla-activa` | autenticado | Puntos |
| GET/POST | `/creditos` · `/creditos/del-mes` · `/creditos/deuda-acumulada` · `/creditos/cierres` · `/creditos/cerrar-mes` | autenticado / ENCARGADO | Crédito a trabajadores |
| GET | `/reportes/ventas-diarias` · `/reportes/stock` · `/reportes/stock-bajo` · `/reportes/top-productos` | autenticado | Reportes |
| GET/PUT | `/configuracion` | autenticado | Configuración key-value |

Todo está documentado y se puede probar en Swagger UI.

---

## 🛠️ Comandos útiles

```bash
./mvnw clean package -DskipTests        # generar el JAR
java -jar target/gestion-bodega-backend-1.0.0.jar
./mvnw test                             # tests
```

---

## 🔌 Integración con Flutter

El front (`lib/core/api/api_endpoints.dart`) apunta a `http://localhost:8080/api`.
Si Flutter corre en otra PC de la red, cambia el host por la IP del servidor donde corre este backend.
El front nunca habla directo con MySQL: todo pasa por esta API.

Pantallas conectadas al backend:
- **Ventas (POS)**: catálogo real (`GET /productos` con precio vigente y stock), exige caja abierta,
  cobro con pago mixto y `POST /ventas`. El pago a CRÉDITO abre un buscador de trabajadores; un
  externo no puede usar crédito. Historial del turno con reimpresión y anulación.
- **Deudores**: `GET /deudores`, detalle por trabajador, anotar deuda manual.
- **Créditos**: cierre mensual e historial (con estado de exportación a FinantialTracker).

## 🖥️ Pestaña "DEUDAS TIENDA" en FinantialTracker (Java Swing)

En `subcafe_manager_hsj` se agregó el menú **DEUDAS TIENDA** (`ComponentDeudasTienda` +
`DeudaTiendaDao`). Es de **solo lectura** sobre las mismas tablas de la tienda y se refresca sola
cada 10 segundos: deudores con sus compras, últimas compras a crédito y cierres mensuales (lo que
irá a planilla). No escribe nada; la unión real (crear el `abono`) sigue desactivada.

---

## 🐛 Troubleshooting

**`Communications link failure` / `Connection refused`**
→ MySQL apagado: `cd ~/Desktop/me/mysql-db && docker compose up -d`.

**`Access denied for user 'root'@...`**
→ Revisa `DB_USER` / `DB_PASS` (por defecto `root` / `123456`, igual que `mysql-db/docker-compose.yml`).

**`Public Key Retrieval is not allowed`**
→ La URL debe llevar `allowPublicKeyRetrieval=true&useSSL=false` (ya viene en `application.yml`).

**`Schema-validation: wrong column type` / `missing table`**
→ Flyway no corrió o alguien modificó la BD a mano. Revisa `flyway_schema_history` y los logs al arrancar.

**`Migration checksum mismatch`**
→ Se editó una migración ya aplicada. `FlywayConfig` la repara al arrancar; si persiste, crea una migración nueva.

**`error: release version 17 not supported` / `Unsupported class file major version`**
→ Estás usando Java 8/11. Usa `./run.sh` (elige JDK 17/21 solo) o exporta `JAVA_HOME` a un JDK 17+.
