-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 5 — PARTE C
-- Archivo: sql/simulacro_incidente.sql
-- Laboratorio: Simulacro controlado de incidente de acceso indebido
-- (fuerza bruta contra fn_autenticar, login exitoso, lectura masiva de usuario
-- e intento fallido de escalamiento de privilegios hacia admin_datos).
-- Cátedra: Base de Datos II — UTN FRM (Ciclo lectivo 2026)
-- Integrantes: Tiziano Valentini y Juan Martin Garcia
-- ============================================================================
-- IMPORTANTE: Este script se ejecuta exclusivamente contra el entorno local
-- de desarrollo (food_store_dev).
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- ----------------------------------------------------------------------------
-- 0. PREPARACIÓN DE AUDITORÍA PARA CAPTURAR TODA LA SECUENCIA DEL INCIDENTE
-- ----------------------------------------------------------------------------
\connect - postgres

ALTER ROLE app_web SET log_statement = 'all';
ALTER ROLE app_web SET log_min_messages = 'notice';
ALTER ROLE app_web SET log_min_error_statement = 'error';
SELECT pg_reload_conf() AS configuracion_recargada;
SELECT pg_sleep(0.1);

-- ----------------------------------------------------------------------------
-- 1. INICIO DEL SIMULACRO DE INCIDENTE BAJO EL ROL DE LOGIN 'app_web'
-- ----------------------------------------------------------------------------
\connect - app_web

SET application_name = 'foodstore_web_gateway';

-- Desactivamos ON_ERROR_STOP en el cliente psql para que los fallos esperados
-- de permisos (lectura de password_hash y escalamiento a admin_datos) queden
-- registrados en el log del servidor sin abortar la secuencia completa.
\set ON_ERROR_STOP off

-- ----------------------------------------------------------------------------
-- FASE 1: Múltiples intentos fallidos de inicio de sesión contra fn_autenticar
--         (Credential Stuffing / Fuerza Bruta sobre cuentas de Food Store)
-- ----------------------------------------------------------------------------
SELECT * FROM public.fn_autenticar('tiziano.valentini@foodstore.com.ar', 'admin123456');
SELECT * FROM public.fn_autenticar('tiziano.valentini@foodstore.com.ar', 'FoodStore2026!');
SELECT * FROM public.fn_autenticar('matias.quiroga@foodstore.com.ar',    'soporte123');
SELECT * FROM public.fn_autenticar('matias.quiroga@foodstore.com.ar',    'Matias2025*');
SELECT * FROM public.fn_autenticar('matias.quiroga@foodstore.com.ar',    'QuirogaSoporte!');

-- ----------------------------------------------------------------------------
-- FASE 2: Inicio de sesión exitoso tras comprometer la credencial de soporte
-- ----------------------------------------------------------------------------
SELECT * FROM public.fn_autenticar('matias.quiroga@foodstore.com.ar',    'SoporteMatias#26');

-- ----------------------------------------------------------------------------
-- FASE 3: Lectura masiva de la tabla usuario (Exfiltración / Enumeración)
-- ----------------------------------------------------------------------------
-- 3.a) Primer intento del atacante: leer toda la tabla incluyendo password_hash.
--      DEBE FALLAR por el permiso a nivel de columna diseñado en la Parte A.
SELECT * FROM public.usuario;

-- 3.b) Segundo intento del atacante: lectura masiva de las columnas permitidas
--      (id, nombre, email, rol, fecha_alta) de todo el padrón de usuarios.
SELECT id, nombre, email, rol, fecha_alta
FROM public.usuario
ORDER BY id;

-- ----------------------------------------------------------------------------
-- FASE 4: Intentos de escalamiento de privilegios hacia 'admin_datos'
--         y ejecución de operaciones administrativas reservadas (Parte C.1 y C.2)
-- ----------------------------------------------------------------------------
-- 4.a) Intento de asumir directamente el rol administrativo admin_datos:
--      DEBE FALLAR (ERROR: permiso denegado para establecer el rol «admin_datos»)
SET ROLE admin_datos;

-- 4.b) Intento de auto-otorgarse membresía en admin_datos:
--      DEBE FALLAR (ERROR: permiso denegado para otorgar el rol «admin_datos»)
GRANT admin_datos TO app_web;

-- 4.c) Intento de otorgar rol_soporte o admin_datos a otro rol:
--      DEBE FALLAR (app_web tiene NOCREATEROLE y no tiene ADMIN OPTION)
GRANT admin_datos TO rol_app_escritura;

-- 4.d) Intento de ejecutar una operación destructiva reservada sobre usuario:
--      DEBE FALLAR (ERROR: permiso denegado a la tabla usuario)
DELETE FROM public.usuario WHERE rol = 'admin';

-- Confirmamos cuál sigue siendo la identidad efectiva tras los intentos fallidos
SELECT
    session_user AS usuario_sesion,
    current_user AS usuario_efectivo,
    pg_has_role(current_user, 'admin_datos', 'MEMBER') AS tiene_admin_datos;

-- ----------------------------------------------------------------------------
-- 5. CIERRE Y RESTAURACIÓN DE PARÁMETROS DEL ROL
-- ----------------------------------------------------------------------------
\set ON_ERROR_STOP on
\connect - postgres

ALTER ROLE app_web RESET log_statement;
ALTER ROLE app_web RESET log_min_messages;
ALTER ROLE app_web RESET log_min_error_statement;
SELECT pg_reload_conf() AS configuracion_recargada;
