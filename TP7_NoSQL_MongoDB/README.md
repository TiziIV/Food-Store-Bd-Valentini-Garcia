# Trabajo Práctico · Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
## Food Store — Modelo Documental en MongoDB y Validación Cruzada con PostgreSQL

**Integrantes:**
- Tiziano Valentini
- Juan Martin Garcia

**Repositorio:** `Trabajos-Practicos-BD-Valentini-Garcia`

---

## 1. Descripción General

En esta entrega se aborda la transición del modelo relacional al modelo documental basado en agregados (DDD / Document Store) para el subconjunto transaccional crítico de **Pedidos y Detalles de Pedido** de Food Store.

El entregable incluye:
1. **`consultas_mongodb.js`**: Script íntegro y ejecutable en `mongosh` con inicialización de la base `food_store_nosql`, colección `pedidos`, migración con `insertMany()` de 6 pedidos reales y las 4 consultas analíticas solicitadas en la Consigna 4.
2. **`consultas_postgresql.sql`**: Script en PostgreSQL con la consulta de extracción y serialización JSON de los pedidos, y las consultas relacionales equivalentes a las consignas (b) y (c) para contraste cruzado.
3. **`informe_nosql_mongodb.md`**: Informe técnico exhaustivo (listo para exportar a PDF) con el modelado formal, justificación de embedding, evidencias de consola, tabla de verificación cruzada, contraste de respuestas de IA contra la documentación técnica oficial y conclusión arquitectónica.

---

## 2. Requisitos Previos

- **PostgreSQL 16+ / 18+** con la base de datos `food_store_dev` inicializada (esquemas de `TP1_FoodStore/schema.sql` y `TP5_Indices_Vistas/soft_delete.sql`).
- **MongoDB Server 6.0+ / 9.0+** corriendo localmente en el puerto default `27017`.
- **mongosh** (MongoDB Shell) instalado de forma nativa o ejecutable vía `npx mongosh`.
- **psql** en el PATH o en la ruta estándar de PostgreSQL.

---

## 3. Instrucciones de Ejecución

### A. Ejecución del script en MongoDB (`mongosh`)

Para ejecutar la migración completa y las consultas documentales:

```bash
# Conexión local estándar
mongosh TP8_NoSQL_MongoDB/consultas_mongodb.js

# O alternativamente utilizando npx (sin instalación global previa):
npx mongosh TP8_NoSQL_MongoDB/consultas_mongodb.js
```

El script imprimirá en consola:
- La creación/selección de la base `food_store_nosql`.
- La confirmación de inserción (`acknowledged: true`) de los 6 documentos con sus ObjectIds generados.
- La creación de índices optimizados (`id_pedido`, `estado`, `lineas.id_producto`, `total_pedido`).
- Las salidas formateadas de las cuatro consultas de la Consigna 4:
  - **(a)** Todos los pedidos con identificador, estado y total.
  - **(b)** Filtro por estado existente (`ENTREGADO`).
  - **(c)** Filtro por producto embebido en líneas (`id_producto: 3`, "Coca 1.5L").
  - **(d)** Filtro por total superior a umbral de alto valor (`total_pedido > 15000.00`).

---

### B. Ejecución de las consultas en PostgreSQL (`psql`)

Para ejecutar la extracción JSON y las consultas relacionales equivalentes:

```bash
# Conexión con psql a la base de datos de desarrollo
psql -U postgres -d food_store_dev -f TP8_NoSQL_MongoDB/consultas_postgresql.sql
```

El script SQL ejecuta:
1. Ajuste idempotente de la columna `estado` en la tabla `Pedido` para coincidir con el ciclo de vida del pedido.
2. Consulta de extracción/migración que genera la estructura documental nativa mediante `jsonb_agg` y `jsonb_build_object`.
3. Consulta equivalente (b): filtro de pedidos con `estado = 'ENTREGADO'` (IDs: 1, 2, 4, 5 — Total: 4).
4. Consulta equivalente (c): pedidos que contienen el producto 3 con `JOIN Detalle_Pedido` (IDs: 1, 3 — Total: 2).

---

## 4. Tabla de Verificación Cruzada (Consigna 5)

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
| :--- | :---: | :---: | :---: |
| **Estado seleccionado (`ENTREGADO`)** | **4** (IDs: 1, 2, 4, 5) | **4** (IDs: 1, 2, 4, 5) | **Sí** |
| **Producto seleccionado (`id_producto = 3`)** | **2** (IDs: 1, 3) | **2** (IDs: 1, 3) | **Sí** |
