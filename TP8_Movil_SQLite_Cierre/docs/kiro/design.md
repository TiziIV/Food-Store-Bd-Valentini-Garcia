# Diseño Arquitectónico: Base Móvil Offline y Motor de Sincronización (TP8)

**Proyecto:** Food Store en la Feria — Base Móvil SQLite y Sincronización Offline  
**Equipo:** Tiziano Valentini y Juan Martin Garcia  
**Comisión:** 2PRO4 — Cátedra Base de Datos II (Ciclo Lectivo 2026)  
**Docente:** Sergio Neira  

---

## 1. Topología del Sistema y Filosofía de Diseño

El sistema Food Store en su modalidad de feria gastronómica adopta un patrón **Offline-First Asimétrico**:

```
+-------------------------------------------------------+
|                POSTGRESQL 16+ (SERVIDOR)              |
|        Single Source of Truth (Fuente de Verdad)      |
|  - Tablas: Producto, Pedido, Detalle_Pedido, Cliente  |
|  - Reglas: Stock transaccional, precios autorizados   |
|  - Vista exportadora: v_snapshot_movil                |
+---------------------------+---------------------------+
                            |
           Instantánea CSV  |  (Exportación por lotes)
           servidor_        |  \copy TO CSV
           snapshot.csv     v
+-------------------------------------------------------+
|                 SQLITE 3.37+ (TABLET MÓVIL)           |
|            Ambiente Desconectado (Feria sin señal)    |
|  - Tablas STRICT con PRAGMA foreign_keys = ON;        |
|  - producto_cache: catálogo de solo lectura           |
|  - pedido_borrador + item_borrador: compras en curso  |
|  - cola_sync: solicitudes a evaluar por semáforo      |
|  - snapshot_servidor: réplica local de la instantánea |
+-------------------------------------------------------+
```

### Regla de Oro
> **"El móvil propone, el servidor dispone."**  
> La tablet jamás confirma ventas reales, ni decrementa el stock maestro ni impone precios al servidor central. Su única atribución es capturar la intención de compra del cliente en forma de borradores (`pedido_borrador`), asociarles un UUID unívoco de sincronización (`cola_sync`) y simular localmente si la operación sería aceptada frente a la última foto conocida del servidor.

---

## 2. Esquema de Datos en SQLite (Modo STRICT)

SQLite 3.37+ incorpora la cláusula `STRICT`, obligando al motor a aplicar tipado estricto en tiempo de inserción y modificación, descartando la afinidad de tipos permisiva tradicional de SQLite.

### 2.1 Tablas del Sistema Móvil

1. **`producto_cache`**: Almacena el catálogo de productos consultable offline.
   - `id INTEGER PRIMARY KEY`: Identificador homologado con `id_producto` de PostgreSQL.
   - `nombre TEXT NOT NULL`: Descripción comercial del artículo.
   - `precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0)`: Precio congelado en centavos enteros para evitar errores de redondeo de coma flotante.
   - `stock_visto INTEGER NOT NULL CHECK (stock_visto >= 0)`: Stock reportado en la última instantánea.
   - `disponible INTEGER NOT NULL CHECK (disponible IN (0, 1))`: 1 si está habilitado para la venta, 0 en caso contrario.
   - `eliminado INTEGER NOT NULL CHECK (eliminado IN (0, 1))`: Lápida (*tombstone*); 1 si fue dado de baja lógica en el servidor.
   - `fecha_copia TEXT NOT NULL`: Timestamp ISO-8601 del momento en que se refrescó la caché local.

2. **`pedido_borrador`**: Encabezado del borrador de pedido iniciado por el operador de la tablet.
   - `id_local TEXT PRIMARY KEY`: UUID v4 generado en la tablet.
   - `usuario TEXT NOT NULL`: Identificador o nombre del operador local (ej. `'operador_tablet_01'`). No contiene credenciales ni datos personales del cliente.
   - `forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA'))`.
   - `fecha TEXT NOT NULL`: Timestamp local de creación.

3. **`item_borrador`**: Líneas de detalle del borrador.
   - `id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE`.
   - `producto_id INTEGER NOT NULL REFERENCES producto_cache(id)`.
   - `cantidad INTEGER NOT NULL CHECK (cantidad > 0)`.
   - `precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0)`.
   - `PRIMARY KEY (id_local, producto_id)`.

4. **`cola_sync`**: Registro de envíos pendientes y estado de resolución.
   - `solicitud_uuid TEXT PRIMARY KEY`: Identificador único de la solicitud de sincronización.
   - `id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local)`.
   - `estado TEXT NOT NULL CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO'))`.
   - `motivo TEXT`: Diagnóstico técnico y comercial emitido por el semáforo.

5. **`snapshot_servidor`**: Tabla de recepción directa para la importación del CSV emitido por PostgreSQL.
   - `id INTEGER PRIMARY KEY`.
   - `nombre TEXT NOT NULL`.
   - `precio_centavos INTEGER NOT NULL`.
   - `stock INTEGER NOT NULL`.
   - `disponible TEXT NOT NULL`: Recibe `'t'` o `'f'` como cadenas generadas por PostgreSQL.
   - `eliminado TEXT NOT NULL`: Recibe `'t'` o `'f'`.

---

## 3. Lógica del Motor de Sincronización (El Semáforo)

El semáforo es una rutina determinista en SQL ejecutada en SQLite. Evalúa **únicamente** aquellas solicitudes en `cola_sync` cuyo estado sea `'PENDIENTE'`.

### 3.1 Precedencia Estricta de Estados

```
                           +----------------------+
                           | Solicitud PENDIENTE  |
                           +----------+-----------+
                                      |
                                      v
                      ¿Existe producto faltante,
                      eliminado ('t'/1), deshabilitado
                      ('f'/0) o cantidad > stock?
                               /             \
                              / SÍ            \ NO
                             v                 v
                   +------------------+   ¿Algún precio difiere?
                   | ROJO: RECHAZADO  |   (precio_visto <> precio_actual)
                   +------------------+         /            \
                                               / SÍ           \ NO
                                              v                v
                                    +--------------------+   +---------------------------+
                                    | AMARILLO: CONFLICTO|   | VERDE: SIMULADO_APROBADO  |
                                    +--------------------+   +---------------------------+
```

1. **ROJO (`RECHAZADO`) — Máxima Prioridad**:
   - Condición:
     `s.id IS NULL` (el producto no existe en el snapshot)
     `OR s.disponible IN ('f', '0')`
     `OR s.eliminado IN ('t', '1')`
     `OR i.cantidad > s.stock`
   - Acción: `estado = 'RECHAZADO'`, con indicación precisa en `motivo` (ej. *"Stock insuficiente: solicitado 5, disponible 2"* o *"Producto dado de baja en servidor"*).

2. **AMARILLO (`CONFLICTO`) — Prioridad Media**:
   - Condición:
     No se cumple ninguna condición de ROJO, pero:
     `i.precio_centavos_visto <> s.precio_centavos`.
   - Acción: `estado = 'CONFLICTO'`, con indicación en `motivo` (ej. *"Precio desactualizado: visto $10.50, actual $12.00"*).
   - Resolución: El cliente debe ser notificado. Si acepta el nuevo precio, se actualiza el borrador local y se emite un nuevo `solicitud_uuid` en `cola_sync` para su reevaluación.

3. **VERDE (`SIMULADO_APROBADO`) — Conformidad**:
   - Condición:
     Todos los ítems existen, tienen stock suficiente, están vigentes y sus precios coinciden exactamente.
   - Acción: `estado = 'SIMULADO_APROBADO'`, `motivo = 'Aprobado: stock y precio coincidentes con instantanea'`.

---

## 4. Estrategia de Representación Monetaria (Centavos Enteros)

En bases de datos distribuidas y sincronización móvil, el uso de tipos de coma flotante (`REAL`, `FLOAT`) introduce discrepancias de redondeo binario (*floating point rounding errors*, p. ej. `0.1 + 0.2 = 0.30000000000000004`). 

En este diseño se adopta la convención contable estricta de **enteros en centavos**:
- En PostgreSQL: `ROUND(precio_actual * 100)::INTEGER AS precio_centavos`.
- En SQLite: `precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0)`.
- Ejemplo: `$1.500,00` se transfiere y almacena como `150000`. Esto garantiza comparaciones de igualdad exactas (`=`, `<>`) sin márgenes de tolerancia de coma flotante.

---

## 5. Idempotencia y Resiliencia ante Desconexión

1. **Idempotencia de Entrada (Clave Primaria):**  
   Cada solicitud enviada a `cola_sync` posee una clave primaria `solicitud_uuid`. Si un fallo de comunicación provoca que la tablet reintente enviar la misma solicitud, SQLite rechaza el duplicado con `PRIMARY KEY constraint failed`.
2. **Idempotencia de Ejecución del Semáforo:**  
   El motor SQL procesa únicamente `WHERE estado = 'PENDIENTE'`. Si el proceso del semáforo se ejecuta múltiples veces consecutivas, las solicitudes que ya obtuvieron un estado (`CONFLICTO`, `RECHAZADO`, `SIMULADO_APROBADO`) permanecen intactas y no se recalculan.
3. **Producción (PostgreSQL):**  
   En un despliegue productivo, la protección de idempotencia real se ubica en el servidor central mediante una restricción `UNIQUE (solicitud_uuid)` sobre una tabla transaccional de recepción de pedidos (patrón *Idempotent Receiver / Outbox*), evitando la doble facturación de pedidos repetidos por la red móvil.
