-- ============================================================
-- indices.sql
-- Plan de indexado aceptado para Food Store (Parte A)
-- Cátedra: Base de Datos II — Unidad 3, Semana 5
-- ============================================================
-- No modifica el modelo de datos heredado (schema.sql).
-- Cada índice está justificado en informe_mediciones.md y en
-- su spec correspondiente dentro de specs/.
-- ============================================================

-- 1. Acelera consultas de catálogo por categoría y precio sobre
--    productos vigentes (Consulta 1). Índice parcial: excluye del
--    árbol los productos dados de baja (activo = FALSE).
CREATE INDEX idx_producto_cat_precio_activo
ON Producto (id_categoria, precio_actual)
WHERE activo = TRUE;
