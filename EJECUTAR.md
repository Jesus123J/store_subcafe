# 🚀 Cómo ejecutar todo el sistema

Guía paso a paso para probar el sistema completo en tu PC. Si Flutter dice "No se pudo conectar al servidor", es porque te falta arrancar el backend.

---

## 🧱 Lo que necesitas (instalado solo 1 vez)

| Software | Versión | Estado |
|----------|---------|--------|
| PostgreSQL | 16+ | Ya instalado |
| Java | 17+ | Ya instalado (tienes Java 22) |
| Maven | 3.9+ | Ya instalado |
| Flutter | 3.40+ | Ya instalado (3.41.9) |
| Visual Studio C++ workload | 2022 o 2026 | Ya instalado |

---

## 🎬 Cada vez que quieras probar — orden estricto

Hay que arrancar **3 cosas en este orden**:

```
   1. PostgreSQL        (servidor de BD)
        ↓
   2. Backend Spring    (API en http://localhost:8080)
        ↓
   3. Flutter           (la app que consume el API)
```

Si saltas el paso 2, Flutter no se puede conectar y verás el error de la captura: *"No se pudo conectar al servidor"*.

---

## ✅ Paso 1 — Verificar PostgreSQL (10 segundos)

PostgreSQL ya está instalado como servicio de Windows, así que **debería estar corriendo solo**. Verifica:

```powershell
Get-Service "postgresql*"
```

Si dice **`Running`** → ✅ todo bien, salta al Paso 2.

Si dice **`Stopped`** → arráncalo:
```powershell
Start-Service "postgresql-x64-16"
```

---

## ✅ Paso 2 — Arrancar el Backend Spring Boot (~25 segundos)

Abre una **terminal nueva** (Git Bash o PowerShell):

```bash
cd "c:/Users/Jesus Gutierrez/Documents/Proyeto_2026/backend"
mvn spring-boot:run
```

⏳ La primera vez tarda ~1 minuto. Las siguientes, ~25 segundos.

**Sabes que está listo cuando ves:**
```
Tomcat started on port 8080 (http) with context path '/api'
Started GestionBodegaApplication in 23.845 seconds
```

🚨 **No cierres esa terminal.** El backend debe quedar corriendo mientras pruebas Flutter.

### 🩺 Verificación rápida

En tu navegador abre:
```
http://localhost:8080/api/swagger-ui.html
```

Si ves la interfaz de Swagger con la lista de endpoints → ✅ backend OK.

---

## ✅ Paso 3 — Arrancar Flutter (~30 segundos)

Abre **OTRA terminal** (deja la del backend abierta):

```bash
cd "c:/Users/Jesus Gutierrez/Documents/Proyeto_2026"
flutter run -d windows
```

⏳ Tarda ~30 segundos en compilar y abrir la ventana.

Cuando abra:
- Usuario: **`admin`**
- Contraseña: **`admin123`**

Click en **Ingresar** y entras a Ventas (POS).

### Atajos mientras Flutter corre

En la terminal donde está Flutter:
- `r` → Hot reload (cambios al instante, sin reiniciar)
- `R` → Hot restart (reinicia la app pero deja el backend)
- `q` → Cerrar Flutter

---

## 🧪 Probar el flujo completo

| # | Acción | Esperado |
|---|--------|----------|
| 1 | Login con `admin / admin123` | Entra al POS |
| 2 | Ir a **Proveedores** | Ves el proveedor "Distribuidora La Bodega SAC" |
| 3 | Ir a **Productos** | Ves los 3 productos demo |
| 4 | Ir a **Usuarios** | Ves admin, vendedor1, encargado1 |
| 5 | Ir a **Ventas** → agregar productos → "Cobrar" | Abre el dialog de pago mixto |
| 6 | Agregar 2 pagos parciales (ej: S/. 5 efectivo + S/. 3 yape) | Solo confirma si suma == total |
| 7 | Elegir Boleta / Factura / Ticket | Numera y guarda en historial |

---

## ⚠️ Errores comunes

### "ApiException(0): No se pudo conectar al servidor"
**Causa:** el backend no está corriendo.
**Solución:** vuelve al Paso 2.

### "401 Unauthorized"
**Causa:** la sesión expiró (token JWT vence en 8h).
**Solución:** cerrar sesión y volver a entrar.

### "Unable to find suitable Visual Studio toolchain"
**Causa:** falta el workload C++ de Visual Studio.
**Solución:** abrir Visual Studio Installer → Modificar → marcar "Desktop development with C++".

### "Migration checksum mismatch for migration version X"
**Causa:** alguien (yo mismo) modificó un archivo de migración SQL después de que ya fue aplicado en BD.
**Solución:** desde la versión actual ya está cubierto — `application.yml` tiene `repair-on-migrate: true`, que actualiza los checksums automáticamente al arrancar.

Si llega a fallar igual:
```powershell
# Pull último código y reintentar
git pull
mvn spring-boot:run
```

Si persiste, manual:
```powershell
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U bodega_user -d gestion_bodega -c "DELETE FROM flyway_schema_history WHERE success = false;"
```

### "Could not connect to PostgreSQL"
**Causa:** el servicio de Postgres está detenido.
**Solución:**
```powershell
Start-Service "postgresql-x64-16"
```

### El error "letra no se ve" que viste en Proveedores
**Causa:** los 2 problemas juntos:
1. Backend no estaba corriendo → no había datos
2. El widget de error tenía letra muy clara

**Solución:** ya está arreglado en la rama `fix/contraste-letras` (PR pronto). Pero igual necesitas arrancar el backend para que la pantalla no muestre error.

---

## 🛠️ Comandos útiles de PostgreSQL

```powershell
# Conectarte a la BD
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U bodega_user -d gestion_bodega
# Password: bodega_pass

# Ver tablas
\dt

# Ver usuarios cargados
SELECT username, rol FROM usuarios;

# Salir
\q
```

---

## 🔄 Reiniciar todo de cero

Si algo se rompe mucho:

```powershell
# 1. Detener Flutter (presiona q en su terminal)

# 2. Detener backend (Ctrl+C en su terminal)

# 3. Limpiar Flutter
cd "c:/Users/Jesus Gutierrez/Documents/Proyeto_2026"
flutter clean
flutter pub get

# 4. Limpiar backend
cd backend
mvn clean

# 5. Volver a Paso 2 → Paso 3
```

---

## 📊 Resumen visual

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   Terminal 1 (Backend)        Terminal 2 (Flutter)      │
│   ─────────────────────       ─────────────────────     │
│   cd backend                  cd Proyeto_2026           │
│   mvn spring-boot:run         flutter run -d windows    │
│                                                         │
│   ⏳ Esperar Started...        ⏳ Esperar ventana...      │
│                                                         │
│   ✅ http://localhost:8080     ✅ App de escritorio      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

🎯 **Regla de oro:** Backend SIEMPRE antes de Flutter. Si Flutter falla "no se pudo conectar", es porque te saltaste el paso 2.
