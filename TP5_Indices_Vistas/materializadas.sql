-- ============================================================
-- materializadas.sql
-- Vista materializada de facturación para Food Store (Parte C)
-- Cátedra: Base de Datos II — Unidad 3, Semana 5
-- ============================================================
-- Aplicar después de soft_delete.sql. Excluye pedidos y líneas
-- anuladas: si no, una baja lógica seguiría sumando en el reporte.
-- No filtra Cliente.eliminado: una venta vigente de un cliente
-- después dado de baja sigue contando en facturación (distinto de
-- vista_pedidos_cliente, que oculta esos pedidos a propósito).
-- Medición: ver informe_mediciones.md (810,45 ms → 1,15 ms).
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;

-- Reporte agregado: facturación por categoría y por mes.
-- Se crea WITH DATA y con un índice único sobre (categoría, mes)
-- que habilita, a futuro, REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.id_categoria,
    c.nombre_categoria,
    date_trunc('month', pe.fecha_hora)::date AS mes,
    SUM(dp.cantidad * dp.precio_unitario) AS total_facturado,
    COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos
FROM Detalle_Pedido dp
JOIN Producto  p  ON dp.id_producto = p.id_producto
JOIN Categoria c  ON p.id_categoria = c.id_categoria
JOIN Pedido    pe ON dp.id_pedido = pe.id_pedido
WHERE dp.eliminado = FALSE
  AND pe.eliminado = FALSE
GROUP BY c.id_categoria, c.nombre_categoria, date_trunc('month', pe.fecha_hora)
WITH DATA;

CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes
ON mv_facturacion_categoria_mes (id_categoria, mes);

-- ============================================================
-- Refresco recomendado: una vez por día, fuera de horario pico
-- (por ejemplo 03:00 AM, luego de los procesos batch nocturnos).
-- Requiere el índice único creado arriba.
--
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
-- ============================================================
