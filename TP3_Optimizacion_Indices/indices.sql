-- ============================================================
-- indices.sql — TP3 (Unidad 2, Semana 3)
-- Optimización asistida por IA sobre Food Store: filtros, planes
-- de ejecución e índices.
-- ============================================================
-- Índices propuestos y aceptados a partir de EXPLAIN ANALYZE
-- sobre la base masiva (ver informe_mediciones.md para el plan
-- completo antes/después de cada uno).
-- ============================================================

-- 1. Consulta 1: productos de una categoría por encima de un precio
--    (Producto.id_categoria = ? AND Producto.precio_actual > ?).
--    Antes: Seq Scan, 13.100 ms. Después: Bitmap Heap Scan, 3.600 ms.
CREATE INDEX idx_producto_categoria_precio
ON Producto (id_categoria, precio_actual);

-- 2. Consulta 2: historial de pedidos de un cliente ordenado por
--    fecha descendente (Pedido.id_cliente = ? AND fecha_hora >= ?
--    ORDER BY fecha_hora DESC). Antes: Sort + Bitmap Heap Scan,
--    0.300 ms. Después: Index Scan sin nodo de Sort, 0.200 ms.
CREATE INDEX idx_pedido_cliente_fecha_hora
ON Pedido (id_cliente, fecha_hora DESC);

-- 3. Consulta 3: ítems de Detalle_Pedido dentro de un rango de
--    precio_unitario. Antes: Seq Scan sobre 400.000 filas,
--    129.200 ms. Después: Bitmap Heap Scan, 16.900 ms.
CREATE INDEX idx_detalle_pedido_precio
ON Detalle_Pedido (precio_unitario);
