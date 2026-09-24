-- =============================================================================
-- restricciones.sql — Parte 1: Restricciones de integridad y disparadores
-- Proyecto: Food Store — TP2 (Unidad 1, Semana 2)
-- Se aplica sobre el esquema real del proyecto (TP1_FoodStore/schema.sql):
-- Cliente, Categoria, Producto, Pedido, Detalle_Pedido.
-- =============================================================================
--
-- Nota de adaptacion: la primera propuesta generada con OpenCode incluia
-- reglas sobre columnas (Pedido.estado, Pedido.fecha_pedido,
-- Pedido.fecha_entrega) que no existen en el esquema real de Food Store;
-- son columnas del esquema generico de ejemplo que usa la catedra
-- (Usuario/Pedido con estado y fechas de entrega). Esas dos reglas se
-- reemplazan aqui por reglas equivalentes sobre columnas que si existen
-- en el proyecto. El detalle de que se acepto, que se descarto y por que
-- queda documentado en duia.md.

-- -----------------------------------------------------------------------------
-- R1: El correo del cliente debe tener formato de email valido.
-- Refuerza la Regla R6 del TP1 (el correo identifica de forma unica al
-- cliente): una clave candidata con formato invalido no sirve como dato
-- de contacto real.
-- -----------------------------------------------------------------------------
ALTER TABLE Cliente
    ADD CONSTRAINT chk_cliente_correo_formato
        CHECK (correo ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- -----------------------------------------------------------------------------
-- R2: El precio de lista de un producto no puede ser cero.
-- schema.sql ya exige precio_actual >= 0 (Regla R5 del TP1); esta
-- restriccion lo refina para prohibir tambien el cero, porque un
-- producto publicado con precio 0 no es un caso de negocio valido.
-- -----------------------------------------------------------------------------
ALTER TABLE Producto
    ADD CONSTRAINT chk_producto_precio_estrictamente_positivo
        CHECK (precio_actual > 0);

-- -----------------------------------------------------------------------------
-- R3: El precio unitario congelado en Detalle_Pedido no puede ser cero.
-- Mismo criterio que R2, pero sobre el precio historico de la Regla R4
-- del TP1 (lo que se facturo no puede alterarse, pero tampoco puede
-- haber quedado guardado en cero).
-- -----------------------------------------------------------------------------
ALTER TABLE Detalle_Pedido
    ADD CONSTRAINT chk_detalle_precio_estrictamente_positivo
        CHECK (precio_unitario > 0);

-- -----------------------------------------------------------------------------
-- R4: Un detalle de pedido ya creado no puede modificar su cantidad ni
-- su precio_unitario.
-- Reemplaza a la regla original de coherencia de fechas (que no aplica
-- porque Pedido no tiene fecha_entrega). Implementa directamente la
-- Regla R4 del TP1: "lo que se facturo en marzo no puede cambiar porque
-- en abril subimos el precio". Se implementa como trigger porque un
-- CHECK no puede comparar el valor anterior de una fila.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_bloquear_modificacion_detalle_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cantidad <> OLD.cantidad OR NEW.precio_unitario <> OLD.precio_unitario THEN
        RAISE EXCEPTION
            'No se puede modificar cantidad ni precio_unitario de un detalle de pedido ya facturado (pedido %, producto %)',
            OLD.id_pedido, OLD.id_producto;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bloquear_modificacion_detalle_pedido ON Detalle_Pedido;

CREATE TRIGGER trg_bloquear_modificacion_detalle_pedido
    BEFORE UPDATE ON Detalle_Pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_bloquear_modificacion_detalle_pedido();

-- -----------------------------------------------------------------------------
-- R5: Garantia de stock suficiente al insertar un Detalle_Pedido.
-- Bloquea la fila de Producto con FOR UPDATE: si dos ventas del mismo
-- producto entran juntas, la segunda espera a que la primera confirme
-- o revierta, y recién ahí lee el stock ya descontado. Sin ese bloqueo
-- las dos leerían el mismo stock y la segunda fallaría recién en el
-- CHECK stock >= 0, con un mensaje que no dice "stock insuficiente".
--
-- Este trigger se aplica DESPUÉS de data.sql. Si está activo durante
-- la carga masiva, miles de detalles fallan porque el stock aleatorio
-- (0 a 200) no alcanza para todos los pedidos.
-- -----------------------------------------------------------------------------
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

    -- Descontar el stock de forma atomica en la misma operacion
    UPDATE Producto
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_stock_pedido ON Detalle_Pedido;

CREATE TRIGGER trg_validar_stock_pedido
    BEFORE INSERT ON Detalle_Pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_stock_pedido();
