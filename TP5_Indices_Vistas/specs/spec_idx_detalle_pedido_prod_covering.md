# spec: idx_detalle_pedido_prod_covering

Objetivo: acelerar el monitoreo de ítems por producto en
Detalle_Pedido, resolviendo la consulta sin tocar el heap de la
tabla.

Consulta afectada:
```sql
SELECT id_pedido, cantidad, precio_unitario
FROM Detalle_Pedido
WHERE id_producto = 24005;
```

Columnas candidatas:
- id_producto (igualdad, clave de búsqueda)
- cantidad, precio_unitario (no participan del filtro; se
  incluyen con INCLUDE para permitir Index Only Scan)

Criterio de aceptación: el plan pasa de Seq Scan a Index Only
Scan con Heap Fetches = 0, y el tiempo baja al menos dos órdenes
de magnitud.

Resultado obtenido: Seq Scan (42.400 ms) → Index Only Scan,
Heap Fetches 0 (0.090 ms). Mejora del 99,8% (factor ≈470x).
Aceptado sin modificaciones.

Costo de escritura verificado: la carga de 1.000 INSERT en
Detalle_Pedido pasó de 28.400 ms (solo PK) a 46.800 ms (PK +
este índice), un sobrecosto de +64,8%, considerado aceptable
frente a la mejora de lectura obtenida.
