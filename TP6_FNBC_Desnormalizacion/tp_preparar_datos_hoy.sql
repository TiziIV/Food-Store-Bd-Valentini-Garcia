-- ============================================================================
-- TP U4 - PARTE 2 (paso previo, SOLO sobre la copia de trabajo)
-- Concentra pedidos en el día de hoy para que el reporte "top 5 categorías
-- del día" tenga volumen medible.
-- ============================================================================
-- Motivo: data.sql reparte los 200.000 pedidos de forma uniforme en 730 días
-- (~270 por día), un volumen demasiado chico para observar diferencias de
-- plan. Se reasigna a "hoy" un pedido de cada 20 (~10.000 pedidos y ~20.000
-- detalles). Es una modificación de datos de prueba: NO ejecutar sobre una
-- base de producción (ver protocolo_seguridad.md: copia + respaldo).
--
-- Efecto lateral conocido: mv_facturacion_categoria_mes (TP5) queda
-- desactualizada; si hace falta, REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes;
--
-- Uso:  psql -d food_store -f tp_preparar_datos_hoy.sql
-- ============================================================================

BEGIN;

UPDATE Pedido
SET fecha_hora = date_trunc('day', now())
               + random() * (now() - date_trunc('day', now()))
WHERE id_pedido % 20 = 0;

ANALYZE Pedido;

COMMIT;

-- Control: cuántos pedidos/detalles vigentes hay hoy.
SELECT count(DISTINCT pe.id_pedido) AS pedidos_hoy,
       count(*)                     AS detalles_hoy
FROM Pedido pe
JOIN Detalle_Pedido dp ON dp.id_pedido = pe.id_pedido
WHERE pe.fecha_hora >= CURRENT_DATE
  AND pe.fecha_hora <  CURRENT_DATE + 1
  AND pe.eliminado = FALSE
  AND dp.eliminado = FALSE;
