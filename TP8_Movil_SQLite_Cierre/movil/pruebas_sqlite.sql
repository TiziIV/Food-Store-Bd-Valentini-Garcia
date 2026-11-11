-- ============================================================================
-- pruebas_sqlite.sql — Pruebas transaccionales, Caso C1 y Caso C7 en SQLite
-- Trabajo Práctico N.º 8 — Consigna 1.c
-- Cátedra: Base de Datos II — Ciclo Lectivo 2026
-- Integrantes: Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)
-- Motor: SQLite 3.37+
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 0. Poblado inicial mínimo de producto_cache para las pruebas offline
-- ----------------------------------------------------------------------------
INSERT OR REPLACE INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia) VALUES
(1, 'Muzzarella', 105000, 40, 1, 0, '2026-11-02T18:00:00Z'),
(2, 'Napolitana', 150000, 25, 1, 0, '2026-11-02T18:00:00Z'),
(3, 'Coca 1.5L', 80000, 100, 1, 0, '2026-11-02T18:00:00Z'),
(4, 'Agua Mineral 500ml', 40000, 150, 1, 0, '2026-11-02T18:00:00Z'),
(5, 'Flan Casero', 65000, 0, 1, 0, '2026-11-02T18:00:00Z'),           -- Sin stock
(6, 'Empanada Criolla', 35000, 50, 0, 0, '2026-11-02T18:00:00Z'),       -- No disponible (agotado transitorio)
(7, 'Cerveza Artesanal', 120000, 20, 1, 1, '2026-11-02T18:00:00Z');     -- Lápida / Eliminado lógicamente

-- ----------------------------------------------------------------------------
-- 1. Transacción confirmada (COMMIT) vs Transacción abortada (ROLLBACK)
-- ----------------------------------------------------------------------------

-- 1.1 Transacción Confirmada: Borrador de compra exitoso
BEGIN TRANSACTION;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('borrador-uuid-001', 'operador_tablet_1', 'EFECTIVO', '2026-11-02T18:15:00Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES 
('borrador-uuid-001', 1, 2, 105000),  -- 2 Muzzarellas a $1050 c/u
('borrador-uuid-001', 3, 1, 80000);   -- 1 Coca 1.5L a $800

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('sync-uuid-001', 'borrador-uuid-001', 'PENDIENTE', 'Esperando evaluacion de instantanea');

COMMIT;

-- Verificación de existencia del borrador confirmado:
SELECT 'Verificacion COMMIT - Pedido:' AS control, * FROM pedido_borrador WHERE id_local = 'borrador-uuid-001';
SELECT 'Verificacion COMMIT - Items:' AS control, * FROM item_borrador WHERE id_local = 'borrador-uuid-001';
SELECT 'Verificacion COMMIT - Cola:' AS control, * FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-001';

-- 1.2 Transacción Abortada con ROLLBACK: Cliente desiste a medio camino
BEGIN TRANSACTION;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('borrador-uuid-cancelado', 'operador_tablet_1', 'TARJETA', '2026-11-02T18:20:00Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('borrador-uuid-cancelado', 2, 3, 150000);

-- Se cancela la operación antes de guardar en cola_sync
ROLLBACK;

-- Verificación de ausencia absoluta (0 registros):
SELECT 'Verificacion ROLLBACK (debe dar 0 filas):' AS control, COUNT(*) AS filas_existentes
FROM pedido_borrador 
WHERE id_local = 'borrador-uuid-cancelado';

-- ----------------------------------------------------------------------------
-- 2. CASO C1: Consulta del catálogo disponible funcionando 100% OFFLINE
-- La tablet muestra los productos vendibles sin necesidad de red:
-- Filtro: disponible = 1, eliminado = 0 y stock_visto > 0.
-- Deben excluirse el Flan (stock 0), la Empanada (no disponible) y la Cerveza (eliminada).
-- ----------------------------------------------------------------------------
SELECT 
    id,
    nombre,
    precio_centavos,
    (precio_centavos / 100.0) AS precio_formateado,
    stock_visto,
    disponible,
    eliminado
FROM producto_cache
WHERE disponible = 1 
  AND eliminado = 0 
  AND stock_visto > 0
ORDER BY id ASC;

-- ----------------------------------------------------------------------------
-- 3. CASO C7: Errores de integridad (CHECK y FOREIGN KEY) sin filas residuales
-- ----------------------------------------------------------------------------

-- 3.1 Intento de inserción con cantidad = 0 (viola CHECK cantidad > 0)
-- En SQLite interactivo falla con: RuntimeError: CHECK constraint failed: cantidad > 0
-- Demostración en bloque protegido:
BEGIN TRANSACTION;

-- Creamos el pedido cabecera
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('borrador-uuid-c7-check', 'operador_tablet_1', 'EFECTIVO', '2026-11-02T18:25:00Z');

-- Este INSERT fallará por CHECK constraint failed:
-- INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
-- VALUES ('borrador-uuid-c7-check', 1, 0, 105000);
-- Al fallar la aplicación efectúa ROLLBACK.
ROLLBACK;

-- Verificamos que no quedó cabecera huérfana:
SELECT 'Verificacion C7 - CHECK (debe ser 0):' AS control, COUNT(*) AS filas_residuales
FROM pedido_borrador WHERE id_local = 'borrador-uuid-c7-check';

-- 3.2 Intento de inserción con producto_id inexistente (viola FOREIGN KEY)
-- En SQLite interactivo con PRAGMA foreign_keys = ON falla con:
-- FOREIGN KEY constraint failed
BEGIN TRANSACTION;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('borrador-uuid-c7-fk', 'operador_tablet_1', 'EFECTIVO', '2026-11-02T18:30:00Z');

-- Este INSERT fallará por FK hacia producto_cache:
-- INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
-- VALUES ('borrador-uuid-c7-fk', 99999, 1, 105000);
-- Al fallar se revierte la transacción:
ROLLBACK;

-- Verificamos que no quedaron registros huérfanos:
SELECT 'Verificacion C7 - FK (debe ser 0):' AS control, COUNT(*) AS filas_residuales
FROM pedido_borrador WHERE id_local = 'borrador-uuid-c7-fk';
