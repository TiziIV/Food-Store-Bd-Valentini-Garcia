-- ============================================================================
-- schema_sqlite.sql — Base de datos local para la tablet móvil (Food Store)
-- Trabajo Práctico N.º 8 — Consigna 1.b
-- Cátedra: Base de Datos II — Ciclo Lectivo 2026
-- Integrantes: Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)
-- Motor: SQLite 3.37+ con tipado estricto (STRICT) y Claves Foráneas activas
-- ============================================================================

-- REGLA DE ORO:
-- "El móvil propone, el servidor dispone."
-- La tablet solo consulta y arma borradores. Precios, stock y ventas los decide PostgreSQL.
-- CERO datos personales, correos reales ni hashes de contraseñas en SQLite.

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. TABLA: producto_cache
-- Catálogo local replicado desde el servidor para operar en modo offline.
-- Precios almacenados en centavos enteros para evitar errores de redondeo IEEE 754.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
-- 2. TABLA: pedido_borrador
-- Encabezado del borrador de pedido confeccionado localmente en la tablet.
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local        TEXT PRIMARY KEY,
    usuario         TEXT NOT NULL,
    forma_pago      TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha           TEXT NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
-- 3. TABLA: item_borrador
-- Líneas de detalle del borrador de pedido. Claves foráneas hacia pedido y producto.
-- ----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local             TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id          INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad             INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- ----------------------------------------------------------------------------
-- 4. TABLA: cola_sync
-- Cola local de solicitudes de sincronización y su estado tras evaluar el semáforo.
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY,
    id_local        TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado          TEXT NOT NULL CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT
) STRICT;

-- ----------------------------------------------------------------------------
-- 5. TABLA: snapshot_servidor
-- Tabla de staging que recibe directamente el volcado CSV exportado de PostgreSQL.
-- Permite comparar en SQLite el estado visto contra el estado actual del servidor.
-- ----------------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT NOT NULL CHECK (disponible IN ('t', 'f', '1', '0')),
    eliminado       TEXT NOT NULL CHECK (eliminado IN ('t', 'f', '1', '0'))
) STRICT;
