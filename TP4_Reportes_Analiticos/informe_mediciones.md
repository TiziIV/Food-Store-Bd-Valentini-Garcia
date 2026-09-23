# Informe de mediciones — TP4 (Unidad 2, Semana 4)

Reportes analíticos asistidos por IA sobre Food Store: joins,
subconsultas, agregación y funciones de ventana. Continúa sobre la
misma base masiva del TP3 (ver
[`TP3_Optimizacion_Indices/informe_mediciones.md`](../TP3_Optimizacion_Indices/informe_mediciones.md)).

## Parte 1 — Consultas analíticas lentas (multi-JOIN y agregación)

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
|---|---|---|---|---|
| 1. Facturación por categoría y producto activo | Hash Join entre Producto/Categoria + Hash Join masivo con Seq Scan completo sobre 400.000 filas de Detalle_Pedido. Cost 11850.00..12450.00, ~145.800 ms. | `idx_producto_activo_categoria` + `idx_detalle_pedido_facturacion` (ver `indices.sql`) | Hash Join asistido por Index Only Scan y mapa de bits. Cost 5420.00..5890.00, ~38.400 ms. | 73,6% más rápido (~3,8x) |
| 2. Clientes por mayor gasto (últimos 180 días) | Hash Join entre Pedido/Cliente + Hash Join con Detalle_Pedido, tras Seq Scan sobre 200.000 filas de Pedido. Cost 14200.00..14850.00, ~168.500 ms. | `idx_pedido_fecha_cliente` + reescritura con pre-agregación por CTE (ver `queries.sql`) | Bitmap Index Scan sobre el índice de fecha/cliente + Hash Join sobre conjunto reducido. Cost 4150.00..4620.00, ~42.100 ms. | 75,0% más rápido (~4,0x) |

## Parte 2 — Lectura crítica de planes de join interpretados por IA

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "En el Nested Loop, Producto funciona como la relación interna (inner) porque tiene índice, y Detalle_Pedido es la relación externa (outer) que se recorre primero." | No | Confunde externa con interna. La relación externa es el conjunto conductor pequeño (productos filtrados); por cada una de sus filas se busca en la relación interna indexada (Detalle_Pedido). Al revés, se harían 400.000 búsquedas individuales. |
| "El costo inicial del Hash Join (cost=1520.00) demuestra que la consulta tardó 1,5 segundos en construir la tabla hash." | No | Confunde costo estimado (unidad arbitraria de I/O y CPU) con tiempo real en milisegundos. El tiempo real de inicialización del Hash lo indica `actual time=18.200 ms`. |
| "El optimizador eligió Hash Join porque Detalle_Pedido no tiene Primary Key definida." | No | Falso: `Detalle_Pedido` sí tiene PK compuesta `(id_pedido, id_producto)`. El optimizador elige Hash Join por volumen de filas (cientos de miles), no por ausencia de PK. |

## Parte 3 — Consultas resumen, rankings y subconsultas (resultado)

Ranking con `DENSE_RANK()` de unidades vendidas por producto vigente
dentro de su categoría, y fecha/monto del pedido más reciente por
cliente vía subconsulta correlacionada — ambas con verificación
`EXCEPT` en ambos sentidos (0 filas). Ver [`queries.sql`](queries.sql).

## Parte 4 — Competencia de optimización entre equipos

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| Grupo de trabajo (García - Valentini) | Índice multinivel `idx_pedido_fecha_cliente (fecha_hora, id_cliente)` + reestructuración con CTEs (`PedidosRecientes`, `TotalesPorPedido`) para acotar el volumen antes de la combinación final. | 168.5 | 42.1 | ~4,0x |
