-- ============================================================
-- queries.sql — Consultas de negocio y analíticas de Food Store
-- Heredado de la Unidad 2 (Semana 3): consultas usadas como carga
-- de trabajo real para el laboratorio de optimización e indexado.
-- ============================================================

-- 1. Catálogo: productos de una categoría por encima de un precio.
--    Usada en la sección de listado/filtro de la tienda.
SELECT id_producto, nombre_producto, precio_actual
FROM Producto
WHERE id_categoria = 3
  AND precio_actual > 2500;

-- 2. Historial cronológico de pedidos de un cliente (más recientes primero).
--    Usada en la sección "mis pedidos".
SELECT id_pedido, fecha_hora, forma_pago
FROM Pedido
WHERE id_cliente = 1500
  AND fecha_hora >= now() - interval '90 days'
ORDER BY fecha_hora DESC;

-- 3. Ítems vendidos dentro de un rango de precios unitarios.
--    Usada en reportes de ventas por rango de precio.
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM Detalle_Pedido
WHERE precio_unitario BETWEEN 4400 AND 4500;

-- 4. Facturación total por categoría vigente, de mayor a menor.
--    Excluye productos dados de baja y categorías sin ventas.
SELECT
    c.nombre_categoria,
    SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria
ORDER BY total_recaudado DESC;

-- 5. Clientes registrados que nunca hicieron un pedido.
SELECT c.id_cliente, c.nombre, c.correo
FROM Cliente c
WHERE NOT EXISTS (
    SELECT 1
    FROM Pedido p
    WHERE p.id_cliente = c.id_cliente
);
