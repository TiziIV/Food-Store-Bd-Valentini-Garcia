# Informe de mediciones — TP3 (Unidad 2, Semana 3)

Optimización asistida por IA sobre Food Store: filtros, planes de
ejecución e índices. Base poblada con la carga masiva de
[`TP5_Indices_Vistas/data.sql`](../TP5_Indices_Vistas/data.sql)
(20.000 clientes, 50.000 productos, 200.000 pedidos, ~400.000
detalles).

## Verificación del volumen cargado

```sql
SELECT
  (SELECT count(*) FROM Cliente)        AS clientes,
  (SELECT count(*) FROM Producto)       AS productos,
  (SELECT count(*) FROM Pedido)         AS pedidos,
  (SELECT count(*) FROM Detalle_Pedido) AS detalles;
```

*(La entrega original de este TP no incluía esta verificación de
volumen — señalado en la corrección del profesor — por lo que se
agrega aquí como parte de la reorganización.)*

## Parte 2 — Consultas lentas, EXPLAIN ANALYZE y optimización medida

### Consulta 1 — Productos por categoría y precio

- **Antes:** `Seq Scan` — cost `0.00..1266.00` — 13.100 ms — 47.201 filas descartadas.
- **Cambio aplicado:** `CREATE INDEX idx_producto_categoria_precio ON Producto (id_categoria, precio_actual);`
- **Después:** `Bitmap Heap Scan` vía `Bitmap Index Scan` — cost `72.63..630.11` — 3.600 ms — 0 filas descartadas.
- **Mejora:** 72,5% más rápido (~3,6x).

### Consulta 2 — Pedidos por cliente ordenados por fecha

- **Antes:** `Sort` (quicksort) sobre `Bitmap Heap Scan` — cost `42.11..42.11` — 0.300 ms — 11 filas descartadas, con `Sort Key` explícito.
- **Cambio aplicado:** `CREATE INDEX idx_pedido_cliente_fecha_hora ON Pedido (id_cliente, fecha_hora DESC);`
- **Después:** `Index Scan` sin nodo `Sort` — cost `0.42..8.45` — 0.200 ms — 0 filas descartadas.
- **Mejora:** 79,9% menos costo estimado.

### Consulta 3 — Detalles por rango de precio_unitario

- **Antes:** `Seq Scan` sobre 400.000 filas — cost `0.00..8942.00` — 129.200 ms — 267.832 filas descartadas.
- **Cambio aplicado:** `CREATE INDEX idx_detalle_pedido_precio ON Detalle_Pedido (precio_unitario);`
- **Después:** `Bitmap Heap Scan` vía `Bitmap Index Scan` — cost `190.63..3264.65` — 16.900 ms — 0 filas descartadas.
- **Mejora:** 86,9% más rápido (~7,6x).

### Resumen

| Consulta | Mejora |
|---|---|
| 1. Productos por categoría y precio | 72,5% (~3,6x) |
| 2. Pedidos por cliente y fecha | 79,9% menos costo |
| 3. Detalles por rango de precio | 86,9% (~7,6x) |

## Parte 3 — Lectura crítica de planes interpretados por IA

**Afirmación 1:** "El índice redujo el Planning Time a 0.200 ms, lo
que demuestra su eficiencia."
- **¿Correcta?** No.
- **Corrección:** confunde los tiempos: el `Execution Time` fue 0.200
  ms, pero el `Planning Time` fue 5.500 ms. El índice mejora la
  ejecución, no necesariamente la planificación.

**Afirmación 2:** "El motor tuvo que filtrar 11 filas en memoria para
resolver la consulta."
- **¿Correcta?** No.
- **Corrección:** atribuye al plan optimizado un comportamiento del
  plan original. En el plan con `Index Scan`, `Rows Removed by
  Filter` es 0; las 11 filas descartadas correspondían al plan
  **antes** de crear el índice.

## Parte 5 — Competencia de optimización entre equipos

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| García - Valentini | Indexación B-Tree sobre precio_unitario (`idx_detalle_pedido_precio`), pasando de Seq Scan a Bitmap Index Scan. | 129.200 | 16.900 | 7,6x |

*Nota: la entrega original reportaba en la Parte 5 exactamente el
mismo resultado ya verificado en la Parte 2 (Consulta 3), sin una
consulta lenta común distinta para la competencia — señalado también
en la corrección del profesor.*
