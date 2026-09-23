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
├── specs/                   (especificaciones entregadas a Kiro)
├── duia.md                  (bitácora de uso de IA)
├── informe_mediciones.md    (EXPLAIN ANALYZE antes/después)
└── README.md
```

## Requisitos

- PostgreSQL 16 o superior.
- `psql` disponible en la terminal.

## Cómo reproducir las pruebas

1. Crear la base y cargar el esquema y los datos (parado en la raíz
   del repositorio, en este orden):

```bash
createdb food_store
psql -d food_store -f TP1_FoodStore/schema.sql
psql -d food_store -f TP5_Indices_Vistas/data.sql
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

3. Medir cada consulta de `queries.sql` **antes** de indexar:

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

6. Crear las vistas y verificar equivalencia:

```bash
psql -d food_store -f TP5_Indices_Vistas/views.sql
```

Para cada vista, ejecutar la comparación con `EXCEPT` en ambos
sentidos contra la consulta manual equivalente (ver ejemplos en
`informe_mediciones.md`). El resultado esperado es 0 filas.

7. Crear la vista materializada y medir el reporte:

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

## Flujo de trabajo con IA

Cada índice, vista y la vista materializada siguieron el mismo
proceso: especificación en Kiro (carpeta `specs/`), generación del
SQL con OpenCode, lectura línea por línea antes de ejecutar, prueba
sobre una copia de la base, y un commit de Git separado y
descriptivo por cada objeto creado. El detalle de qué se aceptó,
modificó o descartó de cada propuesta de la IA está en `duia.md`.

## Notas

- No se modificó el modelo de datos heredado (tablas, tipos ni
  restricciones): todo lo agregado en esta entrega son índices y
  vistas.
- `vista_pedidos_cliente` usa la entidad `Cliente` definida desde
  TP1 (no `Usuario`), ocultando el `telefono` como dato de
  contacto sensible, ya que el proyecto no modela autenticación.
- Los archivos de esta entrega se reutilizan en la Semana 6
  (procedimientos, funciones y disparadores), por lo que no deben
  eliminarse ni reescribirse.
