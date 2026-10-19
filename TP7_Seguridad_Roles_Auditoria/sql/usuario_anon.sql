-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 5 — PARTE D
-- Archivo: sql/usuario_anon.sql
-- Protección de datos personales: construcción determinista de usuario_anon
-- y consultas de verificación de equivalencia analítica frente a usuario.
-- Cátedra: Base de Datos II — UTN FRM (Ciclo lectivo 2026)
-- Integrantes: Tiziano Valentini y Juan Martin Garcia
-- Motor: PostgreSQL 16+ (verificado en PostgreSQL 18.3)
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. CREACIÓN Y POBLADO DETERMINISTA DE public.usuario_anon (Parte D.1)
-- ----------------------------------------------------------------------------
-- Seudonimización determinista:
--   * id: se conserva como clave subrogada numérica para mantener cardinalidad.
--   * nombre_anon: 'Usuario_' || primeros 8 hex del MD5('fs_nombre_' || id)
--   * email_anon:  'usr_' || primeros 10 hex del MD5(lower(email)) || '@anon.foodstore.local'
--   * password_hash: hash SHA-256 irreversible derivado ('anon_pwd_' || password_hash),
--                    nunca el hash real de producción.
--   * rol y fecha_alta: se preservan intactos para no distorsionar los
--                       agrupamientos ni las series temporales de análisis.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.usuario_anon (
    id            BIGINT PRIMARY KEY,
    nombre_anon   VARCHAR(120) NOT NULL,
    email_anon    VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    rol           VARCHAR(40) NOT NULL,
    fecha_alta    TIMESTAMPTZ NOT NULL
);

TRUNCATE TABLE public.usuario_anon;

INSERT INTO public.usuario_anon (
    id,
    nombre_anon,
    email_anon,
    password_hash,
    rol,
    fecha_alta
)
SELECT
    u.id,
    'Usuario_' || substr(md5('fs_nombre_' || u.id::text), 1, 8) AS nombre_anon,
    'usr_' || substr(md5(lower(u.email)), 1, 10) || '@anon.foodstore.local' AS email_anon,
    encode(digest('anon_pwd_' || u.password_hash, 'sha256'), 'hex') AS password_hash,
    u.rol,
    u.fecha_alta
FROM public.usuario u
ORDER BY u.id;

-- Reasegurar permisos de lectura para rol_reportes, rol_auditor y admin_datos
GRANT SELECT ON TABLE public.usuario_anon TO rol_reportes, rol_auditor;
GRANT ALL PRIVILEGES ON TABLE public.usuario_anon TO admin_datos;

COMMIT;

-- ----------------------------------------------------------------------------
-- 2. MUESTRA DE VERIFICACIÓN DE ANONIMIZACIÓN DETERMINISTA (5 FILAS)
-- ----------------------------------------------------------------------------
SELECT
    u.id,
    u.nombre AS nombre_real,
    ua.nombre_anon,
    u.email AS email_real,
    ua.email_anon,
    u.rol,
    to_char(u.fecha_alta, 'YYYY-MM-DD') AS fecha_alta
FROM public.usuario u
JOIN public.usuario_anon ua ON ua.id = u.id
WHERE u.id IN (101, 202, 301, 801, 1001)
ORDER BY u.id;

-- ----------------------------------------------------------------------------
-- 3. CONSULTAS DE AGREGACIÓN EQUIVALENTES (Parte D.2 y D.3)
-- ----------------------------------------------------------------------------

-- 3.1. Consulta A: Agregación sobre la tabla anonimizada (public.usuario_anon)
--      Cantidad de usuarios, primer alta y última alta por rol y mes de alta.
SELECT
    to_char( date_trunc('month', ua.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM' ) AS mes_alta,
    ua.rol,
    COUNT(*) AS cantidad_usuarios,
    MIN(ua.fecha_alta)::date AS primera_alta_mes,
    MAX(ua.fecha_alta)::date AS ultima_alta_mes
FROM public.usuario_anon ua
GROUP BY
    date_trunc('month', ua.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    ua.rol
ORDER BY
    mes_alta ASC,
    ua.rol ASC;

-- 3.2. Consulta B: Consulta equivalente sobre la tabla real (public.usuario)
SELECT
    to_char( date_trunc('month', u.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM' ) AS mes_alta,
    u.rol,
    COUNT(*) AS cantidad_usuarios,
    MIN(u.fecha_alta)::date AS primera_alta_mes,
    MAX(u.fecha_alta)::date AS ultima_alta_mes
FROM public.usuario u
GROUP BY
    date_trunc('month', u.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    u.rol
ORDER BY
    mes_alta ASC,
    u.rol ASC;

-- ----------------------------------------------------------------------------
-- 4. DEMOSTRACIÓN FORMAL DE EQUIVALENCIA CON DIFERENCIA SIMÉTRICA (EXCEPT)
--    Debe devolver exactamente 0 filas.
-- ----------------------------------------------------------------------------
WITH agg_anon AS (
    SELECT
        to_char( date_trunc('month', ua.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM' ) AS mes_alta,
        ua.rol,
        COUNT(*) AS cantidad_usuarios,
        MIN(ua.fecha_alta)::date AS primera_alta_mes,
        MAX(ua.fecha_alta)::date AS ultima_alta_mes
    FROM public.usuario_anon ua
    GROUP BY 1, 2
),
agg_real AS (
    SELECT
        to_char( date_trunc('month', u.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM' ) AS mes_alta,
        u.rol,
        COUNT(*) AS cantidad_usuarios,
        MIN(u.fecha_alta)::date AS primera_alta_mes,
        MAX(u.fecha_alta)::date AS ultima_alta_mes
    FROM public.usuario u
    GROUP BY 1, 2
)
(SELECT * FROM agg_anon EXCEPT ALL SELECT * FROM agg_real)
UNION ALL
(SELECT * FROM agg_real EXCEPT ALL SELECT * FROM agg_anon);
