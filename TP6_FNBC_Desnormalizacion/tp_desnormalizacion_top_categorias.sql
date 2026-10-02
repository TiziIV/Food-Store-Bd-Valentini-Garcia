-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 4 - PARTE 2
-- Desnormalización controlada en Food Store: top 5 categorías del día
-- Cátedra: Base de Datos II - UTN FRM
-- Integrantes: Tiziano Valentini, Juan Martin Garcia
-- ============================================================================
-- Patrón elegido: COLUMNA PRECALCULADA + DISPARADORES
--   Detalle_Pedido.categoria_nombre replica el nombre de la categoría de su
--   producto, para que el reporte no tenga que unir Producto ni Categoria.
--
-- PRERREQUISITOS (orden completo en el README del repositorio):
--   1. TP1/schema.sql + TP5/data.sql + TP2/restricciones.sql + TP5/indices.sql
--   2. TP5/soft_delete.sql   (columnas "eliminado" en Pedido y Detalle_Pedido)
--   3. tp_preparar_datos_hoy.sql (volumen de pedidos en el día actual)
--
-- ADAPTACIÓN de la consulta de la consigna al esquema real del proyecto:
--   consigna                      esquema real (TP1)
--   ped.fecha = CURRENT_DATE      Pedido.fecha_hora (TIMESTAMPTZ) en el rango
--                                 [CURRENT_DATE, CURRENT_DATE + 1)   (sargable;
--                                 equivale a fecha_hora::date = CURRENT_DATE)
--   dp.subtotal                   cantidad * precio_unitario (no existe columna
--                                 subtotal; solo la vista de TP5 lo calcula)
--   pr.id / c.id / ped.id         id_producto / id_categoria / id_pedido
--   c.nombre                      Categoria.nombre_categoria
--   dp.producto_id / pedido_id    Detalle_Pedido.id_producto / id_pedido
-- No se agregan columnas fecha ni subtotal: serían redundancia adicional no
-- pedida. La única redundancia introducida es categoria_nombre.
--
-- Uso:  psql -d food_store -f tp_desnormalizacion_top_categorias.sql > salida_parte2.txt
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off
\timing on

-- Verificación de prerrequisitos: falla con un mensaje claro si falta algo.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'pedido' AND column_name = 'eliminado')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'detalle_pedido' AND column_name = 'eliminado') THEN
        RAISE EXCEPTION 'Falta TP5_Indices_Vistas/soft_delete.sql (columna eliminado en Pedido/Detalle_Pedido)';
    END IF;
END $$;

-- ============================================================================
-- 5.2 (a) MEDICIÓN "ANTES": consulta normalizada (4 tablas)
-- Se ejecuta dos veces; la segunda (caché caliente) es la que se informa.
-- ============================================================================
\echo '=== ANTES (corrida 1: descartar) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre_categoria AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Producto  pr  ON pr.id_producto  = dp.id_producto
JOIN Categoria c   ON c.id_categoria  = pr.id_categoria
JOIN Pedido    ped ON ped.id_pedido   = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre_categoria
ORDER BY total_vendido DESC
LIMIT 5;

\echo '=== ANTES (corrida 2: informar) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre_categoria AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Producto  pr  ON pr.id_producto  = dp.id_producto
JOIN Categoria c   ON c.id_categoria  = pr.id_categoria
JOIN Pedido    ped ON ped.id_pedido   = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre_categoria
ORDER BY total_vendido DESC
LIMIT 5;

-- Resultado de referencia del reporte normalizado (para comparar con el "después").
\echo '=== RESULTADO NORMALIZADO ==='
SELECT c.nombre_categoria AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Producto  pr  ON pr.id_producto  = dp.id_producto
JOIN Categoria c   ON c.id_categoria  = pr.id_categoria
JOIN Pedido    ped ON ped.id_pedido   = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre_categoria
ORDER BY total_vendido DESC
LIMIT 5;

-- ============================================================================
-- 5.2 (c) IMPLEMENTACIÓN: estructura desnormalizada + sincronización
-- ============================================================================
BEGIN;

-- 1) Columna redundante. Primero se agrega nullable, se migra y recién
--    después se exige NOT NULL (la tabla tiene ~400.000 filas).
ALTER TABLE Detalle_Pedido ADD COLUMN IF NOT EXISTS categoria_nombre VARCHAR(80);

-- 2) Migración de los datos existentes (fuente de verdad: Categoria).
UPDATE Detalle_Pedido dp
SET categoria_nombre = c.nombre_categoria
FROM Producto pr
JOIN Categoria c ON c.id_categoria = pr.id_categoria
WHERE dp.id_producto = pr.id_producto
  AND dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria;

ALTER TABLE Detalle_Pedido ALTER COLUMN categoria_nombre SET NOT NULL;

-- 3) Mecanismo de sincronización (tres caminos por los que el dato fuente cambia).

-- 3.1 Alta de un detalle o cambio de su producto: la columna SIEMPRE se
--     recalcula desde la fuente; ningún valor enviado por el cliente se respeta.
CREATE OR REPLACE FUNCTION fn_dp_sync_categoria_nombre() RETURNS TRIGGER AS $$
BEGIN
    SELECT c.nombre_categoria
    INTO NEW.categoria_nombre
    FROM Producto pr
    JOIN Categoria c ON c.id_categoria = pr.id_categoria
    WHERE pr.id_producto = NEW.id_producto;

    IF NEW.categoria_nombre IS NULL THEN
        RAISE EXCEPTION 'Producto % inexistente: no se puede derivar categoria_nombre', NEW.id_producto;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dp_sync_categoria_nombre ON Detalle_Pedido;
CREATE TRIGGER trg_dp_sync_categoria_nombre
    BEFORE INSERT OR UPDATE OF id_producto, categoria_nombre ON Detalle_Pedido
    FOR EACH ROW EXECUTE FUNCTION fn_dp_sync_categoria_nombre();

-- 3.2 Renombre de una categoría: se propaga a los detalles de sus productos.
CREATE OR REPLACE FUNCTION fn_categoria_propagar_nombre() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Detalle_Pedido dp
    SET categoria_nombre = NEW.nombre_categoria
    FROM Producto pr
    WHERE pr.id_producto  = dp.id_producto
      AND pr.id_categoria = NEW.id_categoria
      AND dp.categoria_nombre IS DISTINCT FROM NEW.nombre_categoria;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_categoria_propagar_nombre ON Categoria;
CREATE TRIGGER trg_categoria_propagar_nombre
    AFTER UPDATE OF nombre_categoria ON Categoria
    FOR EACH ROW
    WHEN (OLD.nombre_categoria IS DISTINCT FROM NEW.nombre_categoria)
    EXECUTE FUNCTION fn_categoria_propagar_nombre();

-- 3.3 Cambio de categoría de un producto: se propaga a sus detalles.
--     (Semántica: el reporte refleja la categoría VIGENTE del catálogo, igual
--     que la consulta normalizada, que une con Categoria en el momento de leer.)
CREATE OR REPLACE FUNCTION fn_producto_propagar_categoria() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Detalle_Pedido dp
    SET categoria_nombre = (SELECT c.nombre_categoria
                            FROM Categoria c
                            WHERE c.id_categoria = NEW.id_categoria)
    WHERE dp.id_producto = NEW.id_producto;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_producto_propagar_categoria ON Producto;
CREATE TRIGGER trg_producto_propagar_categoria
    AFTER UPDATE OF id_categoria ON Producto
    FOR EACH ROW
    WHEN (OLD.id_categoria IS DISTINCT FROM NEW.id_categoria)
    EXECUTE FUNCTION fn_producto_propagar_categoria();

COMMIT;

ANALYZE Detalle_Pedido;

-- ============================================================================
-- 5.2 (d) MEDICIÓN "DESPUÉS": mismo reporte leyendo la columna desnormalizada
-- (2 tablas en lugar de 4: Producto y Categoria desaparecen del plan).
-- ============================================================================
\echo '=== DESPUÉS (corrida 1: descartar) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT dp.categoria_nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY dp.categoria_nombre
ORDER BY total_vendido DESC
LIMIT 5;

\echo '=== DESPUÉS (corrida 2: informar) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT dp.categoria_nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY dp.categoria_nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- Mismo resultado que el reporte normalizado (debe coincidir fila por fila).
\echo '=== RESULTADO DESNORMALIZADO ==='
SELECT dp.categoria_nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM Detalle_Pedido dp
JOIN Pedido ped ON ped.id_pedido = dp.id_pedido
WHERE ped.fecha_hora >= CURRENT_DATE
  AND ped.fecha_hora <  CURRENT_DATE + 1
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY dp.categoria_nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- ============================================================================
-- 5.2 (e) AUDITORÍA: detalles cuya columna redundante difiere de la fuente de
-- verdad. Sobre la base ya migrada debe devolver 0 filas.
-- ============================================================================
\echo '=== AUDITORÍA (esperado: 0 filas) ==='
SELECT dp.id_pedido,
       dp.id_producto,
       dp.categoria_nombre   AS valor_desnormalizado,
       c.nombre_categoria    AS valor_fuente_verdad
FROM Detalle_Pedido dp
JOIN Producto  pr ON pr.id_producto = dp.id_producto
JOIN Categoria c  ON c.id_categoria = pr.id_categoria
WHERE dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria;

-- ============================================================================
-- PRUEBA DE SINCRONIZACIÓN (cada bloque se revierte con ROLLBACK)
-- ============================================================================

-- P1. Alta de detalle: la columna se completa sola, aunque se intente forzar otro valor.
\echo '=== P1: INSERT con categoria_nombre forzada a un valor falso ==='
BEGIN;
WITH p AS (
    INSERT INTO Pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', 1) RETURNING id_pedido
)
INSERT INTO Detalle_Pedido (id_pedido, id_producto, cantidad, precio_unitario, categoria_nombre)
SELECT p.id_pedido, 1, 1, 1050.00, 'VALOR FALSO' FROM p
RETURNING id_pedido, id_producto, categoria_nombre;   -- esperado: la categoría real de producto 1
ROLLBACK;

-- P2. Renombre de categoría: se propaga y la auditoría sigue vacía.
\echo '=== P2: renombre de categoría 1 ==='
BEGIN;
UPDATE Categoria SET nombre_categoria = nombre_categoria || ' (TEST)' WHERE id_categoria = 1;
SELECT count(*) AS detalles_con_nombre_nuevo
FROM Detalle_Pedido WHERE categoria_nombre LIKE '% (TEST)';
SELECT count(*) AS filas_desincronizadas   -- esperado: 0
FROM Detalle_Pedido dp
JOIN Producto pr ON pr.id_producto = dp.id_producto
JOIN Categoria c ON c.id_categoria = pr.id_categoria
WHERE dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria;
ROLLBACK;

-- P3. Cambio de categoría de un producto: se propaga a sus detalles.
\echo '=== P3: producto 1 pasa a la categoría 2 ==='
BEGIN;
UPDATE Producto SET id_categoria = 2 WHERE id_producto = 1;
SELECT DISTINCT categoria_nombre FROM Detalle_Pedido WHERE id_producto = 1;  -- esperado: nombre de la categoría 2
SELECT count(*) AS filas_desincronizadas   -- esperado: 0
FROM Detalle_Pedido dp
JOIN Producto pr ON pr.id_producto = dp.id_producto
JOIN Categoria c ON c.id_categoria = pr.id_categoria
WHERE dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria;
ROLLBACK;

-- ============================================================================
-- REVERSIÓN (sin pérdida de información: categoria_nombre es un dato derivado)
-- Descomentar para volver al esquema normalizado.
-- ============================================================================
-- DROP TRIGGER IF EXISTS trg_dp_sync_categoria_nombre   ON Detalle_Pedido;
-- DROP TRIGGER IF EXISTS trg_categoria_propagar_nombre  ON Categoria;
-- DROP TRIGGER IF EXISTS trg_producto_propagar_categoria ON Producto;
-- DROP FUNCTION IF EXISTS fn_dp_sync_categoria_nombre();
-- DROP FUNCTION IF EXISTS fn_categoria_propagar_nombre();
-- DROP FUNCTION IF EXISTS fn_producto_propagar_categoria();
-- ALTER TABLE Detalle_Pedido DROP COLUMN categoria_nombre;
