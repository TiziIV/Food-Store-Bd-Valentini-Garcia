# spec: mv_facturacion_categoria_mes

Objetivo: acelerar el reporte gerencial de facturación agregada
por categoría y por mes, hoy costoso porque recorre las 400.000
filas de Detalle_Pedido cruzándolas con Producto, Categoria y
Pedido en cada consulta.

Consulta original (costosa):
```sql
SELECT c.id_categoria, c.nombre_categoria,
       date_trunc('month', pe.fecha_hora)::date AS mes,
       SUM(dp.cantidad * dp.precio_unitario) AS total_facturado,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos
FROM Detalle_Pedido dp
JOIN Producto p ON dp.id_producto = p.id_producto
JOIN Categoria c ON p.id_categoria = c.id_categoria
JOIN Pedido pe ON dp.id_pedido = pe.id_pedido
GROUP BY c.id_categoria, c.nombre_categoria,
         date_trunc('month', pe.fecha_hora);
```

Columnas candidatas para el índice de la vista materializada:
id_categoria y mes (juntas forman una clave única por fila del
reporte, y permiten REFRESH CONCURRENTLY).

Criterio de aceptación: la vista materializada debe crearse con
WITH DATA, contar con un índice único sobre (id_categoria, mes),
y el tiempo de consulta contra la vista debe ser al menos dos
órdenes de magnitud menor que el de la consulta original.

Resultado obtenido: consulta original 810,450 ms → consulta
contra la vista materializada 1,150 ms. Mejora del 99,86%
(factor ≈705x). Aceptada con el agregado de cantidad_pedidos
como métrica adicional.

Frecuencia de refresco definida: diaria, fuera de horario pico
(03:00 AM), vía REFRESH MATERIALIZED VIEW CONCURRENTLY. Se
descartó un refresco horario por generar carga de escritura
evitable para un reporte de uso mensual.
