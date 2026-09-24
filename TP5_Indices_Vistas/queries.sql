-- ============================================================
-- queries.sql — Consultas de negocio y analíticas de Food Store
-- Correr después de soft_delete.sql: filtran eliminado = FALSE.
-- Las mediciones "antes/después" del informe usan las consultas
-- de informe_mediciones.md, que no dependen de esa columna.
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
  AND eliminado = FALSE
  AND fecha_hora >= now() - interval '90 days'
ORDER BY fecha_hora DESC;

-- 3. Ítems vendidos dentro de un rango de precios unitarios.
--    Usada en reportes de ventas por rango de precio.
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM Detalle_Pedido
WHERE precio_unitario BETWEEN 4400 AND 4500
  AND eliminado = FALSE;

-- 4. Facturación total por categoría vigente, de mayor a menor.
--    Excluye productos dados de baja y categorías sin ventas.
SELECT
    c.nombre_categoria,
    SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
JOIN Pedido pe ON pe.id_pedido = dp.id_pedido
WHERE p.activo = TRUE
  AND dp.eliminado = FALSE
  AND pe.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre_categoria
ORDER BY total_recaudado DESC;

-- 5. Clientes registrados que nunca hicieron un pedido.
SELECT c.id_cliente, c.nombre, c.correo
FROM Cliente c
WHERE c.eliminado = FALSE
  AND NOT EXISTS (
    SELECT 1
    FROM Pedido p
    WHERE p.id_cliente = c.id_cliente
      AND p.eliminado = FALSE
);

-- ============================================================
-- Ampliación — Semana 4: consultas analíticas con múltiples JOIN,
-- agregación, función de ventana y subconsulta correlacionada.
-- ============================================================

-- 6. Facturación acumulada por categoría y producto vigente (top 10).
SELECT
    c.nombre_categoria,
    p.nombre_producto,
    SUM(dp.cantidad * dp.precio_unitario) AS total_facturado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
JOIN Pedido pe ON pe.id_pedido = dp.id_pedido
WHERE p.activo = TRUE
  AND dp.eliminado = FALSE
  AND pe.eliminado = FALSE
GROUP BY c.nombre_categoria, p.nombre_producto
ORDER BY total_facturado DESC
LIMIT 10;

-- 7. Clientes con mayor volumen de compra en los últimos 180 días (top 10).
SELECT
    c.id_cliente,
    c.nombre,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM Cliente c
JOIN Pedido p ON c.id_cliente = p.id_cliente
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.eliminado = FALSE
  AND c.eliminado = FALSE
  AND dp.eliminado = FALSE
  AND p.fecha_hora >= now() - interval '180 days'
GROUP BY c.id_cliente, c.nombre
ORDER BY monto_total DESC
LIMIT 10;

-- 8. Ranking de productos vigentes por unidades vendidas dentro de su categoría
--    (numeración densa: los empates comparten puesto sin saltar números).
SELECT
    c.nombre_categoria,
    p.id_producto,
    p.nombre_producto,
    SUM(dp.cantidad) AS total_unidades,
    DENSE_RANK() OVER (
        PARTITION BY c.id_categoria
        ORDER BY SUM(dp.cantidad) DESC
    ) AS puesto_ranking
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
JOIN Pedido pe ON pe.id_pedido = dp.id_pedido
WHERE p.activo = TRUE
  AND dp.eliminado = FALSE
  AND pe.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto;

-- 10. HAVING: categorías cuya facturación vigente supera un umbral.
--     HAVING filtra el agregado; WHERE no puede hacerlo.
SELECT
    c.nombre_categoria,
    SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
JOIN Pedido pe ON pe.id_pedido = dp.id_pedido
WHERE dp.eliminado = FALSE
  AND pe.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre_categoria
HAVING SUM(dp.cantidad * dp.precio_unitario) > 100000
ORDER BY total_recaudado DESC;

-- 9. Fecha y monto del pedido vigente más reciente de cada cliente.
SELECT
    c.id_cliente,
    c.nombre,
    p.fecha_hora,
    (SELECT SUM(dp.cantidad * dp.precio_unitario)
     FROM Detalle_Pedido dp
     WHERE dp.id_pedido = p.id_pedido
       AND dp.eliminado = FALSE) AS monto_total
FROM Cliente c
JOIN Pedido p ON c.id_cliente = p.id_cliente
WHERE c.eliminado = FALSE
  AND p.eliminado = FALSE
  AND p.fecha_hora = (
    SELECT MAX(p2.fecha_hora)
    FROM Pedido p2
    WHERE p2.id_cliente = c.id_cliente
      AND p2.eliminado = FALSE
);
