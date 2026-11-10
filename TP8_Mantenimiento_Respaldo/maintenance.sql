-- =============================================================================
-- maintenance.sql — Parte 3: Diagnóstico y mantenimiento preventivo seguro
-- Proyecto: Food Store — Unidad 6 (Mantenimiento, respaldo y recuperación)
-- Motor: PostgreSQL 16+
-- Ejecución: psql -X -v ON_ERROR_STOP=1 -h localhost -p 5432 -U postgres -d foodstore -f maintenance.sql
-- =============================================================================
--
-- CRITERIO TÉCNICO Y JUSTIFICACIÓN (Regla Crítica de Aprobación):
-- 1. Por qué NO se utiliza VACUUM FULL como mantenimiento periódico:
--    VACUUM FULL reescribe físicamente toda la tabla y sus índices en archivos
--    nuevos de disco y adquiere un bloqueo ACCESS EXCLUSIVE sobre la relación.
--    Esto bloquea por completo tanto lecturas (SELECT) como escrituras
--    (INSERT/UPDATE/DELETE) durante toda la operación, provocando caída de
--    servicio en un entorno OLTP como Food Store y duplicando temporalmente
--    el espacio en disco necesario.
--
-- 2. Por qué se aplica VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON) en
--    'pedido', 'detalle_pedido' y 'producto':
--    La consulta diagnóstica previa sobre pg_stat_user_tables revela que las
--    tres tablas transaccionales de alta rotación acumulan miles de tuplas
--    muertas (n_dead_tup > 0: versiones obsoletas generadas por actualizaciones
--    de stock en 'producto' y operaciones sobre 'pedido' y 'detalle_pedido')
--    y filas modificadas desde el último análisis (n_mod_since_analyze).
--    Dado el volumen de estas tablas (400.011 filas en detalle_pedido,
--    200.003 en pedido y 50.005 en producto), el umbral por defecto de
--    autovacuum (autovacuum_vacuum_threshold = 50 + 0.20 * n_live_tup) exige
--    acumular ~80.052, ~40.051 y ~10.051 tuplas muertas respectivamente antes
--    de disparar la limpieza automática.
--    Además, en PostgreSQL 16+, el modo por defecto INDEX_CLEANUP AUTO omite
--    el barrido de índices si menos del 2% de las páginas de la tabla tienen
--    punteros muertos (LP_DEAD), lo que ocurría en detalle_pedido (111 de
--    6.513 páginas = 1,63% < 2%). Al especificar VACUUM (VERBOSE, ANALYZE,
--    INDEX_CLEANUP ON) durante la ventana semanal:
--      a) Se limpian efectivamente los punteros LP_DEAD en índices y tabla,
--         liberando espacio reutilizable en el Free Space Map (FSM) y
--         actualizando el Visibility Map (habilitando Index-Only Scans) con un
--         bloqueo SHARE UPDATE EXCLUSIVE que NO bloquea lecturas ni escrituras.
--      b) Se actualizan las estadísticas de distribución en pg_statistic
--         (ANALYZE) para que el optimizador elija planes de ejecución óptimos.
-- =============================================================================

\echo '=========================================================================='
\echo '1. DIAGNOSTICO PREVIO: Proporcion de tuplas muertas y estado de estadisticas'
\echo '=========================================================================='
SELECT
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND(
        100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0),
        2
    ) AS pct_tuplas_muertas,
    n_mod_since_analyze AS mod_desde_analyze,
    ROUND(50 + 0.20 * n_live_tup) AS umbral_autovacuum_20pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, n_live_tup DESC;

\echo ''
\echo '=========================================================================='
\echo '2. ACCION DE MANTENIMIENTO SEGURO: VACUUM (VERBOSE, ANALYZE) en tablas criticas'
\echo '=========================================================================='
-- Limpieza de tuplas muertas, barrido de indices y actualizacion de estadisticas sin bloqueo exclusivo
VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON) pedido;
VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON) detalle_pedido;
VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON) producto;

\echo ''
\echo '=========================================================================='
\echo '3. VERIFICACION POST-MANTENIMIENTO: Confirmacion de limpieza y estadisticas'
\echo '=========================================================================='
SELECT
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND(
        100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0),
        2
    ) AS pct_tuplas_muertas,
    n_mod_since_analyze AS mod_desde_analyze,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE relname IN ('detalle_pedido', 'pedido', 'producto')
ORDER BY n_live_tup DESC;
