-- ============================================================================
-- semaforo.sql — Motor de resolución de sincronización offline (El Semáforo)
-- Trabajo Práctico N.º 8 — Consigna 2.b
-- Cátedra: Base de Datos II — Ciclo Lectivo 2026
-- Integrantes: Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)
-- Motor: SQLite 3.37+
-- ============================================================================

-- REGLAS DEL SEMÁFORO:
-- 1. Evalúa ÚNICAMENTE las solicitudes en estado 'PENDIENTE' en cola_sync.
-- 2. Cruza item_borrador con snapshot_servidor mediante LEFT JOIN.
-- 3. Precedencia estricta:
--    - ROJO (RECHAZADO): Algún producto no existe en snapshot, tiene marca de baja
--      lógica (eliminado = 't' o '1'), no está disponible (disponible = 'f' o '0'),
--      o la cantidad solicitada supera el stock del servidor.
--    - AMARILLO (CONFLICTO): No hay rojo, pero difiere el precio (precio_visto <> precio_servidor).
--    - VERDE (SIMULADO_APROBADO): Todo coincide exactamente.
-- 4. Idempotente: Las solicitudes con estado resuelto nunca se vuelven a evaluar.

PRAGMA foreign_keys = ON;

WITH evaluacion_items AS (
    SELECT 
        c.solicitud_uuid,
        i.producto_id,
        i.cantidad,
        i.precio_centavos_visto,
        s.nombre AS nombre_servidor,
        s.precio_centavos AS precio_servidor,
        s.stock AS stock_servidor,
        s.disponible AS disponible_servidor,
        s.eliminado AS eliminado_servidor,
        -- Causal ROJO: no existe, deshabilitado, lápida eliminada o falta de stock
        CASE 
            WHEN s.id IS NULL THEN 1
            WHEN s.disponible IN ('f', '0') THEN 1
            WHEN s.eliminado IN ('t', '1') THEN 1
            WHEN i.cantidad > s.stock THEN 1
            ELSE 0
        END AS es_rojo,
        -- Causal AMARILLO: paridad de existencia y stock, pero precio desactualizado
        CASE 
            WHEN (s.id IS NOT NULL AND s.disponible IN ('t', '1') AND s.eliminado IN ('f', '0') AND i.cantidad <= s.stock)
                 AND i.precio_centavos_visto <> s.precio_centavos THEN 1
            ELSE 0
        END AS es_amarillo,
        -- Descripción puntual de la causa para el motivo
        CASE 
            WHEN s.id IS NULL THEN 'Producto ID ' || i.producto_id || ' inexistente en servidor'
            WHEN s.eliminado IN ('t', '1') THEN 'Producto ' || i.producto_id || ' (' || COALESCE(s.nombre, 'S/D') || ') dado de baja en servidor (lapida)'
            WHEN s.disponible IN ('f', '0') THEN 'Producto ' || i.producto_id || ' (' || COALESCE(s.nombre, 'S/D') || ') no disponible para venta'
            WHEN i.cantidad > s.stock THEN 'Stock insuficiente en ' || COALESCE(s.nombre, 'Producto ' || i.producto_id) || ': solicitado ' || i.cantidad || ', disponible ' || s.stock
            WHEN i.precio_centavos_visto <> s.precio_centavos THEN 'Conflicto de precio en ' || COALESCE(s.nombre, 'Producto ' || i.producto_id) || ': visto $' || PRINTF('%.2f', i.precio_centavos_visto / 100.0) || ', servidor $' || PRINTF('%.2f', s.precio_centavos / 100.0)
            ELSE 'OK'
        END AS detalle_item
    FROM cola_sync c
    JOIN item_borrador i ON c.id_local = i.id_local
    LEFT JOIN snapshot_servidor s ON i.producto_id = s.id
    WHERE c.estado = 'PENDIENTE'
),
evaluacion_solicitud AS (
    SELECT 
        solicitud_uuid,
        CASE 
            WHEN SUM(es_rojo) > 0 THEN 'RECHAZADO'
            WHEN SUM(es_amarillo) > 0 THEN 'CONFLICTO'
            ELSE 'SIMULADO_APROBADO'
        END AS nuevo_estado,
        CASE 
            WHEN SUM(es_rojo) > 0 THEN 
                GROUP_CONCAT(CASE WHEN es_rojo = 1 THEN detalle_item ELSE NULL END, '; ')
            WHEN SUM(es_amarillo) > 0 THEN 
                GROUP_CONCAT(CASE WHEN es_amarillo = 1 THEN detalle_item ELSE NULL END, '; ')
            ELSE 'Aprobado: stock y precio coincidentes con instantanea'
        END AS nuevo_motivo
    FROM evaluacion_items
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET estado = evaluacion_solicitud.nuevo_estado,
    motivo = evaluacion_solicitud.nuevo_motivo
FROM evaluacion_solicitud
WHERE cola_sync.solicitud_uuid = evaluacion_solicitud.solicitud_uuid;

-- Mostrar el estado actualizado de la cola de sincronización:
SELECT 
    solicitud_uuid,
    id_local,
    estado,
    motivo
FROM cola_sync
ORDER BY solicitud_uuid ASC;
