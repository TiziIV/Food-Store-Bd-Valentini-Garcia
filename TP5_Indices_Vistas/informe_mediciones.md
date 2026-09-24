# Informe de mediciones — Food Store

Cátedra: Base de Datos II — Unidad 3, Semana 5

Volumen de datos usado en todas las mediciones: 50.000 productos,
20.000 clientes, 200.000 pedidos, 400.000 detalles de pedido.

Los tiempos que cierran en centésimas `.x00` son cifras redondeadas
del informe de la semana, no el texto crudo de `EXPLAIN ANALYZE`.
La línea base "Seq Scan" de pedidos por `id_cliente` y de detalles
por `id_producto` se midió sin los índices que `schema.sql` ya crea
(`idx_pedido_id_cliente`, `idx_detalle_pedido_id_producto`). Con
esos índices el plan de pedidos es el de TP3: Bitmap Heap Scan,
alrededor de 0,3 ms, no un Seq Scan de 25 ms. En la carga integrada
esos dos índices se eliminan en `indices.sql` porque el compuesto
y el covering los cubren.

---

## Parte A — Índices

### Consulta 1 — Productos activos por categoría y rango de precio

```sql
SELECT id_producto, nombre_producto, precio_actual
FROM Producto
WHERE id_categoria = 5
  AND activo = TRUE
  AND precio_actual BETWEEN 1500.00 AND 3500.00;
```

**Antes:**
```
Seq Scan on producto (cost=0.00..1285.00 rows=3120 width=45)
  (actual time=0.018..14.200 ms rows=3080 loops=1)
Filtro: (activo AND (id_categoria = 5) AND (precio_actual BETWEEN 1500.00 AND 3500.00))
Filas descartadas por el filtro: 46920
Tiempo total de ejecución: 14.500 ms
```

Índice creado:
```sql
CREATE INDEX idx_producto_cat_precio_activo
ON Producto (id_categoria, precio_actual)
WHERE activo = TRUE;
```

**Después:**
```
Bitmap Heap Scan on producto (cost=45.12..480.20 rows=3120 width=45)
  (actual time=0.450..2.300 ms rows=3080 loops=1)
  -> Bitmap Index Scan on idx_producto_cat_precio_activo
       (cost=0.00..44.34 rows=3120 width=0) (actual time=0.410..0.410 ms)
Filas descartadas: 0
Tiempo total de ejecución: 2.500 ms
```

**Mejora:** 82,7% (de 14,5 ms a 2,5 ms; factor 5,8x).

**Nota sobre el parcial:** con la carga masiva, alrededor del 96% de
los productos tienen `activo = TRUE`. El índice parcial ahorra poco
tamaño frente a uno completo sobre `(id_categoria, precio_actual)`;
se conserva porque la consulta de catálogo siempre lleva
`activo = TRUE` y el plan medido deja el Seq Scan.

---

### Consulta 2 — Historial cronológico de pedidos por cliente

```sql
SELECT id_pedido, fecha_hora, forma_pago
FROM Pedido
WHERE id_cliente = 12450
ORDER BY fecha_hora DESC;
```

**Antes:**
```
Sort (cost=3850.12..3850.15 rows=12 width=32)
  (actual time=24.800..24.805 ms rows=11 loops=1)
  -> Seq Scan on pedido (cost=0.00..3850.00 rows=12 width=32)
       (actual time=0.040..24.600 ms rows=11 loops=1)
Filas descartadas: 199989
Tiempo total de ejecución: 25.100 ms
```

Índice creado:
```sql
CREATE INDEX idx_pedido_cliente_fecha_desc
ON Pedido (id_cliente, fecha_hora DESC);
```

**Después:**
```
Index Scan using idx_pedido_cliente_fecha_desc on pedido
  (cost=0.42..8.65 rows=12 width=32) (actual time=0.025..0.055 ms rows=11 loops=1)
Index Cond: (id_cliente = 12450)
Filas descartadas: 0
Tiempo total de ejecución: 0.080 ms
```

**Mejora:** 99,7% (de 25,1 ms a 0,08 ms; factor ≈314x).

---

### Consulta 3 — Ítems por producto en detalle de pedido

```sql
SELECT id_pedido, cantidad, precio_unitario
FROM Detalle_Pedido
WHERE id_producto = 24005;
```

**Antes:**
```
Seq Scan on detalle_pedido (cost=0.00..7942.00 rows=16 width=22)
  (actual time=0.020..42.100 ms rows=14 loops=1)
Filas descartadas: 399986
Tiempo total de ejecución: 42.400 ms
```

Índice creado:
```sql
CREATE INDEX idx_detalle_pedido_prod_covering
ON Detalle_Pedido (id_producto)
INCLUDE (cantidad, precio_unitario);
```

**Después:**
```
Index Only Scan using idx_detalle_pedido_prod_covering on detalle_pedido
  (cost=0.42..4.68 rows=16 width=22) (actual time=0.030..0.060 ms rows=14 loops=1)
Heap Fetches: 0
Tiempo total de ejecución: 0.090 ms
```

**Mejora:** 99,8% (de 42,4 ms a 0,09 ms; factor ≈470x).

---

### Costo de los índices sobre las escrituras (INSERT)

Prueba: inserción por lotes de 1.000 registros nuevos en Detalle_Pedido.

```sql
INSERT INTO Detalle_Pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
  floor(random() * 200000 + 1)::bigint,
  floor(random() * 50000 + 1)::bigint,
  floor(random() * 5 + 1)::integer,
  round((random() * 2000 + 500)::numeric, 2)
FROM generate_series(1, 1000);
```

| Estado de indexación          | Índices activos en Detalle_Pedido        | Tiempo de carga (1.000 INSERT) | Sobrecosto              |
|--------------------------------|-------------------------------------------|----------------------------------|--------------------------|
| Línea base (antes)             | PK `pk_detalle_pedido`                    | 28.400 ms                        | 0% (referencia)          |
| Con índice agregado (después)  | PK + `idx_detalle_pedido_prod_covering`   | 46.800 ms                        | +64,8% de tiempo adicional |

**Justificación técnica:** cada tupla nueva no solo se escribe en el
heap de la tabla; el motor también actualiza la estructura B-Tree
del índice agregado, incrementando los accesos de I/O y la
contención de locks sobre sus páginas.

### Índice descartado por sobreindexación

```sql
-- Propuesta descartada
CREATE INDEX idx_pedido_forma_pago ON Pedido (forma_pago);
```

Motivo: `forma_pago` es un enum de solo 4 valores (~25% de la
tabla cada uno). El planificador de PostgreSQL descarta este tipo
de índice de baja selectividad y usa Seq Scan; mantenerlo solo
agregaría costo de escritura y de memoria sin beneficio real.

---

## Parte B — Vistas

### Verificación de equivalencia

Para cada una de las tres vistas (`vista_productos_vigentes`,
`vista_pedidos_cliente`, `vista_detalle_pedido_producto`) se
ejecutó la comparación con `EXCEPT` en ambos sentidos contra la
consulta manual equivalente. En los tres casos el resultado fue
0 filas en ambas direcciones, confirmando que la vista devuelve
exactamente el mismo conjunto de datos que la consulta escrita a
mano.

Ejemplo (vista_productos_vigentes):
```sql
SELECT * FROM vista_productos_vigentes
EXCEPT
SELECT p.id_producto, p.nombre_producto, p.precio_actual,
       c.id_categoria, c.nombre_categoria
FROM Producto p
JOIN Categoria c ON p.id_categoria = c.id_categoria
WHERE p.activo = TRUE;
-- Resultado: 0 filas
```

### Criterio de seguridad

`vista_pedidos_cliente` no expone la columna `telefono` de
`Cliente`. Food Store no modela autenticación de clientes (no
existe columna de contraseña en el esquema desde TP1), por lo
que el dato de contacto sensible a proteger en un reporte
compartido es el teléfono, no una credencial. Esto permite
otorgar `SELECT` sobre la vista a un rol de reportería sin dar
acceso al dato de contacto directo del cliente en la tabla base:

```sql
GRANT SELECT ON vista_pedidos_cliente TO rol_reportes;
```

---

## Parte C — Vista materializada

Reporte elegido: facturación por categoría y por mes.

**Consulta original (sin materializar):**
```
HashAggregate (cost=21480.00..21522.40 rows=240 width=64)
  (actual time=795.300..799.100 rows=238 loops=1)
  (tres Hash Join encadenados sobre las 400.000 filas de Detalle_Pedido)
Tiempo total de ejecución: 810.450 ms
```

**Consulta contra la vista materializada:**
```sql
SELECT * FROM mv_facturacion_categoria_mes
ORDER BY mes, nombre_categoria;
```
```
Seq Scan on mv_facturacion_categoria_mes (cost=0.00..8.40 rows=240 width=64)
  (actual time=0.015..0.850 ms rows=238 loops=1)
Tiempo total de ejecución: 1.150 ms
```

**Mejora:** 99,86% (de 810,45 ms a 1,15 ms; factor ≈705x).

**Frecuencia de refresco recomendada:** diaria, fuera de horario
pico (03:00 AM), mediante:
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

**Implicancia para los usuarios:** el reporte puede mostrar datos
con hasta 24 horas de atraso respecto de los pedidos más
recientes. Se considera aceptable porque el reporte se usa para
tendencias mensuales, no para el seguimiento puntual de un
pedido (para eso están `vista_pedidos_cliente` y
`vista_detalle_pedido_producto`, que sí reflejan el estado
actual). El índice único `idx_mv_facturacion_cat_mes` es el que
habilita usar `CONCURRENTLY`, evitando bloquear la lectura del
reporte durante el refresco.
