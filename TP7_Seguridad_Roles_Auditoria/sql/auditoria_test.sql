-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 5 — PARTE B
-- Archivo: sql/auditoria_test.sql
-- Activación de parámetros de auditoría nativa en PostgreSQL 16+ y ejecución
-- de secuencia de operaciones de prueba (lectura, inserción, actualización e
-- intento de inicio de sesión fallido).
-- Cátedra: Base de Datos II — UTN FRM (Ciclo lectivo 2026)
-- Integrantes: Tiziano Valentini y Juan Martin Garcia
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- ----------------------------------------------------------------------------
-- 1. ACTIVACIÓN DE PARÁMETROS DE AUDITORÍA EN EL SERVIDOR (Parte B.1)
-- ----------------------------------------------------------------------------
-- Se ejecuta con el superusuario postgres para configurar el clúster mediante
-- ALTER SYSTEM (persiste en postgresql.auto.conf) y recargar en caliente.

ALTER SYSTEM SET logging_collector = 'on';
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'mod';
ALTER SYSTEM SET log_min_messages = 'notice';
ALTER SYSTEM SET log_min_error_statement = 'error';
ALTER SYSTEM SET log_line_prefix = '%m [%p] %q[app=%a] [user=%u@%d] [host=%h] ';

-- Para la sesión de prueba del rol de aplicación (app_web, que es NOSUPERUSER
-- y por ende no puede ejecutar SET log_statement por su cuenta al ser un
-- parámetro de contexto 'superuser'), habilitamos log_statement = 'all' a nivel
-- de rol para capturar tanto la lectura (SELECT) como las modificaciones (DML).
ALTER ROLE app_web SET log_statement = 'all';

-- Recargar la configuración sin reiniciar el servicio de base de datos
SELECT pg_reload_conf() AS configuracion_recargada;
SELECT pg_sleep(0.1);

-- Verificar que los parámetros quedaron activos en pg_settings
SELECT
    name AS parametro,
    setting AS valor_activo,
    unit AS unidad,
    context AS contexto_recarga,
    source AS origen_configuracion
FROM pg_settings
WHERE name IN (
    'logging_collector',
    'log_destination',
    'log_directory',
    'log_connections',
    'log_disconnections',
    'log_statement',
    'log_min_messages',
    'log_line_prefix'
)
ORDER BY name;

-- ----------------------------------------------------------------------------
-- 2. SECUENCIA BREVE DE OPERACIONES DE PRUEBA (Parte B.2)
-- ----------------------------------------------------------------------------
-- Abrimos una conexión real como el rol de login 'app_web' sobre la misma base
-- para que log_connections, log_line_prefix ([user=app_web@...]) y
-- log_disconnections registren fielmente la sesión del rol de aplicación.
\connect - app_web

SET application_name = 'foodstore_auditoria_test';

BEGIN;

-- 2.1. Operación de LECTURA (consulta de catálogo vigente)
SELECT
    id_producto,
    nombre_producto,
    precio_actual,
    stock
FROM public.producto
WHERE id_producto IN (1, 2, 3)
ORDER BY id_producto;

-- 2.2. Operación de INSERCIÓN (nuevo pedido y su línea de detalle)
WITH nuevo_pedido AS (
    INSERT INTO public.pedido (forma_pago, id_cliente)
    VALUES ('BILLETERA_DIGITAL', 1)
    RETURNING id_pedido
)
INSERT INTO public.detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    np.id_pedido,
    1,
    2,
    pr.precio_actual
FROM nuevo_pedido np
CROSS JOIN public.producto pr
WHERE pr.id_producto = 1;

-- 2.3. Operación de ACTUALIZACIÓN (reabastecimiento de stock en producto 1)
UPDATE public.producto
SET stock = stock + 10
WHERE id_producto = 1;

-- 2.4. Intento de inicio de sesión FALLIDO (nivel aplicación contra fn_autenticar)
SELECT *
FROM public.fn_autenticar('sofia.pereyra@foodstore.com.ar', 'PasswordErroneo_2026!');

-- Se revierte la transacción de prueba para mantener intacto el estado de datos
-- mientras el log de auditoría conserva el registro inmutable de lo ejecutado.
ROLLBACK;

-- ----------------------------------------------------------------------------
-- 3. RESTAURACIÓN DE LA POLÍTICA DE AUDITORÍA DE PRODUCCIÓN ('mod')
-- ----------------------------------------------------------------------------
\connect - postgres

ALTER ROLE app_web RESET log_statement;
SELECT pg_reload_conf() AS configuracion_recargada;

-- ============================================================================
-- NOTA PARA PRUEBA DE LOGIN FALLIDO A NIVEL MOTOR (CONEXIÓN TCP/PSQL):
-- Ejecutar desde terminal:
--   psql -h 127.0.0.1 -U intruso_externo -d food_store_dev -c "SELECT 1;"
-- Esto genera en el log del servidor:
--   FATAL:  no existe el rol «intruso_externo»
--   (o FATAL:  password authentication failed for user "app_web" bajo scram-sha-256)
-- ============================================================================
