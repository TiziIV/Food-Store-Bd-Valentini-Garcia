-- ============================================================
-- soft_delete.sql — Ampliación para el punto 9 del parcial final
-- "Borrado lógico (soft delete) y su impacto correcto sobre
-- consultas e índices."
-- ============================================================
-- Hasta esta entrega, el borrado lógico solo existía en
-- Producto.activo (TP1). Se extiende el mismo criterio a Cliente,
-- Pedido y Detalle_Pedido, bajo el nombre "eliminado" (para no
-- confundirlo con el "activo" de catálogo, que tiene otra semántica:
-- un producto inactivo puede volver a activarse; un registro
-- eliminado lógicamente representa una baja).
--
-- No se modifican TP1_FoodStore/schema.sql ni los archivos ya
-- entregados de TP2 a TP5: esta es una ampliación posterior sobre
-- el mismo esquema, pensada para aplicarse después de
-- TP1_FoodStore/schema.sql y de la carga de TP5_Indices_Vistas/data.sql.
-- ============================================================

-- ---------- Cliente ----------
-- Cliente no tenía ninguna columna de auditoría; se agrega también
-- created_at para poder ordenar/filtrar altas, igual que en el
-- esquema de referencia de la cátedra.
ALTER TABLE Cliente
    ADD COLUMN eliminado  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ---------- Pedido ----------
-- Pedido ya tiene fecha_hora (cumple el rol de "created_at"), por
-- lo que solo se agrega la marca de baja lógica. Un pedido dado de
-- baja representa, por ejemplo, una venta anulada que no debe
-- desaparecer del historial ni de la facturación ya emitida.
ALTER TABLE Pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------- Detalle_Pedido ----------
-- Permite anular una línea puntual de un pedido (por ejemplo, un
-- producto que se retira de la venta) sin afectar el resto del
-- pedido ni violar el trigger de inmutabilidad de precio/cantidad
-- de TP2 (que sigue bloqueando el cambio de cantidad/precio_unitario,
-- no el de esta nueva columna).
ALTER TABLE Detalle_Pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- Índices que reflejan el impacto del filtro de vigencia sobre las
-- consultas de reporte más frecuentes (equivalente al índice
-- parcial idx_producto_cat_precio_activo de TP5, pero para las
-- tablas ampliadas acá).
-- ============================================================

-- Acelera el historial de pedidos vigentes de un cliente (mismo
-- patrón que idx_pedido_cliente_fecha_desc de TP5, agregando el
-- filtro de vigencia).
CREATE INDEX idx_pedido_vigente_cliente_fecha
ON Pedido (id_cliente, fecha_hora DESC)
WHERE eliminado = FALSE;

-- Acelera el cálculo de totales/reportes sobre líneas de pedido
-- vigentes (excluye ítems anulados sin tener que filtrarlos en
-- memoria en cada consulta).
CREATE INDEX idx_detalle_pedido_vigente
ON Detalle_Pedido (id_pedido)
WHERE eliminado = FALSE;

-- ============================================================
-- Impacto sobre consultas existentes: ejemplo antes/después
-- ============================================================
-- Antes de esta ampliación (TP3, queries.sql — clientes que nunca
-- hicieron un pedido) la consulta no podía distinguir un cliente
-- dado de baja de uno activo sin pedidos. La versión correcta,
-- después de agregar el borrado lógico, filtra ambas tablas:

-- Antes (TP3_Optimizacion_Indices/queries.sql, no distingue bajas lógicas):
-- SELECT c.id_cliente, c.nombre, c.correo
-- FROM Cliente c
-- WHERE NOT EXISTS (
--     SELECT 1 FROM Pedido p WHERE p.id_cliente = c.id_cliente
-- );

-- Después (respeta el borrado lógico de Cliente y de Pedido):
SELECT c.id_cliente, c.nombre, c.correo
FROM Cliente c
WHERE c.eliminado = FALSE
  AND NOT EXISTS (
      SELECT 1
      FROM Pedido p
      WHERE p.id_cliente = c.id_cliente
        AND p.eliminado = FALSE
  );

-- Ejemplo de reporte que ahora debe excluir líneas de detalle
-- anuladas para no sobrefacturar (usa idx_detalle_pedido_vigente):
SELECT
    p.id_pedido,
    SUM(dp.cantidad * dp.precio_unitario) AS total_vigente
FROM Pedido p
JOIN Detalle_Pedido dp ON dp.id_pedido = p.id_pedido AND dp.eliminado = FALSE
WHERE p.eliminado = FALSE
GROUP BY p.id_pedido;

-- Verificación con EXPLAIN de que el filtro usa el índice parcial
-- (correr después de tener volumen cargado, ver TP5_Indices_Vistas/data.sql):
-- EXPLAIN ANALYZE
-- SELECT id_pedido, fecha_hora FROM Pedido
-- WHERE id_cliente = 1500 AND eliminado = FALSE
-- ORDER BY fecha_hora DESC;
