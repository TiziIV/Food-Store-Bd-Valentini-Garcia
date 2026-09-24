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
| Facturación por categoría y mes (TP5, vista materializada) | Consulta agregada, 810,45 ms | `SELECT * FROM mv_facturacion_categoria_mes`, 1,15 ms | 99,86% (~705x) |

Los tiempos de TP3 y TP4 que cierran en centésimas `.x00` (13,100;
129,200; 0,300; 145,800) son cifras redondeadas transcriptas del
informe de cada semana, no un volcado crudo de `EXPLAIN ANALYZE`. El
plan (tipo de scan, nodo de Sort, filas descartadas) sí corresponde
a lo medido. La línea base de la consulta de pedidos en TP5 (Seq
Scan, ~25 ms) se tomó **sin** `idx_pedido_id_cliente`, que
`schema.sql` ya crea: con ese índice el plan es el de TP3 (Bitmap
Heap Scan, ~0,3 ms). En la carga integrada ese índice simple se
elimina después, porque queda cubierto por
`idx_pedido_cliente_fecha_desc`.

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

El mismo criterio se aplicó a índices repetidos. `idx_pedido_cliente_fecha_hora`
(TP3) es el mismo árbol que `idx_pedido_cliente_fecha_desc` (TP5).
`idx_detalle_pedido_facturacion` (TP4) es el mismo que
`idx_detalle_pedido_prod_covering` (TP5). En la carga integrada se
crea cada uno una sola vez, en `TP5_Indices_Vistas/indices.sql`, y
ahí se eliminan `idx_pedido_id_cliente` e `idx_detalle_pedido_id_producto`
de `schema.sql`, que quedan subsumidos por esos compuestos.

## 5. Uso de herramientas de IA

Herramientas del flujo habitual de cada TP: **Kiro** (especificación
de requerimientos antes de generar código) y **OpenCode** (agente de
codificación en terminal, en modo Plan antes de modo Build). El
detalle de qué se aceptó, modificó o descartó de cada propuesta está
en el `duia.md` de cada carpeta. Ningún script generado por IA se
ejecutó sin leerse línea por línea ni sin probarse primero sobre una
copia de trabajo, según el protocolo de seguridad de la cátedra.

Además, en la revisión de la entrega parcial se usó **Cursor**
(agente de código en el IDE) para detectar huecos y aplicar
correcciones sobre el SQL y la documentación ya entregados. No
reemplazó a Kiro/OpenCode en el trabajo original de cada TP: se usó
para revisión y remediación. Piezas que salieron de esa revisión y
se **aceptaron**:

- `FOR UPDATE` en el trigger de stock; orden fijo de ítems en
  `sp_registrar_pedido` para evitar deadlock.
- `HAVING` con umbral relativo al promedio entre categorías (un
  umbral fijo de 100.000 no filtraba nada con `data.sql`).
- `fn_total_pedido` en **PL/pgSQL** (no solo `LANGUAGE sql`), con
  excepción si el pedido no existe.
- Índice único parcial `uq_cliente_correo_vigente`, propagación de
  `eliminado` a vistas/MV/consultas, `sp_anular_pedido`, y
  `stock_descontado` para no reponer stock de la carga masiva.
- Deduplicación de índices idénticos entre TP3/TP4/TP5 y baja de
  índices subsumidos por compuestos.
- Corrección del reintento ante `40001`: no dentro del mismo
  `BEGIN`, sino transacción nueva desde el cliente.

Se **descartó** (misma lógica de sobreindexación que
`idx_pedido_forma_pago`): recrear `idx_detalle_pedido_vigente`
(casi redundante con el prefijo de la PK) y dejar el umbral fijo
del `HAVING`. El detalle ampliado está en los `duia.md` de TP2 y
TP5.

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
[`TP3/queries.sql`](TP3_Optimizacion_Indices/queries.sql),
[`TP4/queries.sql`](TP4_Reportes_Analiticos/queries.sql) y
[`TP5/queries.sql`](TP5_Indices_Vistas/queries.sql): JOIN,
`SUM`, subconsultas correlacionadas y no correlacionadas,
`DENSE_RANK() OVER`. El `HAVING` está en la consulta 10 de
[`TP5/queries.sql`](TP5_Indices_Vistas/queries.sql) (categorías con
facturación vigente por encima del promedio entre categorías). Las
consultas de ese archivo filtran `eliminado = FALSE`.

**6. Vistas, funciones y procedimientos en PL/pgSQL.** Vistas en
[`TP5_Indices_Vistas/views.sql`](TP5_Indices_Vistas/views.sql) y vista
materializada en [`materializadas.sql`](TP5_Indices_Vistas/materializadas.sql).
Función invocable en PL/pgSQL: `fn_total_pedido(id) RETURNS numeric`
(`SELECT fn_total_pedido(1);`; excepción si el pedido no existe).
Procedimientos con `CALL` en
[`TP5_Indices_Vistas/procedimientos.sql`](TP5_Indices_Vistas/procedimientos.sql):
`sp_registrar_pedido` (ítems ordenados por `id_producto` para evitar
deadlock con `FOR UPDATE`), `sp_anular_pedido` y `sp_dar_baja_cliente`.
Los triggers de stock e inmutabilidad siguen en
[`TP2/restricciones.sql`](TP2_Concurrencia_IA/restricciones.sql).

**7. Reglas de negocio con CHECK, UNIQUE y triggers** —
`CHECK`/`UNIQUE` en `schema.sql` (Parte 1) y en `TP2/restricciones.sql`;
triggers de stock (`FOR UPDATE` sobre `Producto`) y de inmutabilidad
del precio histórico en `TP2/restricciones.sql`. El trigger de
devolución de stock al anular una línea está en `soft_delete.sql`.

**8. Transacciones** (atomicidad, COMMIT/ROLLBACK, niveles de
aislamiento, control de concurrencia) —
[`TP2_Concurrencia_IA/informe_concurrencia.md`](TP2_Concurrencia_IA/informe_concurrencia.md):
atomicidad con `sp_registrar_pedido` (ítem sin stock → cero pedidos,
stock intacto), dos sesiones con `FOR UPDATE`, y reintento ante
`SQLSTATE 40001` **desde el cliente** con un `BEGIN` nuevo (no
dentro del mismo bloque).

**9. Borrado lógico (soft delete).** `Producto.activo = TRUE` significa
que se puede vender; `eliminado = TRUE` en Cliente, Pedido y
Detalle_Pedido significa dado de baja. Son flags de polaridad
opuesta y responden preguntas distintas. La baja está en
[`TP5_Indices_Vistas/soft_delete.sql`](TP5_Indices_Vistas/soft_delete.sql):
índice único parcial `uq_cliente_correo_vigente WHERE eliminado = FALSE`
(reemplaza el `UNIQUE` de `schema.sql`), índices parciales de
pedidos y detalles vigentes, y trigger que devuelve stock al anular
una línea. Las vistas, la vista materializada y
`TP5_Indices_Vistas/queries.sql` excluyen filas con
`eliminado = TRUE`. `sp_registrar_pedido` rechaza un cliente dado
de baja; `sp_anular_pedido` anula el pedido y repone stock solo si
la línea tenía `stock_descontado = TRUE` (los detalles de la carga
masiva no descontaron stock; anularlos no lo infla).

Ver el paso 9 de [`TP5_Indices_Vistas/README.md`](TP5_Indices_Vistas/README.md)
para aplicar `soft_delete.sql` y `procedimientos.sql`, y verificarlos
con `CALL` y `EXPLAIN ANALYZE`.
