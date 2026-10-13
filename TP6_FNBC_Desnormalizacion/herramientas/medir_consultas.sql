\set ON_ERROR_STOP on
SET TIME ZONE 'America/Argentina/Buenos_Aires';
SET search_path=public;
-- Ejecutar ambas en el mismo estado, alternando el orden en 7 pares.
-- Execution Time no incluye el tiempo de inicio de psql.
\echo ANTES
EXPLAIN (ANALYZE,BUFFERS)
SELECT c.nombre_categoria AS categoria,SUM(dp.cantidad*dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp JOIN producto pr USING(id_producto) JOIN categoria c USING(id_categoria)
JOIN pedido ped USING(id_pedido)
WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
AND NOT dp.eliminado AND NOT ped.eliminado
GROUP BY c.nombre_categoria ORDER BY total_vendido DESC LIMIT 5;
\echo DESPUES
EXPLAIN (ANALYZE,BUFFERS)
SELECT dp.categoria_nombre AS categoria,SUM(dp.cantidad*dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp JOIN pedido ped USING(id_pedido)
WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
AND NOT dp.eliminado AND NOT ped.eliminado
GROUP BY dp.categoria_nombre ORDER BY total_vendido DESC LIMIT 5;
