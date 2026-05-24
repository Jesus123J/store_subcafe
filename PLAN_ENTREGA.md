# 📋 PLAN DE ENTREGA — Sistema Gestión Bodega

> Documento maestro del proyecto: qué está listo, qué falta, decisiones pendientes y pasos para la entrega final a la clienta.

---

## ✅ ESTADO ACTUAL (lo que ya funciona)

### 🖥️ Frontend (Flutter Desktop Windows)
- ✅ App compilable a `.exe` Windows (Visual Studio Enterprise 2026 + C++ workload)
- ✅ Versión web funcional en Chrome (para demo rápida)
- ✅ **Login** conectado al backend con JWT real (admin/admin123)
- ✅ **Modo Demo** para probar sin backend
- ✅ Arquitectura **Clean + Feature-First** con Riverpod + GoRouter + Dio
- ✅ **8 módulos** con UI funcional:
  - **Ventas (POS)**: catálogo con grid, carrito, 5 formas de pago, tipos de comprobante (Boleta/Factura/Ticket), QR Yape/Plin, código de operación
  - **Productos**: lista, búsqueda, alertas stock bajo, form nuevo producto
  - **Proveedores**: lista, form nuevo (RUC validado)
  - **Compras**: lista con detalles, form nueva compra
  - **Cajas**: turno actual con cuadre automático, apertura/cierre, avances, contómetro
  - **Créditos**: lista por trabajador expandible, cierre de mes
  - **Reportes**: dashboard con métricas + gráficos línea/torta + top productos + stock bajo
  - **Usuarios**: CRUD completo conectado al backend (crear/editar/desactivar)
- ✅ **Exportación PDF + Excel + Imprimir** en Reportes, Cajas, Créditos
- ✅ **Comprobantes**: numeración correlativa por tipo (B001-000001, F001-000001, T001-000001)
- ✅ **Historial del turno** en Ventas con reimpresión
- ✅ Texto siempre legible (tema oscuro forzado)
- ✅ Transiciones suaves (fade 120ms)

### ⚙️ Backend (Spring Boot 3.3 + Java 17 + PostgreSQL)
- ✅ Estructura Maven, compilable y ejecutable (`mvn spring-boot:run`)
- ✅ **PostgreSQL** configurado con `bodega_user / bodega_pass`
- ✅ **Flyway**: migración V1 (13 tablas + enums + índices) y V2 (datos iniciales)
- ✅ **JWT + Spring Security** con roles (ADMINISTRADOR / ENCARGADO / VENDEDOR)
- ✅ **Swagger UI** en `/api/swagger-ui.html`
- ✅ **CORS** configurado para Flutter
- ✅ **Endpoints implementados**:
  - `POST /auth/login` ✅ funciona
  - `GET/POST/PUT/DELETE /usuarios` ✅ CRUD completo
  - `GET /proveedores`, `/productos`, `/ventas`, `/compras`, `/cajas`, `/creditos` ✅ solo listar
- ✅ **Entidades JPA** mapeadas para todos los módulos
- ✅ **Manejo de errores** global con `ApiResponse<T>`

### 📦 Documentación entregable
- ✅ `Propuesta_Comercial.pdf` — para enviar a la clienta
- ✅ `README.md` — librerías + cómo correr
- ✅ `ARCHITECTURE.md` — explicación de la arquitectura
- ✅ `backend/README.md` — guía del backend

---

## ⚠️ LO QUE FALTA PARA ENTREGAR

### 🔴 CRÍTICO (sin esto NO se puede entregar)

#### Backend — completar CRUD de los módulos restantes
Actualmente solo `Usuarios` tiene CRUD completo. Hay que agregar:

| Módulo | Endpoints faltantes | Tiempo estimado |
|--------|--------------------|-----------------|
| Proveedores | POST/PUT/DELETE + Service + DTOs | 2-3 horas |
| Productos | POST/PUT/DELETE + lógica histórico precios | 4-5 horas |
| Compras | POST con lógica de actualizar stock + DTOs | 5-6 horas |
| **Ventas (POS)** | POST con descuento de stock + crédito + tipo comprobante | 8-10 horas |
| Cajas | Apertura/cierre/avance + lógica cuadre | 4-5 horas |
| Créditos | POST + cierre mensual automático | 3-4 horas |
| Reportes | Queries agregadas reales (ventas, stock, créditos) | 5-6 horas |

**Total estimado:** ~30-40 horas de backend

#### Migración del schema con campos nuevos
- `ventas.tipo_comprobante`, `cliente_doc`, `cliente_nombre`, `cliente_direccion`, `codigo_operacion`
- Nueva migración Flyway V3

#### Frontend — conectar todo al backend real
- Reemplazar listas mock de Ventas (catálogo) con API real
- Reemplazar mock de Compras con API
- Reemplazar mock de Cajas con API
- Reemplazar mock de Créditos con API
- Reemplazar mock de Reportes con API

**Tiempo estimado:** ~15-20 horas

#### Instalación en local de la clienta
- PostgreSQL en una PC (servidor de BD)
- Backend Spring Boot corriendo como servicio Windows
- Configurar IP del servidor en cada PC cliente
- Generar instalador `.msix` o `.exe` de Flutter
- Probar conexión en red local

**Tiempo estimado:** ~6-8 horas

### 🟡 IMPORTANTE (recomendado para entrega profesional)

- **Configuración por archivo**: hoy las URLs del backend y datos del comerciante están hardcodeados. Pasar a archivo de config `.env` o pantalla de "Configuración" en la app
- **Pantalla de Configuración**: para que el Administrador pueda cambiar:
  - URL del backend
  - Datos del comerciante (razón social, RUC, dirección, teléfono)
  - QR de Yape/Plin del comerciante (subir imagen)
  - Datos de la impresora térmica
- **Manual de usuario** en PDF con capturas de pantalla
- **Backups automáticos** de la BD (script diario)
- **Logs separados** por nivel (info/error) en archivos

### 🟢 OPCIONAL (puede ir en una v2)

- Integración real con **Yape Negocios PRO** (API webhooks) — requiere afiliación BCP
- Integración real con **Niubiz** (POS tarjeta) — requiere terminal físico
- App móvil para que la dueña vea reportes desde el celular
- Modo "Solo lectura" para que el contador vea datos
- Notificaciones cuando stock cae bajo el mínimo

---

## 💸 COSTOS OPERATIVOS POST-ENTREGA

### Lo que tu clienta SÍ paga
| Concepto | Costo | Frecuencia |
|----------|-------|------------|
| Cuenta BCP empresarial | S/. 0 - S/. 30 | Mensual (depende del paquete) |
| Comisiones Yape Negocios PRO (si lo activa) | ~1.5% - 2.5% por venta | Por transacción |
| Comisiones Niubiz (si usa POS tarjeta) | ~3% - 4% por venta | Por transacción |
| Impresora térmica | S/. 250 - S/. 450 | Compra única |
| Lector código de barras USB | S/. 100 - S/. 200 | Compra única |

### Lo que NO paga
| Concepto | Costo |
|----------|-------|
| Software desarrollado | S/. 0 (ya pagó por la entrega) |
| Licencias mensuales | S/. 0 (sin SaaS) |
| PostgreSQL | S/. 0 (gratis y open source) |
| Yape Negocios básico | S/. 0 |

### Soporte (opcional, lo cobras tú)
| Plan | Incluye | Costo mensual |
|------|---------|---------------|
| Básico | Correcciones de errores + respaldo remoto | S/. 150 |
| Plus | Lo anterior + ajustes menores + reportes adicionales | S/. 250 |
| Pro | Lo anterior + nuevos módulos pequeños | S/. 400 |

---

## 🚀 ROADMAP DE 4 FASES PARA TERMINAR

### Fase A — Completar Backend (5-7 días)
1. Implementar POST/PUT/DELETE en cada módulo (Proveedores, Productos, Compras, Ventas, Cajas, Créditos)
2. Lógica de negocio:
   - Ventas: descontar stock + registrar crédito si forma_pago=CREDITO
   - Compras: actualizar stock + crear `producto_precios`
   - Cajas: validar que solo haya una caja abierta por usuario
3. Endpoints de reportes con queries agregadas
4. Migración V3: agregar campos de comprobante a `ventas`
5. Tests básicos de cada endpoint

### Fase B — Conectar Frontend al Backend (3-5 días)
1. Eliminar datos mock de cada página
2. Crear DataSources + Providers para cada módulo
3. Conectar formularios al POST/PUT del backend
4. Manejo de errores con `ApiException`
5. Reemplazar el modelo `_ProductoDemo` del POS con productos reales del backend

### Fase C — Configuración y Pantalla de Settings (2-3 días)
1. Pantalla `/configuracion` con secciones:
   - **Negocio**: razón social, RUC, dirección
   - **QR Pagos**: subir imagen QR Yape + QR Plin
   - **Conexión**: URL del backend, timeout
   - **Impresora**: IP + puerto de impresora térmica
2. Guardar config en BD (tabla `configuracion`)
3. Reemplazar valores hardcodeados (BODEGA LA CONFIANZA, números, etc.)

### Fase D — Instalación y Capacitación (2-3 días)
1. **En la tienda de la clienta:**
   - Instalar PostgreSQL en la PC del Administrador
   - Configurar como servicio Windows (auto-arranque)
   - Configurar IP estática (`192.168.1.100` típico)
2. **Backend como servicio:**
   - Crear `gestion-bodega.jar` con `mvn clean package`
   - Configurar como servicio Windows con `nssm` o Task Scheduler
3. **Frontend en cada PC:**
   - Instalar `.msix` o copiar `.exe` desde `build/windows/x64/runner/Release/`
   - Configurar URL del backend al arrancar primera vez
4. **Datos maestros:**
   - Cargar productos reales de la bodega (Excel → import)
   - Cargar proveedores
   - Crear usuarios reales (Vendedores, Encargados)
5. **Capacitación al personal** (4 horas):
   - Sesión 1: Vendedores — usar el POS
   - Sesión 2: Encargados — cuadre de caja, reportes, correcciones
   - Sesión 3: Administrador — gestión de usuarios, productos, backups

**Total tiempo restante estimado:** 12-18 días hábiles

---

## 🔧 SETUP TÉCNICO PARA ENTREGAR

### Hardware mínimo en la bodega
| Equipo | Especificación mínima | ¿Quién lo provee? |
|--------|----------------------|-------------------|
| PC servidor (Administrador) | i3 / 8GB RAM / 256GB SSD / Windows 10/11 | Cliente |
| PC vendedor (cada caja) | i3 / 4GB RAM / 128GB SSD / Windows 10/11 | Cliente |
| Router WiFi local | Cualquier router doméstico | Cliente |
| Impresora térmica | 80mm USB o red (ej: Epson TM-T20) | Cliente |
| Lector código barras | USB tipo HID | Cliente (opcional) |

### Red local
- Todas las PCs en la misma red WiFi/Ethernet
- IP estática para el servidor (ej: `192.168.1.100`)
- Puerto `8080` abierto en el firewall del servidor

### Backups
- Script PowerShell diario: `pg_dump gestion_bodega > backup_YYYYMMDD.sql`
- Programado en Task Scheduler a las 2 AM
- Copia automática a USB o Google Drive (opcional)

---

## 📞 TEMAS QUE DEBEMOS CONVERSAR

Antes de seguir, necesito que decidas/me confirmes estos puntos:

### 1. 💰 Cobranza al cliente
- ¿La clienta ya pagó la cuota inicial (50%)?
- ¿Cuándo entregamos el sistema? Define fecha límite para presionarnos
- ¿Vas a ofrecerle soporte mensual (S/. 150-250/mes)?

### 2. 🔌 Yape/Plin/Niubiz
- ¿La clienta tiene RUC?
- ¿Tiene cuenta BCP empresarial o está dispuesta a abrirla?
- ¿Le interesa Yape Negocios PRO con API? (mejor experiencia, comisión ~2%)
- ¿O prefiere quedarse con el flujo manual (gratis, vendedor escribe código)?
- ¿Va a usar Niubiz (terminal de tarjeta)?

### 3. 🏪 Datos del negocio
Necesito que me pases (o le pidas a la clienta):
- Razón social exacta
- RUC
- Dirección fiscal
- Teléfono
- Logo (opcional, para los PDFs de comprobantes)
- Foto del QR de Yape (cuando lo afilie)

### 4. 🖥️ Setup técnico en la tienda
- ¿Cuántas PCs van a usar el sistema? (1 sola, 2, 3...?)
- ¿Ya tienen las PCs o hay que recomendar?
- ¿Tienen WiFi en la bodega? ¿Bueno o lento?
- ¿Quién va a manejar el servidor (BD)? ¿La dueña o un familiar?
- ¿Tienen impresora térmica? Marca/modelo

### 5. 👥 Capacitación
- ¿Cuántos vendedores/encargados se van a capacitar?
- ¿Capacitación presencial en la tienda o remota?
- ¿Cuándo se puede agendar?

### 6. 📦 Datos iniciales
- ¿Tienen ya un listado de productos en Excel? (para importarlo)
- ¿O hay que cargarlos manualmente uno por uno?
- ¿Listado de proveedores?
- ¿Saldos iniciales de créditos a trabajadores?

### 7. 🛠️ Funcionalidades extra
- ¿Algo del bosquejo original que no esté cubierto?
- ¿Algo nuevo que se le ocurrió a la clienta después?
- ¿Necesita reportes específicos al contador?

### 8. 🚀 Estrategia de despliegue
- **Opción A**: Entregar versión "MVP" (modo demo) ahora para que se familiarice, y completar backend en paralelo
- **Opción B**: Esperar a tener todo conectado al backend, entregar versión "estable" en 3 semanas
- **Opción C**: Entregar por módulos (primero Productos+Proveedores, luego Ventas, luego Reportes)

---

## 📁 ARCHIVOS DEL PROYECTO

```
Proyeto_2026/
├── 📄 Propuesta_Comercial.pdf       ← PARA ENVIAR A LA CLIENTA
├── 📋 PLAN_ENTREGA.md               ← ESTE DOCUMENTO
├── 📋 README.md                     ← Documentación de librerías Flutter
├── 📋 ARCHITECTURE.md               ← Arquitectura Flutter
├── 📁 lib/                          ← Código Flutter
├── 📁 windows/                      ← Runner C++ para .exe Windows
├── 📁 web/                          ← Versión web (Chrome)
├── 📁 backend/                      ← API Spring Boot
│   ├── 📋 README.md                 ← Cómo correr el backend
│   ├── 📋 pom.xml
│   └── 📁 src/main/
│       ├── java/com/thiago/gestionbodega/
│       └── resources/
│           ├── application.yml
│           └── db/migration/V1, V2
└── 📁 build/windows/x64/runner/Debug/gestion_bodega.exe
```

---

## 🎯 CRONOGRAMA DEFINIDO (decisión 18-mayo-2026)

### Estrategia híbrida: 2 fases de entrega

```
HOY (18/05)         31/05/2026                    21/06/2026
  │                    │                              │
  ├── 13 días ────────►├── 21 días ──────────────────►│
  │                    │                              │
  │  Desarrollo MVP    │  Backend completo +          │
  │  + UI pulida       │  conexión real +             │
  │  + flujos demo     │  instalación + capacitación  │
  │                    │                              │
  │                  ENTREGA 1:                    ENTREGA 2:
  │                  Versión Demo                  Versión Producción
  │                  (UI navegable)                (sistema real)
  │
  └─ COBRO INICIAL S/. 3,000 (50%) ANTES de empezar
                              ↓
                       30% al entregar Demo (31/05)
                              ↓
                       20% al entregar Producción (21/06)
```

### Hitos de cobranza

| Fecha | Hito | Cobranza |
|-------|------|----------|
| **Esta semana** | **Confirmación + cuota inicial** | **S/. 3,000 (50%)** |
| 31/mayo/2026 | Entrega versión Demo | S/. 1,800 (30%) |
| 21/junio/2026 | Entrega versión Producción | S/. 1,200 (20%) |
| **Total** | | **S/. 6,000** |

### 🛑 NO arrancar fase intensiva sin cobrar inicial

Decisión firme: el desarrollo intensivo de las 60-80 horas restantes inicia **únicamente cuando llegue el depósito de los S/. 3,000**. Te protege ante:
- Que la clienta se arrepienta o cambie de opinión
- Que desaparezca sin pagar
- Que pretenda renegociar al final

### 📧 Próximos 2 pasos inmediatos

1. **HOY o mañana**: enviar el correo formal a la clienta → ver [CORREO_CLIENTA.md](CORREO_CLIENTA.md)
2. **Esperar respuesta + depósito** (3-5 días hábiles según plan B del correo)
3. **Día que llegue el depósito**: arrancar **Fase A — Completar Backend**

### 📊 Distribución de las próximas 5 semanas

```
Semana 1 (19-25 mayo):  Backend CRUDs (Productos, Proveedores, Compras)
Semana 2 (26-31 mayo):  Backend Ventas + Cajas → ENTREGA DEMO el 31/05
Semana 3 (1-7 junio):   Frontend conexión real + DataSources
Semana 4 (8-14 junio):  Pantalla de Configuración + datos de la clienta
Semana 5 (15-21 junio): Instalación en local + capacitación → ENTREGA FINAL
```

Una vez decididos esos 3, procedemos con la **Fase A: completar el Backend** que es lo más crítico.
