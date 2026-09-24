-- ============================================================
-- procedimientos.sql — TP5
-- Procedimientos almacenados en PL/pgSQL, invocados con CALL
-- (PostgreSQL 16+).
-- ============================================================
-- Requiere haber aplicado antes soft_delete.sql.
-- ============================================================

-- Función invocable en PL/pgSQL (no es un trigger): total vigente
-- de un pedido. Si el pedido no existe, lanza excepción. Si está
-- anulado, devuelve 0: no debe seguir facturando.
CREATE OR REPLACE FUNCTION fn_total_pedido(p_id_pedido BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_eliminado BOOLEAN;
    v_total NUMERIC;
BEGIN
    SELECT pe.eliminado INTO v_eliminado
    FROM Pedido pe
    WHERE pe.id_pedido = p_id_pedido;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % no existe', p_id_pedido;
    END IF;

    IF v_eliminado THEN
        RETURN 0;
    END IF;

    SELECT COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)
    INTO v_total
    FROM Detalle_Pedido dp
    WHERE dp.id_pedido = p_id_pedido
      AND dp.eliminado = FALSE;

    RETURN v_total;
END;
$$;

-- ------------------------------------------------------------
-- Procedimiento 1: registrar un pedido completo con sus líneas de
-- forma atómica, a partir de un arreglo JSONB de ítems.
-- Reutiliza el trigger fn_validar_stock_pedido (TP2), que valida
-- stock disponible y lo descuenta en cada INSERT de Detalle_Pedido;
-- si algún ítem no tiene stock suficiente, la excepción del trigger
-- aborta todo el procedimiento (atomicidad: no queda un pedido a
-- medio cargar).
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    p_id_cliente BIGINT,
    p_forma_pago forma_pago_enum,
    p_items JSONB,               -- '[{"id_producto":1,"cantidad":2}, ...]'
    INOUT p_id_pedido BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item JSONB;
BEGIN
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Un pedido debe tener al menos un item';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Cliente
        WHERE id_cliente = p_id_cliente
          AND eliminado = FALSE
    ) THEN
        RAISE EXCEPTION 'Cliente % no existe o está dado de baja', p_id_cliente;
    END IF;

    INSERT INTO Pedido (forma_pago, id_cliente)
    VALUES (p_forma_pago, p_id_cliente)
    RETURNING id_pedido INTO p_id_pedido;

    -- Orden fijo por id_producto: con FOR UPDATE en el trigger de
    -- stock, dos pedidos con los mismos productos en distinto orden
    -- se interbloquearían (40P01). El informe de concurrencia pide
    -- este mismo criterio.
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items) AS t(value)
        ORDER BY (value->>'id_producto')::BIGINT
    LOOP
        INSERT INTO Detalle_Pedido (id_pedido, id_producto, cantidad, precio_unitario)
        SELECT
            p_id_pedido,
            (v_item->>'id_producto')::BIGINT,
            (v_item->>'cantidad')::INTEGER,
            pr.precio_actual
        FROM Producto pr
        WHERE pr.id_producto = (v_item->>'id_producto')::BIGINT
          AND pr.activo = TRUE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % no existe o no está vigente', (v_item->>'id_producto');
        END IF;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------
-- Procedimiento 2: anular un pedido. Marca las líneas como
-- eliminadas (el trigger devuelve el stock) y después el pedido.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_anular_pedido(p_id_pedido BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Detalle_Pedido
    SET eliminado = TRUE
    WHERE id_pedido = p_id_pedido
      AND eliminado = FALSE;

    UPDATE Pedido
    SET eliminado = TRUE
    WHERE id_pedido = p_id_pedido
      AND eliminado = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % no existe o ya estaba anulado', p_id_pedido;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Procedimiento 3: dar de baja lógica a un cliente (punto 6 + 9
-- combinados: el procedimiento es el único camino soportado para
-- aplicar el borrado lógico, en vez de dejar que cada consulta
-- escriba su propio UPDATE).
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_dar_baja_cliente(p_id_cliente BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Cliente
    SET eliminado = TRUE
    WHERE id_cliente = p_id_cliente
      AND eliminado = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente % no existe o ya estaba dado de baja', p_id_cliente;
    END IF;
END;
$$;

-- ============================================================
-- Ejemplos de uso (invocación con CALL, como exige la consigna)
-- Probar siempre dentro de una transacción de prueba, según
-- protocolo_seguridad.md:
-- ============================================================

-- BEGIN;
--
-- -- Atomicidad: un ítem sin stock no deja pedido a medias
-- SELECT stock FROM Producto WHERE id_producto = 1;
-- CALL sp_registrar_pedido(
--     1500,
--     'EFECTIVO',
--     '[{"id_producto": 1, "cantidad": 2}, {"id_producto": 1, "cantidad": 999999}]'::jsonb
-- );
-- -- ERROR Stock insuficiente; count de pedidos recientes del cliente = 0;
-- -- stock de producto 1 intacto.
--
-- CALL sp_registrar_pedido(
--     1500,
--     'EFECTIVO',
--     '[{"id_producto": 3, "cantidad": 1}, {"id_producto": 1, "cantidad": 2}]'::jsonb
-- );
-- -- Ítems se insertan ordenados por id_producto (1 antes que 3).
-- -- El resultado de la llamada devuelve el id_pedido en p_id_pedido.
--
-- SELECT fn_total_pedido(<id_pedido>);
-- CALL sp_anular_pedido(<id_pedido>);
-- SELECT fn_total_pedido(<id_pedido>);  -- 0
-- SELECT stock FROM Producto WHERE id_producto = 1;  -- repuesto (stock_descontado)
--
-- CALL sp_dar_baja_cliente(1500);
--
-- ROLLBACK;
