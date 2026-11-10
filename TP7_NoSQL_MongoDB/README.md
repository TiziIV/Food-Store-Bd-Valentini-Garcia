# Trabajo Práctico · Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
## Food Store — Modelo Documental en MongoDB, Validador `$jsonSchema`, `Decimal128` y Validación Cruzada con PostgreSQL

**Integrantes:**
- Tiziano Valentini
- Juan Martin Garcia

**Repositorio:** `Food-Store-Bd-Valentini-Garcia` (rama: `trabajos-practicos-nosql`)

---

## 1. Descripción General

En esta entrega se aborda la transición del modelo relacional al modelo documental basado en agregados (DDD / Document Store) para el subconjunto transaccional crítico de **Pedidos y Detalles de Pedido** de Food Store.

El entregable incluye:
1. **[`consultas_mongodb.js`](consultas_mongodb.js)**: Script íntegro y ejecutable en `mongosh` con inicialización de la base `food_store_nosql`, creación explícita de la colección `pedidos` con validador formal **`$jsonSchema`**, migración con `insertMany()` de 6 pedidos reales usando **`NumberDecimal("...")` (`Decimal128`)** para todos los importes, prueba de validación negativa (`Document failed validation` al intentar insertar `double`), las 4 consultas solicitadas en la Consigna 4 y las pruebas de laboratorio para el contraste crítico de IA.
2. **[`consultas_postgresql.sql`](consultas_postgresql.sql)**: Script en PostgreSQL con la consulta de extracción y serialización JSONB de los pedidos, las consultas relacionales equivalentes a las consignas (b), (c) y (d), el `EXPLAIN ANALYZE` de reconstrucción de pedido completo y la agregación por categoría equivalente al pipeline de MongoDB.
3. **[`informe_nosql_mongodb.md`](informe_nosql_mongodb.md)** y **[`informe_nosql_mongodb.pdf`](informe_nosql_mongodb.pdf)**: Informe técnico completo con el modelado formal, validador `$jsonSchema`, tipado `Decimal128`, justificación de embedding, evidencias de consola en ambos motores, tabla de verificación cruzada, resumen detallado de las respuestas recibidas de la IA, contraste crítico respaldado por evidencias reales de laboratorio y conclusión arquitectónica.
4. **[`duia.md`](duia.md)**: Declaración de Uso de IA y bitácora detallada de iteraciones con el resumen de lo entregado por la IA, descartes/correcciones aplicadas (`double` $\to$ `Decimal128`, incorporación de `$jsonSchema`) y pruebas de laboratorio.

---

## 2. Requisitos Previos

- **PostgreSQL 16+ / 18+** con la base de datos `food_store_dev` inicializada (esquemas de `TP1_FoodStore/schema.sql` y `TP5_Indices_Vistas/soft_delete.sql`).
- **MongoDB Server 6.0+ / 8.0+** corriendo localmente en el puerto default `27017`.
- **mongosh** (MongoDB Shell) instalado de forma nativa o ejecutable vía `npx mongosh`.
- **psql** en el PATH o en la ruta estándar de PostgreSQL.

---

## 3. Instrucciones de Ejecución

### A. Ejecución del script en MongoDB (`mongosh`)

Para ejecutar la creación con `$jsonSchema`, migración con `Decimal128`, prueba de rechazo de validador, consultas documentales y laboratorio de IA:

```bash
# Conexión local estándar
mongosh TP7_NoSQL_MongoDB/consultas_mongodb.js

# O alternativamente utilizando npx:
npx mongosh TP7_NoSQL_MongoDB/consultas_mongodb.js
```

El script imprimirá en consola:
- La creación de la colección `pedidos` con su validador `$jsonSchema` (`{ ok: 1 }`).
- La confirmación de inserción (`acknowledged: true`) de los 6 documentos con importes en `Decimal128`.
- El rechazo esperado del motor (`MongoServerError: Document failed validation`, código `121`) al intentar insertar un pedido con importes en `double`.
- Las salidas formateadas de las cuatro consultas de la Consigna 4:
  - **(a)** Todos los pedidos con identificador, estado, forma de pago y `total_pedido` en `Decimal128`.
  - **(b)** Filtro por estado existente (`ENTREGADO`).
  - **(c)** Filtro por producto embebido en líneas (`id_producto: 3`, "Coca 1.5L").
  - **(d)** Filtro por total superior a umbral de alto valor (`total_pedido > NumberDecimal("15000.00")`).
- Las 3 pruebas de laboratorio para el contraste crítico de IA (`double` vs `Decimal128`, `explain("executionStats")` y pipeline `$match` + `$unwind` + `$group` + `$sort`).

---

### B. Ejecución de las consultas en PostgreSQL (`psql`)

Para ejecutar la extracción JSONB, las consultas relacionales equivalentes y las pruebas de laboratorio en PostgreSQL:

```bash
psql -U postgres -d food_store_dev -f TP7_NoSQL_MongoDB/consultas_postgresql.sql
```

---

## 4. Tabla de Verificación Cruzada (Consigna 5)

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
| :--- | :---: | :---: | :---: |
| **Estado seleccionado (`ENTREGADO`)** | **4** (IDs: 1, 2, 4, 5) | **4** (IDs: 1, 2, 4, 5) | **Sí** |
| **Producto seleccionado (`id_producto = 3`)** | **2** (IDs: 1, 3) | **2** (IDs: 1, 3) | **Sí** |
