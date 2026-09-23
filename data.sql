-- ============================================================
-- data.sql — Datos de prueba para Food Store
-- Heredado del proyecto integrador (carga inicial de desarrollo).
-- Ampliado más adelante con volumen masivo para medir índices.
-- ============================================================

BEGIN;

-- Categorías base del catálogo
INSERT INTO Categoria (nombre_categoria, descripcion) VALUES
    ('Pizzas', 'Pizzas de todos los gustos'),
    ('Bebidas', 'Gaseosas, aguas y jugos'),
    ('Postres', 'Postres y helados'),
    ('Panificados', 'Pan, facturas y productos de panadería');

-- Clientes de prueba
INSERT INTO Cliente (nombre, correo, telefono) VALUES
    ('Ana Gómez', 'ana.gomez@example.com', '+5491100000001'),
    ('Luis Paz', 'luis.paz@example.com', '+5491100000002'),
    ('Marta Ruiz', 'marta.ruiz@example.com', NULL);

-- Productos de prueba, distribuidos en las categorías anteriores
INSERT INTO Producto (nombre_producto, precio_actual, stock, activo, id_categoria) VALUES
    ('Muzzarella', 1050.00, 40, TRUE, 1),
    ('Napolitana', 1500.00, 25, TRUE, 1),
    ('Coca 1.5L', 800.00, 100, TRUE, 2),
    ('Agua Mineral 500ml', 400.00, 150, TRUE, 2),
    ('Flan Casero', 650.00, 20, TRUE, 3);

-- Pedidos y sus detalles
INSERT INTO Pedido (fecha_hora, forma_pago, id_cliente) VALUES
    (now() - interval '10 days', 'EFECTIVO', 1),
    (now() - interval '5 days', 'TARJETA', 2),
    (now() - interval '1 days', 'TRANSFERENCIA', 3);

INSERT INTO Detalle_Pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
    (1, 1, 2, 1050.00),
    (1, 3, 1, 800.00),
    (2, 2, 1, 1500.00),
    (3, 3, 4, 800.00),
    (3, 2, 2, 1500.00);

ANALYZE Cliente;
ANALYZE Categoria;
ANALYZE Producto;
ANALYZE Pedido;
ANALYZE Detalle_Pedido;

COMMIT;
