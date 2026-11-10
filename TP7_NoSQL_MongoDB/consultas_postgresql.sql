-- ============================================================================
-- TRABAJO PRÁCTICO · UNIDAD 7: NoSQL Y NUEVAS FORMAS DE ALMACENAMIENTO
-- Caso: Food Store - Consultas Relacionales y Validación Cruzada con MongoDB
-- Integrantes: Tiziano Valentini y Juan Martin Garcia
-- Repositorio: Trabajos-Practicos-BD-Valentini-Garcia
-- Archivo: TP8_NoSQL_MongoDB/consultas_postgresql.sql
-- ============================================================================
--
-- Este script contiene:
--  1. Actualización idempotente del atributo 'estado' sobre Pedido (Consigna 5).
--  2. Consulta de extracción/migración a formato JSONB estructurado.
--  3. Consulta equivalente a Consigna 4 (b): filtro por estado ('ENTREGADO').
--  4. Consulta equivalente a Consigna 4 (c): pedidos que contienen id_producto = 3.
--  5. Consulta complementaria a Consigna 4 (d): pedidos con total > $15.000,00.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Adecuación de esquema relacional para soportar el ciclo de vida del pedido
-- ----------------------------------------------------------------------------
-- En el esquema base de TP1/TP5, Pedido disponía de 'forma_pago' y 'eliminado'.
-- Tal como autoriza la Consigna 5 ("corregir el modelo o la consulta cuando
-- corresponda"), se agrega la columna 'estado' con valores estándar del dominio.

ALTER TABLE Pedido 
    ADD COLUMN IF NOT EXISTS estado VARCHAR(20) DEFAULT 'ENTREGADO';

UPDATE Pedido SET estado = 'ENTREGADO' WHERE id_pedido IN (1, 2, 4, 5);
UPDATE Pedido SET estado = 'EN_PREPARACION' WHERE id_pedido = 3;
UPDATE Pedido SET estado = 'PENDIENTE' WHERE id_pedido = 6;

-- ----------------------------------------------------------------------------
-- 2. Consulta de extracción / migración de datos hacia MongoDB
-- ----------------------------------------------------------------------------
-- Construye documentos JSONB equivalentes al esquema de la colección 'pedidos',
-- agrupando los detalles como un arreglo de objetos embebidos y calculando
-- subtotales y el importe total consolidado.

SELECT jsonb_pretty(jsonb_agg(to_jsonb(pedido_data))) AS exportacion_mongodb
FROM (
  SELECT 
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    p.estado,
    p.eliminado,
    jsonb_build_object(
      'id_cliente', c.id_cliente,
      'nombre', c.nombre,
      'email', c.correo
    ) AS cliente,
    jsonb_agg(
      jsonb_build_object(
        'id_producto', pr.id_producto,
        'nombre_producto', pr.nombre_producto,
        'categoria', cat.nombre_categoria,
        'cantidad', dp.cantidad,
        'precio_unitario', dp.precio_unitario,
        'subtotal', round((dp.cantidad * dp.precio_unitario)::numeric, 2)
      ) ORDER BY dp.id_producto
    ) AS lineas,
    round(SUM(dp.cantidad * dp.precio_unitario)::numeric, 2) AS total_pedido
  FROM Pedido p
  JOIN Cliente c ON p.id_cliente = c.id_cliente
  JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
  JOIN Producto pr ON dp.id_producto = pr.id_producto
  JOIN Categoria cat ON pr.id_categoria = cat.id_categoria
  WHERE p.id_pedido BETWEEN 1 AND 6
  GROUP BY p.id_pedido, p.fecha_hora, p.forma_pago, p.estado, p.eliminado, c.id_cliente, c.nombre, c.correo
  ORDER BY p.id_pedido
) AS pedido_data;

-- ----------------------------------------------------------------------------
-- 3. Consigna 5 - Consulta equivalente a 4 (b): Filtro por estado 'ENTREGADO'
-- ----------------------------------------------------------------------------
-- Recupera los pedidos migrados que se encuentran en estado 'ENTREGADO',
-- proyectando el identificador, fecha, forma de pago, estado, cliente y total.
--
-- Coincidencia esperada con MongoDB: 4 filas (IDs: 1, 2, 4, 5).

SELECT 
    p.id_pedido,
    p.fecha_hora,
    p.forma_pago,
    p.estado,
    c.nombre AS cliente,
    round(SUM(dp.cantidad * dp.precio_unitario)::numeric, 2) AS total_pedido
FROM Pedido p
JOIN Cliente c ON p.id_cliente = c.id_cliente
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.estado = 'ENTREGADO'
  AND p.id_pedido BETWEEN 1 AND 6
GROUP BY p.id_pedido, p.fecha_hora, p.forma_pago, p.estado, c.nombre
ORDER BY p.id_pedido;

-- Conteo de verificación para la tabla cruzada:
SELECT count(*) AS cantidad_entregados_pg
FROM Pedido p
WHERE p.estado = 'ENTREGADO'
  AND p.id_pedido BETWEEN 1 AND 6;

-- ----------------------------------------------------------------------------
-- 4. Consigna 5 - Consulta equivalente a 4 (c): Búsqueda por producto embebido
-- ----------------------------------------------------------------------------
-- Recupera los pedidos migrados que contienen el producto con id_producto = 3
-- ('Coca 1.5L'), haciendo uso de la relación relacional Pedido -> Detalle_Pedido.
--
-- Coincidencia esperada con MongoDB: 2 filas (IDs: 1, 3).

SELECT DISTINCT
    p.id_pedido,
    p.fecha_hora,
    p.estado,
    c.nombre AS cliente,
    dp.id_producto,
    pr.nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    round((dp.cantidad * dp.precio_unitario)::numeric, 2) AS subtotal
FROM Pedido p
JOIN Cliente c ON p.id_cliente = c.id_cliente
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
JOIN Producto pr ON dp.id_producto = pr.id_producto
WHERE dp.id_producto = 3
  AND p.id_pedido BETWEEN 1 AND 6
ORDER BY p.id_pedido;

-- Conteo de verificación para la tabla cruzada:
SELECT count(DISTINCT p.id_pedido) AS cantidad_pedidos_con_producto_3_pg
FROM Pedido p
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
WHERE dp.id_producto = 3
  AND p.id_pedido BETWEEN 1 AND 6;

-- ----------------------------------------------------------------------------
-- 5. Consulta complementaria equivalente a 4 (d): Total > $15.000,00
-- ----------------------------------------------------------------------------
-- Recupera pedidos de alto valor en PostgreSQL mediante agregación HAVING.
--
-- Coincidencia esperada con MongoDB: 4 filas (IDs: 5, 6, 1, 2).

SELECT 
    p.id_pedido,
    p.estado,
    c.nombre AS cliente,
    round(SUM(dp.cantidad * dp.precio_unitario)::numeric, 2) AS total_pedido
FROM Pedido p
JOIN Cliente c ON p.id_cliente = c.id_cliente
JOIN Detalle_Pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.id_pedido BETWEEN 1 AND 6
GROUP BY p.id_pedido, p.estado, c.nombre
HAVING SUM(dp.cantidad * dp.precio_unitario) > 15000.00
ORDER BY total_pedido DESC;
