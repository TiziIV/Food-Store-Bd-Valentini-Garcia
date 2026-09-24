# Informe técnico general — Entrega parcial del TPI Food Store

Base de Datos II · Proyecto integrador «Food Store» · PostgreSQL 16+
Integrantes: Valentini, Tiziano — García, Juan Martín

Este informe resume lo actuado en las Unidades 1, 2 y 3 (TP1 a TP5)
para la primera entrega parcial del Trabajo Práctico Integrador, tal
como lo pide la consigna de esa entrega. El detalle completo de cada
trabajo práctico (scripts, mediciones y DUIA) vive en su propia
carpeta; este documento es el resumen transversal.

## 1. Qué se implementó en cada unidad

### Unidad 1 — Integridad, transacciones y concurrencia (TP1 y TP2)

- **TP1** ([`TP1_FoodStore/`](TP1_FoodStore/)): modelo entidad-relación
  del dominio Food Store (Cliente, Categoría, Producto, Pedido,
  Detalle_Pedido), derivación al modelo relacional, normalización
  hasta BCNF, y el DDL definitivo en `schema.sql` con tipos ENUM,
  claves primarias/foráneas, `CHECK`, `UNIQUE`, `DEFAULT` e índices
  justificados.
- **TP2** ([`TP2_Concurrencia_IA/`](TP2_Concurrencia_IA/)): protocolo
  de seguridad operativa (copia, transacción, respaldo), restricciones
  de integridad adicionales (formato de correo, precios estrictamente
  positivos, inmutabilidad del precio histórico facturado) y un
  trigger de validación/descuento de stock; laboratorio de tres
  escenarios de concurrencia reproducidos con dos sesiones (pérdida de
  actualización, lectura no repetible, prevención de interbloqueos); y
  un ejercicio de lectura crítica de scripts SQL destructivos.

### Unidad 2 — Optimización de consultas (TP3 y TP4)

- **TP3** ([`TP3_Optimizacion_Indices/`](TP3_Optimizacion_Indices/)):
  carga masiva de datos (20.000 clientes, 50.000 productos, 200.000
  pedidos, ~400.000 detalles), medición con `EXPLAIN ANALYZE` de tres
  consultas de catálogo/historial/reporte antes y después de indexar,
  lectura crítica de una explicación de plan generada por IA, y dos
  consultas bajo especificación precisa (agregación y subconsulta) con
  verificación de equivalencia por `EXCEPT`.
- **TP4** ([`TP4_Reportes_Analiticos/`](TP4_Reportes_Analiticos/)):
  optimización de dos consultas analíticas con múltiples `JOIN`
  (facturación por categoría/producto, clientes por gasto en 180
  días), identificación del algoritmo de join elegido por el
  optimizador en cada caso, lectura crítica de una explicación de plan
  con `Nested Loop`/`Hash Join`, y dos consultas con función de
  ventana (`DENSE_RANK`) y subconsulta correlacionada.

### Unidad 3 — Índices, vistas y objetos programables (TP5)

- **TP5** ([`TP5_Indices_Vistas/`](TP5_Indices_Vistas/)): plan de
  indexado final (índice parcial, compuesto con orden `DESC` y
  covering index), tres vistas de solo lectura para los reportes del
  sistema (productos vigentes, pedidos con datos de cliente, detalle
  de pedido con nombre de producto y subtotal), una vista
  materializada de facturación por categoría y mes con índice único
  para permitir `REFRESH CONCURRENTLY`, el borrado lógico extendido
  a `Cliente`, `Pedido` y `Detalle_Pedido` (`soft_delete.sql`), y
  dos procedimientos invocados con `CALL` (`procedimientos.sql`).

## 2. Cómo se probó cada elemento

- Todo script DDL/DML se leyó línea por línea antes de ejecutarse y
  se probó primero sobre una copia de trabajo de la base, siguiendo
  [`protocolo_seguridad.md`](protocolo_seguridad.md) (copia,
  transacción `BEGIN...ROLLBACK`, respaldo con `pg_dump` antes de
  cambios estructurales).
- Los índices se validaron comparando el plan de `EXPLAIN ANALYZE`
  antes y después de crearlos (nodo, `cost`, tiempo real), y también
  se midió su costo sobre la escritura (lote de `INSERT`).
- Las vistas se validaron comparando su resultado contra la consulta
  manual equivalente con `EXCEPT` en ambos sentidos (0 filas
  esperadas).
- Los escenarios de concurrencia se reprodujeron con dos sesiones
  `psql` reales sobre la misma base de trabajo, no solo en teoría.
- Las restricciones de integridad se probaron con `INSERT`/`UPDATE`
  válidos e inválidos dentro de una transacción de prueba.

## 3. Qué resultados se obtuvieron

Ver el detalle completo en cada `informe_mediciones.md`
([TP3](TP3_Optimizacion_Indices/informe_mediciones.md),
[TP4](TP4_Reportes_Analiticos/informe_mediciones.md),
[TP5](TP5_Indices_Vistas/informe_mediciones.md)). En síntesis:

| Consulta | Antes | Después | Mejora |
|---|---|---|---|
| Productos por categoría y precio (TP3) | Seq Scan, 13.1 ms | Bitmap Heap Scan, 3.6 ms | 72,5% (~3,6x) |
| Pedidos por cliente y fecha (TP3) | Sort + Bitmap Heap Scan, 0.30 ms | Index Scan, 0.20 ms | 79,9% menos costo |
| Detalle_Pedido por rango de precio (TP3) | Seq Scan, 129.2 ms | Bitmap Heap Scan, 16.9 ms | 86,9% (~7,6x) |
| Facturación por categoría/producto (TP4) | Hash Join + Seq Scan, 145.8 ms | Hash Join + Index Only Scan, 38.4 ms | 73,6% (~3,8x) |
| Clientes por gasto en 180 días (TP4) | Hash Join + Seq Scan, 168.5 ms | Bitmap Index Scan + Hash Join, 42.1 ms | 75,0% (~4,0x) |
| Facturación por categoría y mes (TP5, vista materializada) | Consulta agregada original sin materializar | `SELECT * FROM mv_facturacion_categoria_mes` | Ver TP5/informe_mediciones.md |

## 4. Qué se optimizó y qué diferencias se encontraron

En los tres casos con volumen masivo (TP3 y TP4), el cuello de botella
inicial fue siempre un `Seq Scan` sobre `Producto`, `Pedido` o
`Detalle_Pedido` con decenas o cientos de miles de filas descartadas
por filtro. La estrategia fue siempre la misma: medir con `EXPLAIN
ANALYZE`, proponer con IA un índice o una reescritura justificada en
el nodo concreto del plan, aplicar sobre una copia y volver a medir.
En dos casos (TP3 Parte 3, TP4 Parte 2) la explicación de un plan
generada por IA contenía errores concretos (confundir `cost` con
tiempo real, invertir la relación externa/interna de un `Nested
Loop`, o atribuir una elección del optimizador a una causa
equivocada) — esos errores se detectaron por lectura crítica contra
el plan real y quedan documentados, no ocultados, en cada
`informe_mediciones.md`.

Un índice propuesto por la IA fue **descartado explícitamente** por
sobreindexación: `idx_pedido_forma_pago` (TP5), sobre una columna de
baja cardinalidad (4 valores ENUM), porque el optimizador lo ignora y
solo agrega costo de escritura sin beneficio de lectura (ver
[`TP5_Indices_Vistas/specs/spec_idx_pedido_forma_pago_DESCARTADO.md`](TP5_Indices_Vistas/specs/spec_idx_pedido_forma_pago_DESCARTADO.md)).

## 5. Uso de herramientas de IA

Herramientas usadas en todo el proyecto: **Kiro** (especificación de
requerimientos antes de generar código) y **OpenCode** (agente de
codificación en terminal, en modo Plan antes de modo Build). El
detalle de qué se aceptó, modificó o descartó de cada propuesta está
documentado en el `duia.md` de cada carpeta de TP. Ningún script
generado por IA se ejecutó sin leerse línea por línea ni sin probarse
primero sobre una copia de trabajo, según el protocolo de seguridad
de la cátedra.

## 6. Checklist de los 9 objetivos exigidos por la entrega parcial

Resumen rápido (detalle de evidencia debajo de la tabla):

| # | Objetivo | Estado |
|---|---|---|
| 1 | Modelo ER | Cubierto |
| 2 | Paso de ER a modelo relacional | Cubierto |
| 3 | Normalización hasta 3FN/BCNF | Cubierto |
| 4 | DDL completo | Cubierto |
| 5 | DML y consultas (JOIN, agregación, subconsultas, ventana) | Cubierto |
| 6 | Vistas, funciones y procedimientos en PL/pgSQL | Cubierto |
| 7 | Reglas de negocio con CHECK, UNIQUE y triggers | Cubierto |
| 8 | Transacciones y control de concurrencia | Cubierto |
| 9 | Borrado lógico (soft delete) | Cubierto |

**1. Modelo ER** (entidades, atributos, claves, cardinalidad,
participación) — [`TP1_FoodStore/diagrama-er.png`](TP1_FoodStore/diagrama-er.png)
y [`TP1_FoodStore/modelo_relacional_y_normalizacion.md`](TP1_FoodStore/modelo_relacional_y_normalizacion.md).

**2. Paso de ER a modelo relacional** (1:N y N:M con tabla
intermedia) — mismo archivo, sección "Parte 2".

**3. Normalización hasta 3FN/BCNF**, con justificación de
dependencias funcionales — mismo archivo, sección "Parte 3".

**4. DDL completo** (tipos, PK/FK, restricciones e índices) —
[`TP1_FoodStore/schema.sql`](TP1_FoodStore/schema.sql).

**5. DML y consultas** (JOIN, agregación, subconsultas, GROUP
BY/HAVING, funciones de ventana) —
[`TP3/queries.sql`](TP3_Optimizacion_Indices/queries.sql) y
[`TP4/queries.sql`](TP4_Reportes_Analiticos/queries.sql): JOIN,
`SUM`, subconsultas correlacionadas y no correlacionadas,
`DENSE_RANK() OVER`.

**6. Vistas, funciones y procedimientos en PL/pgSQL.** Vistas en
[`TP5_Indices_Vistas/views.sql`](TP5_Indices_Vistas/views.sql) y vista
materializada en [`materializadas.sql`](TP5_Indices_Vistas/materializadas.sql).
Funciones-trigger en PL/pgSQL en
[`TP2/restricciones.sql`](TP2_Concurrencia_IA/restricciones.sql).
Procedimientos invocados con `CALL` en
[`TP5_Indices_Vistas/procedimientos.sql`](TP5_Indices_Vistas/procedimientos.sql):
`sp_registrar_pedido` (carga atómica de un pedido con JSONB,
reutilizando el trigger de validación de stock) y
`sp_dar_baja_cliente` (aplica el borrado lógico del punto 9).

**7. Reglas de negocio con CHECK, UNIQUE y triggers** —
`CHECK`/`UNIQUE` en `schema.sql` (Parte 1) y en `TP2/restricciones.sql`;
triggers de stock y de inmutabilidad del precio histórico en
`TP2/restricciones.sql`.

**8. Transacciones** (atomicidad, COMMIT/ROLLBACK, niveles de
aislamiento, control de concurrencia) —
[`TP2_Concurrencia_IA/informe_concurrencia.md`](TP2_Concurrencia_IA/informe_concurrencia.md):
tres escenarios con dos sesiones, verificados en el motor.

**9. Borrado lógico (soft delete).** Base en `Producto.activo`, con
índice parcial `WHERE activo = TRUE` (`TP5_Indices_Vistas/indices.sql`)
reflejado en las vistas/consultas de reporte. Extendido a `Cliente`,
`Pedido` y `Detalle_Pedido` en
[`TP5_Indices_Vistas/soft_delete.sql`](TP5_Indices_Vistas/soft_delete.sql),
con sus propios índices parciales (`idx_pedido_vigente_cliente_fecha`,
`idx_detalle_pedido_vigente`) y el ejemplo concreto de cómo cambia la
consulta de "clientes sin pedidos" de TP3 al aplicar el filtro de
vigencia en ambas tablas.

Ver el paso 9 de [`TP5_Indices_Vistas/README.md`](TP5_Indices_Vistas/README.md)
para aplicar `soft_delete.sql` y `procedimientos.sql`, y verificarlos
con `CALL` y `EXPLAIN ANALYZE`.
