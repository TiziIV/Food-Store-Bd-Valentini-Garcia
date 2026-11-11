-- ============================================================================
-- vista_postgres_snapshot.sql — Instantánea del catálogo para exportación móvil
-- Trabajo Práctico N.º 8 — Consigna 2.a
-- Cátedra: Base de Datos II — Ciclo Lectivo 2026
-- Integrantes: Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)
-- Motor: PostgreSQL 16+ (probado en PostgreSQL 18.3)
-- ============================================================================

-- REGLA DE ORO:
-- "El móvil propone, el servidor dispone."
-- Esta vista proyecta los datos públicos estrictamente necesarios para la venta
-- offline en las tablets. Excluye deliberadamente costos de compra, auditoría,
-- márgenes, datos personales de clientes y contraseñas.

CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    id_producto                             AS id,
    nombre_producto                         AS nombre,
    ROUND(precio_actual * 100)::INTEGER     AS precio_centavos,
    stock                                   AS stock,
    activo                                  AS disponible,
    (NOT activo)                            AS eliminado
FROM Producto
ORDER BY id_producto ASC;

COMMENT ON VIEW v_snapshot_movil IS 
'Vista de exportación periódica para tablets desconectadas. Normaliza precios a centavos enteros y mapea flags de disponibilidad y lápidas (soft-delete).';

-- ----------------------------------------------------------------------------
-- Comando psql para exportar la instantánea hacia el entorno móvil:
-- \copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER
-- ----------------------------------------------------------------------------
