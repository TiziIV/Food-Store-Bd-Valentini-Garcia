-- =============================================================================
-- health_check.sql — Parte 3: Monitoreo diario de salud de la base 'foodstore'
-- Proyecto: Food Store — Unidad 6 (Mantenimiento, respaldo y recuperación)
-- Motor: PostgreSQL 16+
-- Ejecución: psql -X -v ON_ERROR_STOP=1 -h localhost -p 5432 -U postgres -d foodstore -f health_check.sql
-- =============================================================================

\echo '=========================================================================='
\echo 'CONTROL 1: Tamaño total en disco de la base de datos foodstore'
\echo '=========================================================================='
SELECT pg_size_pretty(pg_database_size('foodstore')) AS tamano;

\echo ''
\echo '=========================================================================='
\echo 'CONTROL 2: Actividad de conexiones, transacciones confirmadas y rollbacks'
\echo '=========================================================================='
SELECT numbackends, xact_commit, xact_rollback
FROM pg_stat_database
WHERE datname = 'foodstore';

\echo ''
\echo '=========================================================================='
\echo 'CONTROL 3: Estado de tablas (tuplas vivas/muertas, autovacuum y autoanalyze)'
\echo '=========================================================================='
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo ''
\echo '=========================================================================='
\echo 'CONTROL 4: Consultas activas en ejecución (distintas de idle) y su duración'
\echo '=========================================================================='
SELECT pid, state, now() - query_start AS duracion, query
FROM pg_stat_activity
WHERE datname = 'foodstore' AND state <> 'idle';
