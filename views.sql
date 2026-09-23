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

-- 2. Pedidos con los datos del cliente que los realizó.
--    Criterio de seguridad: NO expone la columna telefono de
--    Cliente (Food Store no modela autenticación ni contraseñas;
--    el teléfono es el dato de contacto sensible a proteger), por
--    lo que puede otorgarse SELECT sobre esta vista sin dar
--    acceso a la tabla base.
--    Ejemplo de uso:
--    GRANT SELECT ON vista_pedidos_cliente TO rol_reportes;
CREATE OR REPLACE VIEW vista_pedidos_cliente AS
SELECT
    pe.id_pedido,
    pe.fecha_hora,
    pe.forma_pago,
    c.id_cliente,
    c.nombre AS nombre_cliente,
    c.correo
FROM Pedido pe
JOIN Cliente c ON pe.id_cliente = c.id_cliente;
