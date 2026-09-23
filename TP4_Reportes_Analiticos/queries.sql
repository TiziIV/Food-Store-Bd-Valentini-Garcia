-- ============================================================
-- queries.sql — TP4 (Unidad 2, Semana 4)
-- Consultas analíticas de la Parte 1 (con índices aplicados) y
-- de la Parte 3 (ranking con función de ventana + subconsulta
-- correlacionada), con sus versiones alternativas y verificación
-- de equivalencia.
-- ============================================================

-- ------------------------------------------------------------
-- Parte 1 — Consulta 1: facturación acumulada por categoría y
-- producto activo (top 10).
-- ------------------------------------------------------------
SELECT
    c.nombre_categoria,
    p.nombre_producto,
    SUM(dp.cantidad * dp.precio_unitario) AS total_facturado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
WHERE p.activo = TRUE
GROUP BY c.nombre_categoria, p.nombre_producto
ORDER BY total_facturado DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Parte 1 — Consulta 2: clientes con mayor volumen de compra en
-- los últimos 180 días (top 10), reescrita con CTE de
-- pre-agregación para reducir el tamaño del join antes de
-- agrupar (aplica idx_pedido_fecha_cliente de indices.sql).
-- ------------------------------------------------------------

-- Versión original (antes de optimizar)
SELECT
    c.id_cliente,
    c.nombre,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM Cliente c
JOIN Pedido p ON c.id_cliente = p.id_cliente
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.fecha_hora >= now() - interval '180 days'
GROUP BY c.id_cliente, c.nombre
ORDER BY monto_total DESC
LIMIT 10;

-- Versión reescrita con pre-agregación (CTE)
WITH PedidosRecientes AS (
    SELECT id_pedido, id_cliente
    FROM Pedido
    WHERE fecha_hora >= now() - interval '180 days'
),
TotalesPorPedido AS (
    SELECT dp.id_pedido, SUM(dp.cantidad * dp.precio_unitario) AS total_pedido
    FROM Detalle_Pedido dp
    WHERE dp.id_pedido IN (SELECT id_pedido FROM PedidosRecientes)
    GROUP BY dp.id_pedido
)
SELECT
    c.id_cliente,
    c.nombre,
    COUNT(pr.id_pedido) AS total_pedidos,
    SUM(tp.total_pedido) AS monto_total
FROM Cliente c
JOIN PedidosRecientes pr ON c.id_cliente = pr.id_cliente
JOIN TotalesPorPedido tp ON pr.id_pedido = tp.id_pedido
GROUP BY c.id_cliente, c.nombre
ORDER BY monto_total DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Parte 3.A — Ranking con función de ventana: unidades vendidas
-- por producto vigente dentro de su categoría (DENSE_RANK).
-- ------------------------------------------------------------

-- Versión 1
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
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto;

-- Versión 2 (estructura alternativa con subconsulta en el FROM)
SELECT
    sub.nombre_categoria,
    sub.id_producto,
    sub.nombre_producto,
    sub.total_unidades,
    DENSE_RANK() OVER (
        PARTITION BY sub.id_categoria
        ORDER BY sub.total_unidades DESC
    ) AS puesto_ranking
FROM (
    SELECT
        c.id_categoria,
        c.nombre_categoria,
        p.id_producto,
        p.nombre_producto,
        SUM(dp.cantidad) AS total_unidades
    FROM Categoria c
    JOIN Producto p ON c.id_categoria = p.id_categoria
    JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
    WHERE p.activo = TRUE
    GROUP BY c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto
) sub;

-- Verificación de equivalencia (ambos sentidos)
(
    SELECT
        c.nombre_categoria, p.id_producto, p.nombre_producto,
        SUM(dp.cantidad) AS total_unidades,
        DENSE_RANK() OVER (PARTITION BY c.id_categoria ORDER BY SUM(dp.cantidad) DESC) AS puesto_ranking
    FROM Categoria c
    JOIN Producto p ON c.id_categoria = p.id_categoria
    JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
    WHERE p.activo = TRUE
    GROUP BY c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto
)
EXCEPT
(
    SELECT
        sub.nombre_categoria, sub.id_producto, sub.nombre_producto,
        sub.total_unidades,
        DENSE_RANK() OVER (PARTITION BY sub.id_categoria ORDER BY sub.total_unidades DESC) AS puesto_ranking
    FROM (
        SELECT c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto,
               SUM(dp.cantidad) AS total_unidades
        FROM Categoria c
        JOIN Producto p ON c.id_categoria = p.id_categoria
        JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
        WHERE p.activo = TRUE
        GROUP BY c.id_categoria, c.nombre_categoria, p.id_producto, p.nombre_producto
    ) sub
);

-- ------------------------------------------------------------
-- Parte 3.B — Subconsulta correlacionada: fecha y monto del
-- pedido más reciente de cada cliente con al menos un pedido.
-- ------------------------------------------------------------

-- Versión 1 (subconsulta correlacionada en el WHERE)
SELECT
    c.id_cliente,
    c.nombre,
    p.fecha_hora,
    (SELECT SUM(dp.cantidad * dp.precio_unitario)
     FROM Detalle_Pedido dp
     WHERE dp.id_pedido = p.id_pedido) AS monto_total
FROM Cliente c
JOIN Pedido p ON c.id_cliente = p.id_cliente
WHERE p.fecha_hora = (
    SELECT MAX(p2.fecha_hora)
    FROM Pedido p2
    WHERE p2.id_cliente = c.id_cliente
);

-- Versión 2 (JOIN con agrupación MAX, sin correlacionada)
WITH UltimoPedido AS (
    SELECT id_cliente, MAX(fecha_hora) AS max_fecha
    FROM Pedido
    GROUP BY id_cliente
)
SELECT
    c.id_cliente,
    c.nombre,
    p.fecha_hora,
    SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM Cliente c
JOIN UltimoPedido up ON c.id_cliente = up.id_cliente
JOIN Pedido p ON up.id_cliente = p.id_cliente AND up.max_fecha = p.fecha_hora
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, p.fecha_hora, p.id_pedido;

-- Verificación de equivalencia (ambos sentidos)
(
    SELECT c.id_cliente, c.nombre, p.fecha_hora,
           (SELECT SUM(dp.cantidad * dp.precio_unitario) FROM Detalle_Pedido dp WHERE dp.id_pedido = p.id_pedido) AS monto_total
    FROM Cliente c
    JOIN Pedido p ON c.id_cliente = p.id_cliente
    WHERE p.fecha_hora = (SELECT MAX(p2.fecha_hora) FROM Pedido p2 WHERE p2.id_cliente = c.id_cliente)
)
EXCEPT
(
    WITH UltimoPedido AS (
        SELECT id_cliente, MAX(fecha_hora) AS max_fecha FROM Pedido GROUP BY id_cliente
    )
    SELECT c.id_cliente, c.nombre, p.fecha_hora, SUM(dp.cantidad * dp.precio_unitario) AS monto_total
    FROM Cliente c
    JOIN UltimoPedido up ON c.id_cliente = up.id_cliente
    JOIN Pedido p ON up.id_cliente = p.id_cliente AND up.max_fecha = p.fecha_hora
    JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
    GROUP BY c.id_cliente, c.nombre, p.fecha_hora, p.id_pedido
);
