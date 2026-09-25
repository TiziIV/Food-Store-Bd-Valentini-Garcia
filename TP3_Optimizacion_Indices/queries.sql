-- ============================================================
-- queries.sql — TP3 (Unidad 2, Semana 3), Parte 4
-- Consultas resumen y subconsultas bajo especificación precisa.
-- Snapshot de la Semana 3: no filtra eliminado (soft delete es
-- posterior, en TP5). Versión consolidada: TP5_Indices_Vistas/queries.sql
-- ============================================================

-- ------------------------------------------------------------
-- Consulta 1: recaudación total por categoría vigente.
-- Spec: "para cada categoría vigente (activo = TRUE), el nombre
-- de la categoría y el monto total histórico recaudado por
-- ventas de productos de esa categoría. Ordenar de mayor a menor
-- recaudación, excluyendo categorías sin ventas."
-- ------------------------------------------------------------

-- Versión IA (JOINs explícitos con agregación)
SELECT
    c.nombre_categoria,
    SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria
ORDER BY total_recaudado DESC;

-- Versión propia alternativa (CTE con subconsulta agrupada por producto)
WITH VentasPorProducto AS (
    SELECT
        dp.id_producto,
        SUM(dp.cantidad * dp.precio_unitario) AS subtotal
    FROM Detalle_Pedido dp
    GROUP BY dp.id_producto
)
SELECT
    c.nombre_categoria,
    SUM(v.subtotal) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN VentasPorProducto v ON p.id_producto = v.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria
ORDER BY total_recaudado DESC;

-- Verificación de equivalencia (debe dar 0 filas en ambos sentidos)
WITH VentasPorProducto AS (
    SELECT dp.id_producto, SUM(dp.cantidad * dp.precio_unitario) AS subtotal
    FROM Detalle_Pedido dp
    GROUP BY dp.id_producto
)
SELECT c.nombre_categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria
EXCEPT
SELECT c.nombre_categoria, SUM(v.subtotal) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN VentasPorProducto v ON p.id_producto = v.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria;

-- Sentido inverso de la verificación (la consigna exige comprobar
-- ambos sentidos, no solo uno — ver nota en informe_mediciones.md)
WITH VentasPorProducto AS (
    SELECT dp.id_producto, SUM(dp.cantidad * dp.precio_unitario) AS subtotal
    FROM Detalle_Pedido dp
    GROUP BY dp.id_producto
)
SELECT c.nombre_categoria, SUM(v.subtotal) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN VentasPorProducto v ON p.id_producto = v.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria
EXCEPT
SELECT c.nombre_categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_recaudado
FROM Categoria c
JOIN Producto p ON c.id_categoria = p.id_categoria
JOIN Detalle_Pedido dp ON p.id_producto = dp.id_producto
WHERE p.activo = TRUE
GROUP BY c.id_categoria, c.nombre_categoria;

-- ------------------------------------------------------------
-- Consulta 2: clientes que nunca hicieron un pedido.
-- Spec: "el id, nombre y correo de los clientes registrados que
-- nunca hayan realizado un pedido en la plataforma."
-- ------------------------------------------------------------

-- Versión IA (NOT IN)
SELECT id_cliente, nombre, correo
FROM Cliente
WHERE id_cliente NOT IN (
    SELECT id_cliente
    FROM Pedido
    WHERE id_cliente IS NOT NULL
);

-- Versión propia alternativa (NOT EXISTS — segura ante NULL)
SELECT c.id_cliente, c.nombre, c.correo
FROM Cliente c
WHERE NOT EXISTS (
    SELECT 1
    FROM Pedido p
    WHERE p.id_cliente = c.id_cliente
);

-- Verificación de equivalencia, ambos sentidos
(SELECT id_cliente, nombre, correo FROM Cliente
 WHERE id_cliente NOT IN (SELECT id_cliente FROM Pedido WHERE id_cliente IS NOT NULL))
EXCEPT
(SELECT c.id_cliente, c.nombre, c.correo FROM Cliente c
 WHERE NOT EXISTS (SELECT 1 FROM Pedido p WHERE p.id_cliente = c.id_cliente));

(SELECT c.id_cliente, c.nombre, c.correo FROM Cliente c
 WHERE NOT EXISTS (SELECT 1 FROM Pedido p WHERE p.id_cliente = c.id_cliente))
EXCEPT
(SELECT id_cliente, nombre, correo FROM Cliente
 WHERE id_cliente NOT IN (SELECT id_cliente FROM Pedido WHERE id_cliente IS NOT NULL));
