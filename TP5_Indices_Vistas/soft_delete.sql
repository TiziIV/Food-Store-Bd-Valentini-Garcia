-- ============================================================
-- soft_delete.sql — TP5
-- Borrado lógico (soft delete) y su impacto sobre consultas
-- e índices.
-- ============================================================
-- Hasta esta entrega, el borrado lógico solo existía en
-- Producto.activo (TP1). Se extiende el mismo criterio a Cliente,
-- Pedido y Detalle_Pedido, bajo el nombre "eliminado" (para no
-- confundirlo con el "activo" de catálogo, que tiene otra semántica:
-- un producto inactivo puede volver a activarse; un registro
-- eliminado lógicamente representa una baja).
-- Polaridad: activo = TRUE significa "se puede vender";
-- eliminado = TRUE significa "dado de baja". No son el mismo flag
-- invertido. Un reporte de vigencia usa activo = TRUE en Producto
-- y eliminado = FALSE en Cliente, Pedido y Detalle_Pedido.
--
-- No se modifica ../TP1_FoodStore/schema.sql: esta es una ampliación
-- posterior sobre el mismo esquema, pensada para aplicarse después
-- de TP1_FoodStore/schema.sql y de la carga de data.sql de esta
-- misma carpeta (ver README.md para el orden completo).
-- ============================================================

-- ---------- Cliente ----------
-- Cliente no tenía ninguna columna de auditoría; se agrega también
-- created_at para poder ordenar/filtrar altas, igual que en el
-- esquema de referencia de la cátedra.
ALTER TABLE Cliente
    ADD COLUMN eliminado  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- El UNIQUE de schema.sql impide reutilizar el correo de un cliente
-- dado de baja. Se reemplaza por un único parcial: el correo identifica
-- a un cliente vigente, no a uno anulado.
ALTER TABLE Cliente DROP CONSTRAINT uq_cliente_correo;

CREATE UNIQUE INDEX uq_cliente_correo_vigente
ON Cliente (correo)
WHERE eliminado = FALSE;

-- ---------- Pedido ----------
-- Pedido ya tiene fecha_hora (cumple el rol de "created_at"), por
-- lo que solo se agrega la marca de baja lógica. Un pedido dado de
-- baja representa una venta anulada: queda en la tabla para el
-- historial, y las vistas, la materializada y las consultas de
-- facturación la excluyen con eliminado = FALSE.
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

-- Al anular una línea se devuelve el stock que el trigger de TP2
-- había descontado en el INSERT. No toca cantidad ni precio_unitario,
-- así que no choca con trg_bloquear_modificacion_detalle_pedido.
CREATE OR REPLACE FUNCTION fn_devolver_stock_al_anular()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.eliminado = FALSE AND NEW.eliminado = TRUE THEN
        UPDATE Producto
        SET stock = stock + OLD.cantidad
        WHERE id_producto = OLD.id_producto;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_devolver_stock_al_anular ON Detalle_Pedido;

CREATE TRIGGER trg_devolver_stock_al_anular
    BEFORE UPDATE ON Detalle_Pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_devolver_stock_al_anular();

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
