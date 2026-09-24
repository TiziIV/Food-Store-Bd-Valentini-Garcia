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

-- 2. Optimiza la consulta cronológica de pedidos por cliente
--    (Consulta 2), evitando el nodo de ordenamiento (Sort) en
--    memoria al indexar fecha_hora en orden descendente.
CREATE INDEX idx_pedido_cliente_fecha_desc
ON Pedido (id_cliente, fecha_hora DESC);

-- 3. Cubre consultas de detalles por producto (Consulta 3) sin
--    acceder al heap de la tabla (Index Only Scan), incluyendo
--    cantidad y precio_unitario como columnas no indexadas.
CREATE INDEX idx_detalle_pedido_prod_covering
ON Detalle_Pedido (id_producto)
INCLUDE (cantidad, precio_unitario);

-- Los índices simples de schema.sql quedan cubiertos por los
-- compuestos de arriba (el prefijo id_cliente, y el covering sobre
-- id_producto). Dejarlos sumaría costo de escritura sin un plan distinto.
DROP INDEX IF EXISTS idx_pedido_id_cliente;
DROP INDEX IF EXISTS idx_detalle_pedido_id_producto;

-- ============================================================
-- Índice descartado por sobreindexación (NO se crea; se deja
-- documentado el motivo del descarte, ver specs/spec_idx_pedido_
-- forma_pago_DESCARTADO.md):
--
-- CREATE INDEX idx_pedido_forma_pago ON Pedido (forma_pago);
--
-- Motivo: baja cardinalidad (4 valores enum, ~25% cada uno).
-- El planificador de PostgreSQL descarta el índice y usa Seq Scan,
-- por lo que el índice solo agregaría costo de escritura y de
-- memoria (buffer pool) sin beneficio real. Ver informe_mediciones.md.
-- ============================================================
