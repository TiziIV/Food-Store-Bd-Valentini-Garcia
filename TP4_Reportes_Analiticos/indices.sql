-- ============================================================
-- indices.sql — TP4 (Unidad 2, Semana 4)
-- Reportes analíticos asistidos por IA sobre Food Store: joins,
-- subconsultas, agregación y ventana.
-- ============================================================

-- Consulta 1: facturación acumulada por categoría y producto
-- vigente (JOIN Categoria + Producto + Detalle_Pedido). Antes:
-- Hash Join masivo con Seq Scan sobre Detalle_Pedido, 145.800 ms.

-- 1a. Índice parcial: omite productos inactivos y ya trae la
--     categoría, para acelerar el primer Hash Join.
CREATE INDEX idx_producto_activo_categoria
ON Producto (id_producto, id_categoria)
WHERE activo = TRUE;

-- 1b. Covering index sobre Detalle_Pedido: permite calcular el
--     subtotal (cantidad * precio_unitario) sin volver al heap.
CREATE INDEX idx_detalle_pedido_facturacion
ON Detalle_Pedido (id_producto)
INCLUDE (cantidad, precio_unitario);

-- Después de 1a + 1b: Hash Join asistido por Index Only Scan,
-- 38.400 ms (73,6% más rápido).

-- Consulta 2: clientes con mayor volumen de compra en los
-- últimos 180 días (JOIN Cliente + Pedido + Detalle_Pedido).
-- Antes: Seq Scan sobre 200.000 filas de Pedido, 168.500 ms.

-- 2. Índice compuesto para acelerar el filtro de rango temporal
--    junto con la FK a Cliente.
CREATE INDEX idx_pedido_fecha_cliente
ON Pedido (fecha_hora, id_cliente);

-- Después de 2 (+ reescritura con CTE de pre-agregación en
-- queries.sql): Bitmap Index Scan + Hash Join reducido,
-- 42.100 ms (75,0% más rápido).
