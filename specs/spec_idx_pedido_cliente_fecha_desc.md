# spec: idx_pedido_cliente_fecha_desc

Objetivo: acelerar el historial cronológico de pedidos de un
cliente, evitando un ordenamiento explícito en memoria.

Consulta afectada:
```sql
SELECT id_pedido, fecha_hora, forma_pago
FROM Pedido
WHERE id_cliente = 12450
ORDER BY fecha_hora DESC;
```

Columnas candidatas:
- id_cliente (igualdad, clave foránea, alta selectividad por
  cliente individual)
- fecha_hora DESC (orden de la cláusula ORDER BY; al indexarla en
  el mismo sentido se evita el nodo Sort)

Criterio de aceptación: el plan pasa de Seq Scan + Sort a Index
Scan puro, y el tiempo de ejecución baja al menos un orden de
magnitud.

Resultado obtenido: Sort + Seq Scan (25.100 ms) → Index Scan
(0.080 ms). Mejora del 99,7% (factor ≈314x). Aceptado sin
modificaciones.
