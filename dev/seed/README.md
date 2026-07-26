# Datos de prueba (seed)

Scripts para poblar ambas bases de datos y probar el flujo end-to-end
**bodega → cierre mensual → envío a FinantialTracker**.

## Orden y comandos

Asumiendo MariaDB en `localhost:3306`.

### 1. Arranca el backend de la bodega al menos una vez

Para que Flyway cree todas las tablas (V1..V8):

```bash
cd backend
mvn spring-boot:run
```

Cuando veas `Started GestionBodegaApplication`, mátalo con Ctrl+C. Ya
están todas las tablas creadas.

### 2. Corre el seed del FinantialTracker

Asegúrate primero de que la BD `financialtracker1` exista y tenga las
tablas de FT creadas (levanta el `.exe` de FinantialTracker una vez si
no las tienes).

```bash
mysql -u root financialtracker1 < dev/seed/01-financialtracker-seed.sql
```

Esto crea:
- Empleado **12345678 · Juan Perez Test** (NOMBRADO)
- Empleado **87654321 · Maria Garcia Test** (CAS)
- Concepto de servicio **"CONSUMO BODEGA"**

Al final el script te imprime el `service_concept_id` que debes usar.
Si no es 1, ajusta en `backend/src/main/resources/application.yml`:

```yaml
integracion:
  financialtracker:
    service-concept-id: 2   # el ID que te devolvio el script
```

O usa la variable de entorno `FT_SERVICE_CONCEPT_ID` sin tocar el YAML.

### 3. Corre el seed de la bodega

```bash
mysql -u bodega_user -pbodega_pass gestion_bodega < dev/seed/02-gestion-bodega-seed.sql
```

Esto crea:
- Cliente-trabajador **12345678 · Juan Perez Test**
- Cliente-trabajador **87654321 · Maria Garcia Test**
- Producto **DEMO001 · Galleta Demo** (bazar, S/. 1.50, stock 100)

**Nota**: el usuario admin, proveedor demo y algunos productos base ya
existen porque el `V2__seed_data.sql` los crea automáticamente en cada
arranque limpio.

### 4. Levanta backend + frontend

```bash
# Terminal 1
cd backend && mvn spring-boot:run

# Terminal 2
flutter run -d windows
```

Login: **admin / admin123**

## Flujo de prueba paso a paso

1. **Cajas** → abrir caja turno DÍA, monto apertura 50.00
2. **Ventas (POS)** → agregar "Galleta Demo" (x3) al carrito → **Cobrar**
3. En el diálogo de pago:
   - Click "Agregar pago"
   - Forma de pago: **Crédito a trabajador**
   - Selecciona **12345678 · Juan Perez Test**
   - Monto: 4.50 (que el total coincida)
   - Guardar
4. Confirmar como **Boleta** → verifica que aparece en historial de ventas
5. Repite 2-4 con Maria Garcia para tener más data
6. **Créditos** → deberías ver:
   - "Consumos del mes actual" con los 2 trabajadores
   - Deuda total = suma de sus consumos
7. Click **Cerrar mes** → confirma
8. En "Historial de cierres mensuales", aparece el cierre nuevo.
   Al lado: botón **"Enviar a planilla"**
9. Click "Enviar a planilla" → snack de confirmación con lote #N
10. Verifica en FT:
    ```sql
    USE financialtracker1;
    SELECT a.ID, a.SoliNum, e.national_id, e.fullName, a.monthly, a.status
      FROM abono a
      JOIN employees e ON e.employee_id = a.Employee_id
     WHERE a.lote_id = <N>;
    ```
    Deberías ver una fila por trabajador con `status='Pendiente'`.
11. En la UI de la bodega, botón **Revertir** → borra los abonos del
    lote en FT y marca el envío como REVERTIDO.

## Reset (empezar de cero)

Si algo salió mal y quieres borrar los datos de prueba sin tocar la BD:

```sql
-- En financialtracker1
DELETE FROM abonodetail WHERE AbonoID IN (
    SELECT ID FROM abono WHERE lote_id IN (
        SELECT id FROM lote_carga_abono WHERE nombre_archivo LIKE 'Bodega Sub Cafe%'
    )
);
DELETE FROM abono WHERE lote_id IN (
    SELECT id FROM lote_carga_abono WHERE nombre_archivo LIKE 'Bodega Sub Cafe%'
);
DELETE FROM lote_carga_abono WHERE nombre_archivo LIKE 'Bodega Sub Cafe%';
DELETE FROM employees WHERE national_id IN ('12345678', '87654321');
DELETE FROM service_concept WHERE description = 'CONSUMO BODEGA';

-- En gestion_bodega
DELETE FROM envios_financialtracker;
DELETE FROM creditos_trabajadores;
DELETE FROM venta_pagos WHERE trabajador_credito_id IN (
    SELECT id FROM clientes WHERE dni IN ('12345678', '87654321')
);
DELETE FROM clientes WHERE dni IN ('12345678', '87654321');
DELETE FROM producto_precios WHERE producto_id IN (
    SELECT id FROM productos WHERE codigo = 'DEMO001'
);
DELETE FROM productos WHERE codigo = 'DEMO001';
```
