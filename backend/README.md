# Backend — Gestión Bodega API

API REST en **Spring Boot 3.3 + Java 17 + PostgreSQL** para el sistema de gestión.

---

## 🏛️ Arquitectura

```
┌─────────────────────────────────────────────┐
│  Controller (REST)        — endpoints HTTP   │
│         ↓                                   │
│  Service                  — lógica de negocio│
│         ↓                                   │
│  Repository (Spring Data) — acceso a BD     │
│         ↓                                   │
│  Entity (JPA)             — tablas          │
└─────────────────────────────────────────────┘

         🔒 JWT Filter intercepta todas las requests
```

**Tecnologías:**
- Spring Boot 3.3.5
- Spring Web + Validation
- Spring Data JPA + Hibernate 6
- Spring Security 6 + JWT (jjwt 0.12)
- PostgreSQL 14+
- Flyway (migraciones)
- Lombok
- SpringDoc OpenAPI (Swagger UI)

---

## 📁 Estructura de carpetas

```
backend/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/com/thiago/gestionbodega/
    │   │   ├── GestionBodegaApplication.java    ← @SpringBootApplication
    │   │   ├── config/                          ← SecurityConfig, OpenApiConfig
    │   │   ├── security/                        ← JWT (token + filter)
    │   │   ├── common/
    │   │   │   ├── audit/      ← BaseEntity (id, creadoEn, actualizadoEn)
    │   │   │   ├── dto/        ← ApiResponse<T> wrapper
    │   │   │   └── exception/  ← GlobalExceptionHandler + errores custom
    │   │   └── modules/        ← ⭐ Feature-First
    │   │       ├── auth/
    │   │       │   ├── controller/AuthController.java       (POST /auth/login)
    │   │       │   ├── service/AuthService.java
    │   │       │   └── dto/{LoginRequest,LoginResponse}
    │   │       ├── usuarios/   ← ✅ COMPLETO (referencia)
    │   │       │   ├── entity/{Usuario,RolUsuario}
    │   │       │   ├── repository/UsuarioRepository
    │   │       │   ├── service/UsuarioService
    │   │       │   ├── controller/UsuarioController
    │   │       │   └── dto/{UsuarioDto,CrearUsuarioRequest,ActualizarUsuarioRequest}
    │   │       ├── proveedores/
    │   │       ├── productos/
    │   │       ├── compras/
    │   │       ├── ventas/
    │   │       ├── cajas/
    │   │       ├── creditos/
    │   │       └── reportes/
    │   └── resources/
    │       ├── application.yml
    │       └── db/migration/
    │           ├── V1__initial_schema.sql      ← 12 tablas + enums + indices
    │           └── V2__seed_data.sql           ← admin + datos de ejemplo
    └── test/
```

---

## 🚀 Instalación y ejecución

### 1. Requisitos
- **JDK 17** (Temurin/Microsoft Build/Oracle)
- **Maven 3.9+** (o usar el wrapper `./mvnw`)
- **PostgreSQL 14+**

### 2. Configurar PostgreSQL

Crear base de datos y usuario:

```sql
CREATE DATABASE gestion_bodega;
CREATE USER bodega_user WITH ENCRYPTED PASSWORD 'bodega_pass';
GRANT ALL PRIVILEGES ON DATABASE gestion_bodega TO bodega_user;

-- Conectarse a la BD y dar permisos al esquema public
\c gestion_bodega
GRANT ALL ON SCHEMA public TO bodega_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bodega_user;
```

### 3. Ajustar conexión

Editar [`application.yml`](src/main/resources/application.yml) si tu PostgreSQL usa host/puerto/credenciales distintas a las default:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/gestion_bodega
    username: bodega_user
    password: bodega_pass
```

### 4. Compilar y arrancar

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

Al arrancar, **Flyway crea automáticamente todas las tablas** ejecutando `V1__initial_schema.sql` y `V2__seed_data.sql`.

El servidor queda escuchando en **`http://localhost:8080/api`**

---

## 🔐 Autenticación

### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

**Respuesta:**
```json
{
  "success": true,
  "message": "Login exitoso",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "expiresIn": 28800,
    "usuario": {
      "id": "...",
      "username": "admin",
      "nombreCompleto": "Administrador",
      "rol": "ADMINISTRADOR",
      "activo": true
    }
  }
}
```

### Usar el token
En todas las llamadas siguientes, agregar header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

### Usuarios pre-creados (V2__seed_data.sql)

| Usuario | Contraseña | Rol |
|---------|------------|-----|
| `admin` | `admin123` | ADMINISTRADOR |
| `encargado1` | `admin123` | ENCARGADO |
| `vendedor1` | `admin123` | VENDEDOR |

> ⚠️ Las 3 cuentas tienen la misma contraseña por simplicidad. Cambiar en producción.

---

## 📚 Endpoints disponibles

| Método | Ruta | Rol mínimo | Descripción |
|--------|------|-----------|-------------|
| POST | `/api/auth/login` | público | Autenticación |
| GET | `/api/usuarios` | ENCARGADO | Listar usuarios |
| GET | `/api/usuarios/{id}` | ENCARGADO | Obtener uno |
| POST | `/api/usuarios` | ADMINISTRADOR | Crear |
| PUT | `/api/usuarios/{id}` | ADMINISTRADOR | Actualizar |
| DELETE | `/api/usuarios/{id}` | ADMINISTRADOR | Desactivar (soft delete) |
| GET | `/api/proveedores` | autenticado | Listar |
| GET | `/api/productos` | autenticado | Listar activos |
| GET | `/api/ventas` | autenticado | Listar |
| GET | `/api/compras` | autenticado | Listar |
| GET | `/api/cajas` | autenticado | Listar |
| GET | `/api/creditos` | autenticado | Listar |
| GET | `/api/reportes/ventas-diarias` | autenticado | Pendiente impl |
| GET | `/api/reportes/stock` | autenticado | Pendiente impl |

### 📖 Swagger UI
Una vez corriendo, abre:
```
http://localhost:8080/api/swagger-ui.html
```
Allí puedes probar todos los endpoints, autenticarte con el botón "Authorize" pegando el JWT, y ver los schemas.

---

## 🗄️ Migraciones (Flyway)

**NUNCA** modifiques una migración que ya se aplicó en producción. Para hacer cambios, crea una nueva:

```
src/main/resources/db/migration/V3__agregar_columna_x.sql
V4__crear_tabla_y.sql
```

Flyway las ejecuta en orden al arrancar la app.

---

## 🛠️ Comandos útiles

```bash
# Compilar
mvn clean install

# Correr (con hot reload por DevTools)
mvn spring-boot:run

# Generar el JAR ejecutable
mvn clean package
java -jar target/gestion-bodega-backend-1.0.0.jar

# Tests
mvn test

# Limpiar BD y recrear desde cero (CUIDADO: borra todo)
mvn flyway:clean flyway:migrate
```

---

## 🔌 Integración con Flutter

Desde el Flutter, las llamadas se hacen a:
```
http://localhost:8080/api/...
```

Si Flutter corre en **otra PC en la red local**, cambia el `host` por la IP del servidor:
```
http://192.168.1.100:8080/api/...
```

Asegurarte que en `application.yml` el CORS permita el origen del cliente.

---

## 📋 Próximos pasos para completar

Los módulos `proveedores`, `productos`, `compras`, `ventas`, `cajas`, `creditos`, `reportes` solo tienen entity + repository + controller básico (GET listar). Falta:

1. **DTOs** para request/response
2. **Services** con lógica de negocio:
   - Productos: actualizar stock al vender/comprar, alertas de stock mínimo
   - Ventas: descontar stock, registrar crédito si forma_pago = CREDITO
   - Cajas: lógica de apertura/cierre/cuadre
   - Créditos: cierre mensual automático
   - Reportes: queries agregadas
3. **Validaciones** con `@Valid` y constraints
4. **Tests** unitarios y de integración

El módulo `usuarios/` está completo como **plantilla a copiar** para los demás.

---

## 🐛 Troubleshooting

**Error: `password authentication failed for user "bodega_user"`**
→ Verifica las credenciales en `application.yml` y que el usuario tenga permisos sobre la BD.

**Error: `Validation failed for query for method...`**
→ La entidad JPA no coincide con la tabla. Verifica que `ddl-auto: validate` y que la migración corrió.

**Error: `relation "usuarios" does not exist`**
→ Flyway no corrió las migraciones. Revisa logs al arrancar y verifica que `spring.flyway.enabled=true`.
