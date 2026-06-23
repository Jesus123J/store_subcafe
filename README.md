# store_subcafe

Sistema de gestión de bodega + fotocopiadora para **Sub Café** (Perú).
Cliente: Karina. Flujos cubiertos: ventas (POS con pago mixto), compras,
stock, caja por turno, créditos a trabajadores, vales, puntos y reportes.

---

## Stack

| Capa     | Tecnología                                                 |
| -------- | ----------------------------------------------------------- |
| Frontend | Flutter Desktop (Windows) · Riverpod · GoRouter             |
| Backend  | Spring Boot 3.3 · Java 17 · JPA/Hibernate · Flyway · JWT    |
| BD       | MySQL 8 / MariaDB (driver `mariadb-java-client`)            |

---

## Arrancar en local

### 1. Backend

Requiere **MySQL 8** corriendo en `localhost:3306` con una BD vacía:

```sql
CREATE DATABASE gestion_bodega CHARACTER SET utf8mb4;
CREATE USER 'bodega_user'@'localhost' IDENTIFIED BY 'bodega_pass';
GRANT ALL ON gestion_bodega.* TO 'bodega_user'@'localhost';
```

Luego:

```bash
cd backend
mvn spring-boot:run
```

Flyway corre las 7 migrations al arrancar (crea esquema + seed). La API
queda en `http://localhost:8080/api` y Swagger en `/api/swagger-ui.html`.

### 2. Frontend

Requiere **Flutter 3.41+** con soporte Windows desktop habilitado y
**Visual Studio 2022/2026** (workload *Desktop development with C++*).

```bash
flutter pub get
flutter run -d windows
```

El cliente apunta a `http://localhost:8080/api` (ver `lib/core/api/api_endpoints.dart`).

### 3. Login

- Usuario: `admin`
- Password: `admin123`

---

## Estructura

```
backend/
  src/main/java/com/thiago/gestionbodega/
    config/           JpaAuditing, Security, CORS
    common/           DTOs base, excepciones, BaseEntity
    modules/
      auth/           Login + JWT
      cajas/          Apertura/cierre, avances, cuadre
      clientes/       Clientes y trabajadores (importables)
      compras/        Compras a proveedores (suma stock)
      configuracion/  Key-value editable por admin
      creditos/       Crédito mensual a trabajadores + cierre
      productos/      Catálogo + histórico de precios
      proveedores/    CRUD básico
      puntos/         Fidelización por consumo
      reportes/       Ventas diarias, stock, top productos
      usuarios/       Admin / Encargado / Vendedor
      vales/          Bonificaciones canjeables
      ventas/         POS con pago mixto (efectivo + Yape + crédito)
  src/main/resources/db/migration/   V1..V7 (MySQL)

lib/
  app/                Theme, router, colores
  core/               Api client, utils, services
  features/<modulo>/  data/ · domain/ · presentation/
  shared/             Widgets y layouts reutilizables
```

---

## Comandos útiles

```bash
# Backend
mvn -f backend/pom.xml clean compile
mvn -f backend/pom.xml spring-boot:run

# Frontend
flutter analyze
flutter test
flutter build windows --release
```

---

## CI

GitHub Actions corre en cada PR y push a `main`:

1. Compila el backend (Maven) y corre los tests
2. Verifica el frontend con `flutter analyze`

Ver [`.github/workflows/ci.yml`](.github/workflows/ci.yml).
