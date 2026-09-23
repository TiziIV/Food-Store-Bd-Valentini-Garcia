-- ============================================================
-- views.sql
-- Vistas de reporte para Food Store (Parte B)
-- Cátedra: Base de Datos II — Unidad 3, Semana 5
-- ============================================================
-- No modifica el modelo de datos heredado (schema.sql).
-- Verificación de equivalencia de cada vista contra su consulta
-- manual: ver informe_mediciones.md.
-- ============================================================

-- 1. Productos vigentes con su categoría.
--    Oculta los productos dados de baja (activo = FALSE).
CREATE OR REPLACE VIEW vista_productos_vigentes AS
SELECT
    p.id_producto,
    p.nombre_producto,
    p.precio_actual,
    c.id_categoria,
    c.nombre_categoria
FROM Producto p
JOIN Categoria c ON p.id_categoria = c.id_categoria
WHERE p.activo = TRUE;
