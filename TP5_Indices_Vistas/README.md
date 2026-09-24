# TP5 — Índices, Vistas y Vistas Materializadas

Unidad 3, Semana 5 — Base de Datos II

Esta carpeta es la última pieza del proyecto integrador Food Store
dentro del repositorio dividido por TP. El esquema (`schema.sql`)
vive en [`TP1_FoodStore/`](../TP1_FoodStore/); esta carpeta solo
agrega objetos nuevos sobre ese esquema, sin modificarlo.

## Estructura de esta carpeta

```
TP5_Indices_Vistas/
├── data.sql                (heredado de TP1, ampliado con la carga
│                             masiva de TP3/TP4)
├── queries.sql              (heredado de TP3/TP4)
├── indices.sql              (nuevo — Parte A)
├── views.sql                (nuevo — Parte B)
├── materializadas.sql       (nuevo — Parte C)
├── soft_delete.sql          (borrado lógico en Cliente, Pedido y
│                             Detalle_Pedido)
├── procedimientos.sql       (procedimientos PL/pgSQL invocados con CALL)
├── specs/                   (especificaciones entregadas a Kiro)
├── duia.md                  (bitácora de uso de IA)
├── informe_mediciones.md    (EXPLAIN ANALYZE antes/después)
└── README.md
```

## Requisitos

- PostgreSQL 16 o superior.
- `psql` disponible en la terminal.

## Cómo reproducir las pruebas

1. Crear la base, cargar el esquema y **después** los datos. El
   trigger de stock va después de `data.sql`: si está activo durante
   la carga, los ~400.000 detalles con stock aleatorio de 0 a 200
   fallan y el `COMMIT` de `data.sql` no llega a guardarse.

```bash
createdb food_store
psql -d food_store -f TP1_FoodStore/schema.sql
psql -d food_store -f TP5_Indices_Vistas/data.sql
psql -d food_store -f TP2_Concurrencia_IA/restricciones.sql
```

2. Confirmar el volumen de datos (se usó como referencia: 50.000
   productos, 20.000 clientes, 200.000 pedidos, 400.000 detalles):

```sql
SELECT
  (SELECT count(*) FROM Producto)       AS productos,
  (SELECT count(*) FROM Cliente)        AS clientes,
  (SELECT count(*) FROM Pedido)         AS pedidos,
  (SELECT count(*) FROM Detalle_Pedido) AS detalles;
```

3. Medir las tres consultas de `informe_mediciones.md` **antes** de
   indexar (no usar todavía `queries.sql`: esa versión filtra
   `eliminado` y se corre después del paso 6).

   El informe documenta Seq Scan sobre pedidos/detalles. Para
   reproducir esa línea base hay que sacar antes los índices simples
   que ya crea `schema.sql` (si no, el plan usa Bitmap Heap Scan y
   no coincide con el "antes" del informe):

```sql
DROP INDEX IF EXISTS idx_pedido_id_cliente;
DROP INDEX IF EXISTS idx_detalle_pedido_id_producto;
```

```sql
EXPLAIN ANALYZE
SELECT id_producto, nombre_producto, precio_actual
FROM Producto
WHERE id_categoria = 5 AND activo = TRUE
  AND precio_actual BETWEEN 1500.00 AND 3500.00;
```

(repetir con las consultas 2 y 3 documentadas en
`informe_mediciones.md`)

4. Aplicar los índices y volver a medir:

```bash
psql -d food_store -f TP5_Indices_Vistas/indices.sql
```

Repetir los mismos `EXPLAIN ANALYZE` del paso 3 y comparar planes
y tiempos contra `informe_mediciones.md`.

5. Medir el costo de escritura (antes y después de indices.sql)
   con el lote de INSERT documentado en `informe_mediciones.md`,
   idealmente sobre una copia de la tabla o dentro de una
   transacción que luego se revierte (`BEGIN; ... ROLLBACK;`).

6. Borrado lógico, y recién ahí las vistas (filtran `eliminado`):

```bash
psql -d food_store -f TP5_Indices_Vistas/soft_delete.sql
psql -d food_store -f TP5_Indices_Vistas/views.sql
```

Para cada vista, el `EXCEPT` en ambos sentidos se compara contra la
consulta manual **con el mismo** `WHERE eliminado = FALSE`. El
resultado esperado es 0 filas.

7. Crear la vista materializada (también excluye anulados) y medir:

```bash
psql -d food_store -f TP5_Indices_Vistas/materializadas.sql
```

```sql
-- Antes (consulta original, sin materializar): ver informe_mediciones.md
-- Después:
EXPLAIN ANALYZE SELECT * FROM mv_facturacion_categoria_mes;
```

8. Refresco periódico recomendado (no se ejecuta en la carga
   inicial, solo se documenta para producción):

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

9. Procedimientos con `CALL` y la función `fn_total_pedido`:

```bash
psql -d food_store -f TP5_Indices_Vistas/procedimientos.sql
```

Verificación, dentro de una transacción de prueba según
`protocolo_seguridad.md`:

```sql
BEGIN;

CALL sp_registrar_pedido(1500, 'EFECTIVO',
    '[{"id_producto": 1, "cantidad": 2}]'::jsonb);
-- psql devuelve el id_pedido generado. Con ese id:
-- SELECT fn_total_pedido(<id_pedido>);

CALL sp_dar_baja_cliente(1500);
SELECT id_cliente, eliminado FROM Cliente WHERE id_cliente = 1500;

-- Un segundo CALL sp_registrar_pedido(1500, ...) debe fallar:
-- el cliente ya está dado de baja.

EXPLAIN ANALYZE
SELECT id_pedido, fecha_hora FROM Pedido
WHERE id_cliente = 1500 AND eliminado = FALSE
ORDER BY fecha_hora DESC;

ROLLBACK;
```

Resultado esperado: `sp_registrar_pedido` devuelve el `id_pedido`
generado y descuenta stock vía el trigger de TP2 (con `FOR UPDATE`);
`SELECT fn_total_pedido(...)` devuelve el total vigente;
`sp_dar_baja_cliente` deja `eliminado = TRUE` en el cliente 1500; el
plan usa `idx_pedido_vigente_cliente_fecha`. Para anular un pedido
ya cargado y reponer stock: `CALL sp_anular_pedido(<id>);` y volver
a consultar `fn_total_pedido`, que devuelve 0.

## Flujo de trabajo con IA

Cada índice, vista y la vista materializada siguieron el mismo
proceso: especificación en Kiro (carpeta `specs/`), generación del
SQL con OpenCode, lectura línea por línea antes de ejecutar, prueba
sobre una copia de la base, y un commit de Git separado y
descriptivo por cada objeto creado. El detalle de qué se aceptó,
modificó o descartó de cada propuesta de la IA está en `duia.md`.

## Notas

- El plan de indexado, las vistas y la vista materializada (Partes
  A, B y C) no modifican el modelo de datos heredado (tablas, tipos
  ni restricciones): todo lo agregado ahí son índices y vistas.
- `vista_pedidos_cliente` usa la entidad `Cliente` definida desde
  TP1 (no `Usuario`), ocultando el `telefono` como dato de
  contacto sensible, ya que el proyecto no modela autenticación.
- `soft_delete.sql` sí amplía el modelo (agrega `eliminado` a
  `Cliente`, `Pedido` y `Detalle_Pedido`), pero como `ALTER TABLE`
  posterior, sin reescribir `TP1_FoodStore/schema.sql` — ese archivo
  queda intacto como el DDL originalmente entregado y corregido en
  el TP1.
- `procedimientos.sql` reutiliza el trigger `fn_validar_stock_pedido`
  de `TP2_Concurrencia_IA/restricciones.sql`. Ese script se aplica
  después de `data.sql` y antes de los `CALL`.
