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

-- Marca si el trigger de stock descontó unidades al insertar la
-- línea. La carga masiva (data.sql) corre ANTES de ese trigger, así
-- que esas filas quedan en FALSE: anularlas no debe reponer stock
-- que nunca se descontó. Solo los INSERT posteriores (p. ej.
-- sp_registrar_pedido) ponen TRUE.
ALTER TABLE Detalle_Pedido
    ADD COLUMN stock_descontado BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- Índices que reflejan el impacto del filtro de vigencia.
-- ============================================================

-- Acelera el historial de pedidos vigentes de un cliente.
CREATE INDEX idx_pedido_vigente_cliente_fecha
ON Pedido (id_cliente, fecha_hora DESC)
WHERE eliminado = FALSE;

-- No se crea idx_detalle_pedido_vigente(id_pedido) WHERE eliminado =
-- FALSE: la PK pk_detalle_pedido ya empieza por id_pedido, y el
-- parcial ahorra poco frente a filtrar eliminado = FALSE sobre ese
-- prefijo. Mismo criterio de sobreindexación que con forma_pago.

-- Redefine el trigger de stock (TP2) para marcar stock_descontado
-- cuando efectivamente descuenta. Debe correr después de este ALTER.
CREATE OR REPLACE FUNCTION fn_validar_stock_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_disponible INT;
BEGIN
    SELECT stock INTO v_stock_disponible
    FROM Producto
    WHERE id_producto = NEW.id_producto
    FOR UPDATE;

    IF v_stock_disponible IS NULL THEN
        RAISE EXCEPTION 'Producto % no existe', NEW.id_producto;
    END IF;

    IF v_stock_disponible < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto ID %: Disponible %, Solicitado %',
            NEW.id_producto, v_stock_disponible, NEW.cantidad;
    END IF;

    UPDATE Producto
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    NEW.stock_descontado := TRUE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Al anular una línea solo se devuelve stock si el INSERT lo había
-- descontado (stock_descontado = TRUE).
CREATE OR REPLACE FUNCTION fn_devolver_stock_al_anular()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.eliminado = FALSE
       AND NEW.eliminado = TRUE
       AND OLD.stock_descontado = TRUE THEN
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
-- anuladas para no sobrefacturar:
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
