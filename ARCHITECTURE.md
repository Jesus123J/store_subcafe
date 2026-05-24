# Arquitectura del Proyecto

## 🏛️ Patrón elegido: Clean Architecture + Feature-First

Este proyecto usa una combinación de dos patrones probados en producción:

1. **Clean Architecture** (Uncle Bob) — separación estricta en 3 capas (Domain, Data, Presentation).
2. **Feature-First** (Vertical Slicing) — cada módulo de negocio es autocontenido.

### ¿Por qué esta arquitectura?

| Beneficio | Explicación |
|-----------|-------------|
| 🧱 **Mantenible** | Cada feature vive aislada — tocar "Ventas" no rompe "Reportes" |
| 🧪 **Testeable** | El dominio no depende de Flutter ni de la BD — se testea con Dart puro |
| 🔄 **Reemplazable** | Cambiar PostgreSQL por otra BD solo afecta la capa Data |
| 📈 **Escalable** | Agregar un módulo nuevo = crear una carpeta en `features/` |
| 👥 **Colaborable** | Múltiples desarrolladores pueden trabajar en features distintas sin pisarse |

---

## 📚 Las 3 capas (Clean Architecture)

```
┌─────────────────────────────────────────────────────┐
│  PRESENTATION (UI + Estado)                         │
│  └─ Pages, Widgets, Providers (Riverpod)            │
│                                                     │
│  ↓ depende de                                       │
│                                                     │
├─────────────────────────────────────────────────────┤
│  DOMAIN (Lógica de negocio pura)                    │
│  └─ Entities, Repository interfaces, UseCases       │
│  └─ No conoce Flutter, no conoce SQL                │
│                                                     │
│  ↑ implementado por                                 │
│                                                     │
├─────────────────────────────────────────────────────┤
│  DATA (Acceso a datos)                              │
│  └─ Models (DTOs), DataSources, Repository impls    │
│  └─ Aquí vive PostgreSQL                            │
└─────────────────────────────────────────────────────┘
```

**Regla de oro:** Las dependencias apuntan SIEMPRE hacia el centro (Domain). Domain no conoce a nadie.

### Capa **Domain**
- **Entities**: objetos de negocio puros (`Usuario`, `Venta`, `Producto`). Sin anotaciones, sin JSON, sin SQL.
- **Repository interfaces**: contratos abstractos (`abstract class VentasRepository`).
- **UseCases**: un caso de uso = una acción del negocio (`CrearVentaUseCase`, `LoginUseCase`).

### Capa **Data**
- **Models**: extienden de las Entities, agregan `fromMap()`, `toMap()`, `fromJson()`.
- **DataSources**: acceso bruto a PostgreSQL (queries SQL).
- **Repository implementations**: implementan las interfaces de Domain usando los DataSources.

### Capa **Presentation**
- **Pages**: pantallas completas (`LoginPage`, `POSPage`).
- **Widgets**: componentes reutilizables de la feature.
- **Providers**: estado con Riverpod, llaman a los UseCases.

---

## 🗂️ Organización Feature-First

En lugar de agrupar por tipo de archivo (`pages/`, `models/`, `services/` en la raíz), agrupamos por **funcionalidad del negocio**:

```
features/
├── auth/              ← Todo lo de login en un solo lugar
├── usuarios/          ← Todo lo de gestión de usuarios
├── productos/         ← Todo lo de productos
└── ventas/            ← Todo lo del POS
```

Cada feature tiene SU PROPIA estructura de 3 capas:

```
features/ventas/
├── domain/
│   ├── entities/
│   ├── repositories/   (interfaces)
│   └── usecases/
├── data/
│   ├── models/
│   ├── datasources/
│   └── repositories/   (implementaciones)
└── presentation/
    ├── pages/
    ├── widgets/
    └── providers/
```

---

## 🧰 Stack técnico decidido

| Capa | Tecnología | Por qué |
|------|-----------|---------|
| UI Framework | **Flutter Desktop (Windows)** | Multiplataforma, moderno, rápido |
| Estado | **Riverpod 2** | Type-safe, sin BuildContext, fácil de testear |
| Navegación | **GoRouter** | Declarativo, soporta deep links, oficial de Flutter |
| Base de datos | **PostgreSQL** | Soporta múltiples clientes concurrentes (LAN) |
| Driver BD | **`postgres` package** | Cliente nativo Dart para PostgreSQL |
| Modelos | **Freezed + JsonSerializable** | Inmutables, generación automática |
| Inyección | **Riverpod Providers** | No necesitamos GetIt/Injectable |
| Manejo errores | **`dartz` (Either)** | Programación funcional, errores explícitos |

---

## 🌳 Estructura completa de carpetas

```
lib/
│
├── main.dart                         # Punto de entrada
├── bootstrap.dart                    # Init de la app (BD, settings)
│
├── app/                              # Configuración global de la app
│   ├── app.dart                      # Widget raíz (MaterialApp)
│   ├── router.dart                   # Definición de rutas (GoRouter)
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       └── app_text_styles.dart
│
├── core/                             # Código compartido transversal
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── db_constants.dart
│   ├── errors/
│   │   ├── failure.dart              # Clases de error tipadas
│   │   └── exceptions.dart
│   ├── usecases/
│   │   └── usecase.dart              # Clase base abstracta
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── currency_formatter.dart   # Formato Soles (S/.)
│   │   ├── validators.dart           # Validadores de RUC, DNI, etc.
│   │   └── logger.dart
│   └── extensions/
│       ├── string_extensions.dart
│       ├── date_extensions.dart
│       └── context_extensions.dart
│
├── data/                             # Capa de datos compartida
│   ├── database/
│   │   ├── postgres_connection.dart  # Singleton conexión PostgreSQL
│   │   └── migrations/
│   │       └── 001_initial_schema.sql
│   └── local/
│       └── secure_storage.dart       # Sesión/credenciales cifradas
│
├── features/                         # ⭐ Módulos de negocio (Feature-First)
│   │
│   ├── auth/                         # 🔐 Autenticación
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   │
│   ├── usuarios/                     # 👥 Gestión de usuarios
│   ├── proveedores/                  # 🏭 Proveedores
│   ├── productos/                    # 📦 Productos e inventario
│   ├── compras/                      # 🛒 Compras a proveedores
│   ├── ventas/                       # 💰 Punto de venta (POS)
│   ├── cajas/                        # 💵 Cuadre y turnos
│   ├── creditos/                     # 💳 Crédito a trabajadores
│   └── reportes/                     # 📊 Reportes
│
└── shared/                           # Componentes UI reutilizables
    ├── widgets/
    │   ├── app_button.dart
    │   ├── app_text_field.dart
    │   ├── app_data_table.dart
    │   ├── app_loading.dart
    │   ├── app_error_widget.dart
    │   └── app_dialog.dart
    ├── layouts/
    │   ├── main_layout.dart          # Layout con sidebar
    │   └── sidebar.dart
    └── providers/
        └── current_user_provider.dart
```

---

## 🔄 Flujo de datos típico (ejemplo: Login)

```
1. Usuario presiona botón "Login" en LoginPage
                ↓
2. LoginPage llama a authNotifier.login(user, pass)
                ↓
3. AuthNotifier (Riverpod) llama a LoginUseCase
                ↓
4. LoginUseCase llama a AuthRepository.login()  ← interface (Domain)
                ↓
5. AuthRepositoryImpl ejecuta la lógica           ← implementación (Data)
                ↓
6. AuthDataSource hace SELECT en PostgreSQL
                ↓
7. Retorna User model → User entity → UseCase → Notifier → UI
```

En cada paso, si hay error, se retorna un `Failure` tipado (no excepciones).

---

## 📦 Convenciones de nombres

| Tipo | Convención | Ejemplo |
|------|-----------|---------|
| Archivos | snake_case | `login_page.dart` |
| Clases | PascalCase | `LoginPage` |
| Variables/funciones | camelCase | `currentUser` |
| Constantes | lowerCamelCase | `defaultPageSize` |
| Entities | Sustantivo singular | `Usuario`, `Venta` |
| UseCases | Verbo + sustantivo + UseCase | `CrearVentaUseCase` |
| Repositorios | Sustantivo plural + Repository | `VentasRepository` |
| Pages | Nombre + Page | `LoginPage`, `POSPage` |
| Providers | Nombre + Provider | `authProvider` |

---

## ✅ Reglas de oro

1. **El Domain no importa nada de Flutter, ni de Drift, ni de paquetes externos.**
2. **El Domain no importa de Data ni de Presentation.**
3. **Data implementa interfaces que vienen del Domain.**
4. **La UI nunca llama directamente al DataSource — siempre va vía UseCase.**
5. **Una pantalla = una Page. Si crece mucho, se divide en Widgets.**
6. **Los errores se retornan como `Either<Failure, T>`, NO se lanzan excepciones cruzando capas.**
7. **Cada feature debería poder eliminarse borrando su carpeta sin romper el resto.**

---

## 🚀 Cómo agregar una nueva feature

1. Crear carpeta en `lib/features/nueva_feature/`
2. Crear estructura: `domain/`, `data/`, `presentation/`
3. Definir Entity y Repository interface en `domain/`
4. Implementar Repository y DataSource en `data/`
5. Crear Pages y Providers en `presentation/`
6. Agregar ruta en `app/router.dart`
7. Agregar entrada en el sidebar de `shared/layouts/sidebar.dart`

Listo, feature integrada sin tocar ningún otro módulo.
