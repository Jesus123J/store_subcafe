# Sistema de Gestión - Bodega / Fotocopiadora

Aplicación de **escritorio (Windows)** desarrollada en **Flutter Desktop** para administración de ventas, compras, stock, cajas y reportes.

---

## 📋 Módulos del sistema

- **Usuarios** — Vendedores, Encargados, Administrador (roles y permisos)
- **Proveedores** — Razón Social, RUC, Dirección
- **Productos** — Descripción, costo/precio histórico, stock, stock mínimo, mermas
- **Módulo de Compras** — Registro de compras, fotocopias (A4, A3, DNI, impresiones), contómetro
- **Módulo de Ventas** — Punto de venta, formas de pago, turnos
- **Formas de pago** — Efectivo, Yape, Plin, Niubiz, Crédito a trabajadores
- **Cajas** — Cuadre de caja, avance de efectivo, turnos día/noche, correcciones
- **Reportes** — Ventas diarias por forma de pago, stock con costo/precio

---

## 🛠️ Stack tecnológico

- **Framework:** Flutter Desktop (Windows)
- **Lenguaje:** Dart
- **Base de datos:** SQLite local (Drift)
- **Estado:** Riverpod
- **Navegación:** GoRouter
- **Plataforma objetivo:** Windows 10/11

---

## ⚙️ Requisitos previos

1. **Flutter SDK** ≥ 3.16 con soporte de escritorio habilitado:
   ```bash
   flutter config --enable-windows-desktop
   ```
2. **Visual Studio 2022** con el workload *"Desktop development with C++"* (requerido por Flutter Windows).
3. **Git** para control de versiones.

---

## 📦 Librerías recomendadas (Compatibles con Windows Desktop)

### 🗄️ Base de datos y almacenamiento
| Librería | Uso |
|----------|-----|
| `drift` | ORM sobre SQLite con tipado fuerte (recomendado) |
| `sqlite3_flutter_libs` | Binarios SQLite para Windows |
| `path_provider` | Rutas del sistema (AppData, Documents) |
| `path` | Manipulación de rutas |
| `shared_preferences` | Configuraciones simples (turno actual, sesión) |
| `flutter_secure_storage` | Tokens y datos sensibles cifrados (soporta Windows) |

### 👥 Autenticación y usuarios
| Librería | Uso |
|----------|-----|
| `bcrypt` | Hash seguro de contraseñas |
| `crypto` | Funciones criptográficas (SHA, MD5) |
| `uuid` | IDs únicos para registros |

> ⚠️ `local_auth` (biometría) tiene soporte limitado en Windows — se omite.

### 🏗️ Arquitectura y estado
| Librería | Uso |
|----------|-----|
| `flutter_riverpod` | Manejo de estado (recomendado) |
| `go_router` | Navegación declarativa con rutas |
| `freezed_annotation` | Modelos inmutables |
| `json_annotation` | Serialización JSON |
| `build_runner` | Generador de código (dev) |

### 💰 Códigos de barras y QR
| Librería | Uso |
|----------|-----|
| `qr_flutter` | Generar QR para Yape/Plin (mostrar al cliente) |
| `barcode_widget` | Generar códigos de barras para productos/tickets |
| `flutter_barcode_scanner_keyboard` | Capturar entrada de **lector USB tipo HID** (recomendado para escritorio) |

> 💡 En escritorio lo más común es un **lector de código de barras USB** que actúa como teclado: simplemente se captura el input en un `TextField`. No requiere librería de cámara.

### 🖨️ Impresión de tickets y boletas
| Librería | Uso |
|----------|-----|
| `esc_pos_printer` | Impresoras térmicas por red (LAN/WiFi) — funciona en Windows |
| `esc_pos_utils` | Comandos ESC/POS |
| `printing` | Impresión en impresoras estándar instaladas en Windows |
| `pdf` | Generación de archivos PDF |
| `win32` | Acceso directo a APIs de Windows (impresión avanzada si se necesita) |

### 📊 Reportes y exportación
| Librería | Uso |
|----------|-----|
| `fl_chart` | Gráficos de barras, líneas, tortas |
| `syncfusion_flutter_charts` | Gráficos avanzados (alternativa) |
| `excel` | Exportar/leer archivos Excel (.xlsx) |
| `csv` | Exportar a CSV |
| `intl` | Formato de fechas, números y moneda (soles) |
| `data_table_2` | Tablas avanzadas para reportes |

### 🎨 Interfaz de usuario (UI Desktop)
| Librería | Uso |
|----------|-----|
| `fluent_ui` | **Estilo nativo Windows 11** (recomendado para escritorio) |
| `flex_color_scheme` | Temas personalizados si prefieres Material |
| `google_fonts` | Tipografías personalizadas |
| `sidebarx` | Menú lateral animado |
| `gap` | Espaciados rápidos en layouts |
| `flutter_svg` | Renderizar imágenes SVG |
| `fluttertoast` | Notificaciones tipo toast |
| `awesome_dialog` | Diálogos personalizados |
| `window_manager` | Control de la ventana (tamaño, posición, título, minimizar al tray) |
| `system_tray` | Icono en bandeja del sistema de Windows |
| `hotkey_manager` | Atajos de teclado globales (útil en punto de venta) |

### 🔄 Backups y archivos
| Librería | Uso |
|----------|-----|
| `file_picker` | Seleccionar archivos/carpetas (soporta Windows) |
| `file_selector` | Alternativa oficial de Flutter para diálogos de archivo |
| `share_plus` | Compartir archivos |
| `archive` | Comprimir/descomprimir ZIP (para backups) |
| `open_file` | Abrir archivos con la app por defecto de Windows |

### 🔧 Utilidades
| Librería | Uso |
|----------|-----|
| `logger` | Logs formateados para debugging |
| `equatable` | Comparación de objetos por valor |
| `collection` | Utilidades para listas y mapas |
| `connectivity_plus` | Detectar conexión a internet (soporta Windows) |
| `package_info_plus` | Información de la app |
| `url_launcher` | Abrir URLs en navegador |

---

## 📄 pubspec.yaml recomendado

```yaml
name: gestion_bodega
description: Sistema de gestión de escritorio para bodega y fotocopiadora
version: 1.0.0+1
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6

  # Base de datos
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  path_provider: ^2.1.1
  path: ^1.8.3
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0

  # Autenticación
  bcrypt: ^1.1.3
  crypto: ^3.0.3
  uuid: ^4.2.1

  # Estado y navegación
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

  # Códigos
  qr_flutter: ^4.1.0
  barcode_widget: ^2.0.4

  # Impresión
  esc_pos_printer: ^4.1.0
  esc_pos_utils: ^1.1.0
  printing: ^5.11.1
  pdf: ^3.10.7
  win32: ^5.0.9

  # Reportes
  fl_chart: ^0.66.0
  excel: ^4.0.2
  csv: ^5.1.1
  intl: ^0.19.0
  data_table_2: ^2.5.11

  # UI Desktop
  fluent_ui: ^4.8.5
  flex_color_scheme: ^7.3.1
  google_fonts: ^6.1.0
  sidebarx: ^0.17.1
  gap: ^3.0.1
  flutter_svg: ^2.0.9
  fluttertoast: ^8.2.4
  awesome_dialog: ^3.2.1
  window_manager: ^0.3.7
  system_tray: ^2.0.3
  hotkey_manager: ^0.2.3

  # Archivos y backup
  file_picker: ^6.1.1
  file_selector: ^1.0.3
  share_plus: ^7.2.1
  archive: ^3.4.10
  open_file: ^3.3.2

  # Utilidades
  logger: ^2.0.2+1
  equatable: ^2.0.5
  collection: ^1.18.0
  connectivity_plus: ^5.0.2
  package_info_plus: ^5.0.1
  url_launcher: ^6.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  build_runner: ^2.4.7
  drift_dev: ^2.14.0
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  msix: ^3.16.7  # Empaquetar como instalador .msix para Windows

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

---

## 🗂️ Estructura de carpetas sugerida

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── constants/
│   ├── utils/
│   └── errors/
├── data/
│   ├── database/        # Drift DB
│   ├── models/
│   └── repositories/
├── features/
│   ├── auth/
│   ├── usuarios/
│   ├── proveedores/
│   ├── productos/
│   ├── compras/
│   ├── ventas/
│   ├── cajas/
│   └── reportes/
└── shared/
    ├── widgets/
    └── providers/
windows/                 # Configuración Windows (autogenerada)
assets/
├── images/
└── icons/
```

---

## 🚀 Instalación y ejecución

```bash
# Habilitar Windows Desktop
flutter config --enable-windows-desktop

# Crear proyecto (si aún no existe)
flutter create --platforms=windows .

# Instalar dependencias
flutter pub get

# Generar código (Drift, Freezed, JSON)
flutter pub run build_runner build --delete-conflicting-outputs

# Ejecutar en Windows
flutter run -d windows
```

---

## 📦 Empaquetar como instalador (.msix / .exe)

### Opción 1 — MSIX (recomendado, instalador moderno)
```bash
flutter pub run msix:create
```
Configurar en `pubspec.yaml`:
```yaml
msix_config:
  display_name: Gestión Bodega
  publisher_display_name: Tu Empresa
  identity_name: com.tuempresa.gestionbodega
  msix_version: 1.0.0.0
  logo_path: assets/icons/app_icon.png
```

### Opción 2 — Inno Setup (instalador `.exe` clásico)
1. Compilar release: `flutter build windows --release`
2. Usar [Inno Setup](https://jrsoftware.org/isinfo.php) para empaquetar la carpeta `build/windows/x64/runner/Release/`.

---

## 📅 Roadmap de desarrollo

| Fase | Módulo | Estado |
|------|--------|--------|
| 1 | Base (login, roles, BD, navegación, ventana) | ⏳ Pendiente |
| 2 | Maestros (Proveedores, Productos) | ⏳ Pendiente |
| 3 | Módulo Compras | ⏳ Pendiente |
| 4 | Módulo Ventas (POS) | ⏳ Pendiente |
| 5 | Cajas y turnos | ⏳ Pendiente |
| 6 | Reportes y exportación | ⏳ Pendiente |
| 7 | Pulido (UI Fluent, impresión, backups, atajos) | ⏳ Pendiente |
| 8 | Empaquetado e instalador | ⏳ Pendiente |

---

## 📝 Notas técnicas

- **Hardware típico:** PC Windows + impresora térmica (USB o red) + lector de código de barras USB (HID).
- **Yape / Plin / Niubiz:** se registran manualmente (no hay API pública para pequeños comercios).
- **Contómetro de fotocopiadora:** se ingresa manualmente al inicio y fin de turno.
- **Créditos a trabajadores:** se cierran a fin de mes y se suman a la deuda total.
- **Base de datos:** se guarda en `%APPDATA%\gestion_bodega\` por defecto.
- **Backups:** se recomienda exportar la BD a ZIP automáticamente al cerrar la app.
- **Multi-ventana:** posible usar `window_manager` para abrir reportes en ventanas separadas.
