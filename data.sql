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

-- ============================================================
-- Carga masiva — volumen para medir índices (Unidad 2, Semanas 3-4)
-- Genera 20.000 clientes, 50.000 productos, 200.000 pedidos y sus
-- detalles, para que las diferencias de plan y tiempo sean
-- observables con EXPLAIN ANALYZE.
-- ============================================================

BEGIN;

-- Categorías adicionales del catálogo ampliado
INSERT INTO Categoria (nombre_categoria, descripcion)
VALUES
    ('Lácteos', 'Leche, yogures, quesos, manteca y derivados'),
    ('Snacks', 'Papas fritas, maníes, palitos salados y copetín'),
    ('Almacén', 'Fideos, arroz, aceites, harinas, yerba, azúcar y conservas'),
    ('Carnicería y Granja', 'Cortes vacunos, pollo, cerdo y fiambres'),
    ('Frutas y Verduras', 'Productos frescos de estación y hortalizas'),
    ('Congelados', 'Pizzas, empanadas, hamburguesas y verduras congeladas'),
    ('Limpieza', 'Lavandina, detergentes, desinfectantes y accesorios'),
    ('Perfumería y Cuidado Personal', 'Jabones, champús, dentífricos y papel higiénico');

-- Carga masiva de 20.000 clientes adicionales
INSERT INTO Cliente (nombre, correo, telefono)
SELECT
    'Cliente ' || i,
    'usuario_' || i || '@foodstore.com',
    CASE
        WHEN random() < 0.85 THEN '+54911' || lpad(floor(random() * 90000000 + 10000000)::text, 8, '0')
        ELSE NULL
    END
FROM generate_series(1, 20000) AS i;

-- Carga masiva de 50.000 productos adicionales
INSERT INTO Producto (nombre_producto, precio_actual, stock, activo, id_categoria)
SELECT
    'Producto FoodStore ' || i,
    round((random() * 4500 + 500)::numeric, 2),
    floor(random() * 201)::integer,
    CASE WHEN random() < 0.96 THEN TRUE ELSE FALSE END,
    1 + floor(random() * 12)::bigint
FROM generate_series(1, 50000) AS i;

-- Carga masiva de 200.000 pedidos
INSERT INTO Pedido (fecha_hora, forma_pago, id_cliente)
SELECT
    now() - (random() * interval '730 days'),
    (ARRAY['EFECTIVO'::forma_pago_enum, 'TARJETA'::forma_pago_enum,
           'TRANSFERENCIA'::forma_pago_enum, 'BILLETERA_DIGITAL'::forma_pago_enum])
        [floor(random() * 4 + 1)::integer],
    floor(random() * 20003 + 1)::bigint
FROM generate_series(1, 200000) AS i;

-- Carga masiva de Detalle_Pedido (dos ítems distintos por pedido)
INSERT INTO Detalle_Pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    p.id_pedido,
    pr.id_producto,
    floor(random() * 4 + 1)::integer AS cantidad,
    pr.precio_actual
FROM Pedido p
CROSS JOIN LATERAL (
    SELECT id_producto, precio_actual
    FROM Producto
    WHERE id_producto IN (
        6 + (((p.id_pedido - 1) * 2) % 50000),
        6 + (((p.id_pedido - 1) * 2 + 1) % 50000)
    )
) pr;

ANALYZE Cliente;
ANALYZE Categoria;
ANALYZE Producto;
ANALYZE Pedido;
ANALYZE Detalle_Pedido;

COMMIT;
