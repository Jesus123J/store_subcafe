# Manual del proceso: venta a crédito a un trabajador y su reflejo en FinantialTracker

Sistema **Sub Café** (tienda del Hospital San José) + **FinantialTracker** (préstamos y planilla).
Ambos usan **la misma base de datos MySQL** (`financialtracker1`). La tienda registra la venta y la deuda;
FinantialTracker la ve al instante en su menú **DEUDAS TIENDA**.

Fecha de las capturas: 27/09/2026. Todas las pantallas son reales, tomadas con datos de prueba.

---

## 1. Cómo funciona la unión

```
Tienda (Flutter)  →  Backend Spring Boot  →  MySQL financialtracker1  ←  FinantialTracker (Java)
   POS / Deudores       http://localhost:8080/api        clientes, ventas,           menú DEUDAS TIENDA
                                                         creditos_trabajadores       (solo lectura, vía API)
```

| Quién compra | Cómo paga | Qué pasa |
|---|---|---|
| Cliente externo | Efectivo, Yape, Plin o Niubiz | Solo se registra la venta. |
| Trabajador del hospital | **Crédito a trabajador** | Se registra la venta **y** una deuda a su nombre. Aparece en Deudores y en FinantialTracker. |
| Trabajador del hospital | Al contado, identificándose | Se registra la venta y **suma puntos**. |

El padrón de trabajadores viene de FinantialTracker (tabla `employees`) y se sincroniza a la tienda con un botón.

---

## 2. Antes de empezar

1. **Base de datos** (contenedor Docker `mysql-proyectos`):
   `cd ~/Desktop/me/mysql-db && docker compose up -d`
2. **Backend de la tienda**:
   `cd ~/Desktop/me/store_subcafe/backend && ./run.sh` (Windows: `run.cmd`). Listo cuando aparece `Started GestionBodegaApplication`.
3. **App de la tienda** (Flutter): `flutter run -d windows` o `flutter run -d chrome`.
4. **FinantialTracker** (Java): abrir desde NetBeans o el `.exe`. Necesita el backend de la tienda encendido para el menú DEUDAS TIENDA.

Usuarios de la tienda (los del seed; cambiarlos en producción):

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin` | `admin123` | Administrador |
| `encargado1` | `admin123` | Encargado |
| `vendedor1` | `admin123` | Vendedor |

---

## 3. Paso a paso

### Paso 1 · Entrar a la tienda

![Login](capturas/01_login_marcado.png)

1. Escribe el **usuario** (por ejemplo `admin`).
2. Escribe la **contraseña**.
3. Pulsa **Ingresar**. Entras directo al Punto de venta.

### Paso 2 · Tener la caja abierta

Sin caja abierta el botón **Cobrar** queda deshabilitado y el POS muestra un aviso con acceso directo a Cajas.

![Cajas](capturas/03_cajas_marcado.png)

1. Turno activo, vendedor y hora de apertura.
2. Cuadre de efectivo: apertura + ventas en efectivo − avances = efectivo esperado.
3. **Registrar avance**: salidas de efectivo durante el turno.
4. **Cerrar caja** al terminar el turno (la primera vez verás **Abrir caja** con turno DÍA/NOCHE y monto de apertura).

### Paso 3 · Padrón de trabajadores

![Trabajadores](capturas/16_trabajadores_marcado.png)

1. Estado del padrón frente a FinantialTracker (aquí: 1046 empleados sincronizados).
2. **Sincronizar con FinantialTracker**: copia o actualiza a los empleados como trabajadores de la tienda. Se puede repetir las veces que haga falta; nunca borra.
3. Búsqueda por DNI, nombre o condición (Nombrado / CAS).
4. Paginación de 25, 50 o 100 filas.

Cada trabajador queda enlazado a su ficha de empleado (`empleado_id`). Solo los trabajadores pueden comprar a crédito, recibir vales y acumular puntos.

### Paso 4 · Venta a crédito en el Punto de venta

**4.1 Punto de venta**

![POS](capturas/02_pos_marcado.png)

1. Menú **Ventas (POS)**.
2. Toca una tarjeta para agregar el producto al ticket. Muestra precio y stock; los agotados se bloquean.
3. **Identificar trabajador (suma puntos)**: opcional, para ventas al contado de un trabajador.
4. Caja del turno y total vendido.
5. **Cobrar**.

**4.2 Ticket armado**

![Carrito](capturas/04_pos_carrito_marcado.png)

1. La tarjeta indica cuántas unidades van en el ticket.
2. Cambia cantidades con − / +.
3. Total del ticket.
4. **Cobrar** abre la distribución del pago.

**4.3 Distribuir el pago**

![Distribuir](capturas/05_cobrar_dialogo_marcado.png)

1. Pagado / falta / estado. La venta solo se confirma cuando la suma de pagos es exactamente el total.
2. **Agregar pago**. Se pueden combinar varias formas (pago mixto).

**4.4 Elegir Crédito a trabajador**

![Agregar pago](capturas/06_agregar_pago_marcado.png)

1. Forma de pago **Crédito a trabajador**.
2. Monto (por defecto lo que falta cobrar).

![Buscar](capturas/07_credito_buscar_marcado.png)

1. Aparece el buscador **Trabajador que asume la deuda**. Escribe DNI o parte del nombre.

![Resultados](capturas/08_credito_resultados_marcado.png)

1. Solo se listan trabajadores activos del padrón. Toca al correcto.

![Elegido](capturas/09_credito_trabajador_elegido_marcado.png)

1. Trabajador seleccionado (DNI, condición y número de empleado en FinantialTracker).
2. **Agregar**.

Si el pago es CRÉDITO y no se elige trabajador, el sistema no deja continuar. Para un cliente externo se usa otra forma de pago.

**4.5 Confirmar la venta**

![Pago listo](capturas/10_pago_credito_listo_marcado.png)

1. Pago a crédito con el nombre del trabajador que asume la deuda.
2. Estado **COMPLETO**.
3. **Confirmar venta**.

![Comprobante](capturas/11_comprobante_marcado.png)

1. Tipo de comprobante (Ticket, Boleta o Factura).
2. **Confirmar venta**.

![Confirmada](capturas/12_venta_confirmada_marcado.png)

1. "Ticket registrada · deuda anotada": la venta quedó guardada y el stock descontado.
2. Trabajador identificado (también suma puntos).
3. Aviso: la deuda ya aparece en Deudores y entrará al próximo cierre mensual.
4. **Imprimir comprobante** (PDF).

**4.6 Historial del turno**

![Historial](capturas/13_historial_turno_marcado.png)

1. Alterna a **Historial del turno**: cada venta con su forma de pago, etiqueta CRÉDITO y el trabajador que debe. Desde aquí se reimprime o se anula (la anulación devuelve el stock y borra la deuda si aún no se cerró el mes).

### Paso 5 · Ver la deuda en Deudores

![Deudores](capturas/14_deudores_marcado.png)

1. Totales: trabajadores con deuda, pendiente del mes, acumulado de meses cerrados y deuda total.
2. Estado de la unión con FinantialTracker.
3. Cada fila es un trabajador con deuda viva. Toca la fila para ver su estado de cuenta.
4. **Anotar deuda**: para consumos que no pasaron por el POS.

![Detalle deudor](capturas/14b_deudor_detalle_marcado.png)

1. Cabecera con pendiente del mes, acumulado y total.
2. Consumos a crédito: qué compró, cuándo, quién lo registró y si ya entró a un cierre.
3. Cierres mensuales en los que participó y su estado hacia planilla.

![Anotar deuda](capturas/14c_anotar_deuda_marcado.png)

1. El mismo buscador de trabajadores de todo el sistema.
2. Monto.
3. **Guardar deuda**.

### Paso 6 · Créditos y cierre de mes

![Créditos](capturas/15_creditos_marcado.png)

1. Ciclo actual y fecha del próximo cierre.
2. Créditos del mes por trabajador (lo que se trasladará a deuda al cerrar).
3. **Cerrar mes** (solo administrador o encargado). Al cerrar:
    - se suma lo pendiente por trabajador y pasa a **deuda acumulada**;
    - se guarda un detalle del cierre por trabajador (`cierre_creditos_detalle`), que es lo que irá a planilla;
    - el envío del descuento a FinantialTracker (crear el `abono` con el concepto **DESCUENTOS CREDITO BAZAR**) está programado pero **desactivado**. Se activa con la clave `finantial.exportar_al_cerrar = true` en Configuración cuando se decida unir el descuento.

### Paso 7 · Verlo en FinantialTracker

![FT login](capturas/30_ft_login.png)

Entra a FinantialTracker con tu usuario habitual.

![FT principal](capturas/31_ft_principal.png)

En la barra de menús hay una opción nueva: **DEUDAS TIENDA**, antes de "Cerrar sesión".

![FT deudas](capturas/32_ft_deudas_tienda_marcado.png)

1. Menú **DEUDAS TIENDA**.
2. Los mismos totales que la pestaña Deudores de la tienda.
3. La trabajadora de la venta del Paso 4 (ACUÑA AUCCAHUASI, S/. 9.00) ya aparece. Al hacer clic se listan sus compras abajo.
4. **Auto-actualizar (10 s)**: la ventana se refresca sola; también hay botón Actualizar y búsqueda por DNI o nombre.

![FT compras](capturas/33_ft_compras_credito_marcado.png)

1. Pestaña **Compras a crédito**: cada venta a crédito del POS o deuda anotada a mano, en orden de llegada, con origen y estado.
2. La compra de S/. 9.00 registrada minutos antes en la tienda.

La tercera pestaña, **Cierres mensuales (planilla)**, muestra el total por trabajador de cada mes cerrado y su estado en FinantialTracker.

Esta ventana es de **solo lectura**: FinantialTracker consume la API de la tienda (`http://localhost:8080/api`) y no modifica sus tablas. Si el backend está apagado, el pie de la ventana lo indica.

---

## 4. Los demás registros de la tienda

| Pantalla | Qué se registra | Captura |
|---|---|---|
| Productos | Catálogo con precio vigente, stock, mínimo, tipo (producto / servicio / bazar). Alta y edición; un cambio de precio guarda historial. | ![](capturas/17_productos.png) |
| Proveedores | Razón social, RUC, dirección, teléfono. Alta y edición. | ![](capturas/18_proveedores.png) |
| Compras | Compras a proveedores: suben el stock y registran el nuevo costo. | ![](capturas/19_compras_marcado.png) ![](capturas/19b_registrar_compra.png) ![](capturas/19c_detalle_compra.png) |
| Puntos | Regla de puntos (soles por punto), saldos por trabajador y catálogo de productos del bazar canjeables. | ![](capturas/20_puntos_marcado.png) ![](capturas/20b_agregar_canjeable.png) |
| Vales | Vales al portador (CASH) o nombrados a un trabajador, con vencimiento opcional. | ![](capturas/21_vales.png) |
| Usuarios del sistema | Quién entra a la caja y con qué rol. | ![](capturas/22_usuarios.png) |
| Configuración | Datos del negocio, Yape/Plin, impresora y claves de la unión con FinantialTracker. | ![](capturas/23_configuracion.png) |
| Reportes | Ventas por día, forma de pago y turno; stock y productos más vendidos. | ![](capturas/24_reportes.png) |
| Trabajadores · nuevo | Alta manual de un trabajador que no esté en el padrón. | ![](capturas/16b_nuevo_trabajador.png) |

---

## 5. Resumen del recorrido de una deuda

1. El trabajador compra en el POS y paga con **Crédito a trabajador** → `ventas` + `creditos_trabajadores`.
2. Aparece en **Deudores** (tienda) y en **DEUDAS TIENDA** (FinantialTracker) en menos de 10 segundos.
3. A fin de mes, **Cerrar mes** en Créditos → `deuda_trabajadores` + `cierre_creditos_detalle`.
4. Cuando se active la unión, cada fila del cierre se convierte en un **abono** de FinantialTracker y se descuenta por planilla; el `abono.ID` queda guardado en la tienda para no duplicar y para ver si ya se pagó.
