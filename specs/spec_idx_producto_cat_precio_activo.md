# spec: idx_producto_cat_precio_activo

Objetivo: acelerar la búsqueda de productos activos por categoría y
rango de precio en el catálogo (consulta de alta frecuencia en la
sección de listado/filtro de la tienda).

Consulta afectada:
```sql
SELECT id_producto, nombre_producto, precio_actual
FROM Producto
WHERE id_categoria = 5
  AND activo = TRUE
  AND precio_actual BETWEEN 1500.00 AND 3500.00;
```

Columnas candidatas:
- id_categoria (igualdad, alta selectividad combinada con precio)
- precio_actual (rango, va después de la columna de igualdad)
- activo (condición de filtro parcial, no de indexado directo)

Criterio de aceptación: el plan pasa de Seq Scan a Bitmap Heap
Scan / Index Scan, y el tiempo de ejecución baja al menos un
70% respecto de la línea base.

Resultado obtenido: Seq Scan (14.500 ms) → Bitmap Heap Scan
(2.500 ms). Mejora del 82,7%. Aceptado sin modificaciones.
