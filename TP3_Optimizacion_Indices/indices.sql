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
-- En la carga integrada se elimina en TP5_Indices_Vistas/indices.sql
-- al crear idx_producto_cat_precio_activo (mismo criterio de dedup).

-- 2. Consulta 2: historial de pedidos de un cliente ordenado por
--    fecha descendente. El índice que quedó en el proyecto es
--    idx_pedido_cliente_fecha_desc, creado una sola vez en
--    TP5_Indices_Vistas/indices.sql sobre (id_cliente, fecha_hora DESC).
--    No se vuelve a crear acá: sería el mismo índice con otro nombre
--    (sobreindexación, el mismo criterio con el que se descartó
--    idx_pedido_forma_pago).

-- 3. Consulta 3: ítems de Detalle_Pedido dentro de un rango de
--    precio_unitario. Antes: Seq Scan sobre 400.000 filas,
--    129.200 ms. Después: Bitmap Heap Scan, 16.900 ms.
CREATE INDEX idx_detalle_pedido_precio
ON Detalle_Pedido (precio_unitario);
