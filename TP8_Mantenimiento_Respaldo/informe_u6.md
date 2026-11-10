# Informe Post-Incidente — Unidad 6: Mantenimiento, Respaldo y Recuperación

**Proyecto:** Food Store (Base de Datos II — Semana 10) · **Motor:** PostgreSQL 16+ (PostgreSQL 18.3 en Windows / PowerShell)  
**Integrantes:** Valentini, Tiziano — García, Juan Martín · **Bases:** `foodstore` (intacta) → `foodstore_restore_test` (simulacro)

---

## 1. Respaldo Utilizado y Métricas del Simulacro (RPO vs. RTO)

- **Archivo de respaldo:** `backups/foodstore_20261109_221751.dump` (formato *Custom* `-Fc`, generado por `backup_foodstore.ps1` en `1,950 s`).
- **Fecha/hora del respaldo:** `2026-11-09 22:17:53.221 -03:00` · **Tamaño:** `8.433.690 bytes` (`8,04 MB`, desde `179 MB` en disco) · **SHA-256:** `349A7FC7...49AA0B`.
- **Inicio del simulacro (`restore_test.ps1`):** `2026-11-09 22:17:54.802 -03:00` (sobre `foodstore_restore_test`, sin tocar `foodstore`).

| Métrica | Definición conceptual | Valor previsto (Meta) | Valor observado en laboratorio | Desglose / Interpretación técnica |
| :--- | :--- | :--- | :--- | :--- |
| **RPO** (*Recovery Point Objective*) | Pérdida máxima de datos tolerable medida **hacia atrás** en el tiempo (antigüedad del último respaldo válido al ocurrir el incidente). | **$\le$ 24 horas** (ventana de respaldo diario a las 02:00 AM) | **1,58 segundos** (`00h:00m:01s` / `0,03 min`) | En el ensayo se restauró un respaldo recién tomado; en operación productiva con `pg_dump` diario el RPO en el peor caso es de hasta 24 h. |
| **RTO** (*Recovery Time Objective*) | Tiempo máximo tolerable de interrupción medido **hacia adelante** desde que inicia la recuperación hasta validar el servicio. | **$\le$ 300 segundos** (`5 minutos`) | **5,183 segundos** (`5182 ms`) | `createdb`: `0,250 s` (`250 ms`) + `pg_restore`: `4,214 s` (`4214 ms`) + `3 validaciones SQL`: `0,718 s` (`718 ms`). Cumple holgadamente la meta. |

---

## 2. Resultado de las Validaciones de Conteo, Restricciones Lógicas y Mantenimiento

| Tabla validada (`Validación 1`) | Filas en `foodstore` | Filas en `foodstore_restore_test` | Coincidencia | Controles lógicos (`Validaciones 2 y 3`) y Mantenimiento (`Parte 3`) | Resultado |
| :--- | ---: | ---: | :---: | :--- | :---: |
| `categoria` | 12 | 12 | **OK (100%)** | `productos_invalidos` (`precio_actual < 0 OR stock < 0`) | **0 filas** |
| `cliente` | 20.003 | 20.003 | **OK (100%)** | `detalles_invalidos` (`cantidad <= 0 OR precio_unitario < 0`) | **0 filas** |
| `producto` | 50.005 | 50.005 | **OK (100%)** | Limpieza `detalle_pedido` (`23.974` $\rightarrow$ `0` tuplas muertas) | **0,00%** |
| `pedido` | 200.003 | 200.003 | **OK (100%)** | Limpieza `pedido` (`7.719` $\rightarrow$ `0` tuplas muertas) | **0,00%** |
| `detalle_pedido` | 400.011 | 400.011 | **OK (100%)** | Limpieza `producto` (`3.450` $\rightarrow$ `0` tuplas muertas) | **0,00%** |

---

## 3. Problemas Reales Encontrados y Resolución

1. **Diferencia en nombre de columna (`precio` vs. `precio_actual`):** La consulta de referencia de la consigna filtraba `WHERE precio < 0 OR stock < 0` sobre `producto`, pero en nuestro esquema real (`TP1_FoodStore/schema.sql`) la columna se llama `precio_actual`. Se detectó en revisión y prueba manual y se ajustó a `WHERE precio_actual < 0 OR stock < 0`.
2. **Omisión de barrido de índices con `INDEX_CLEANUP AUTO` en PostgreSQL 16+:** Al ejecutar inicialmente `VACUUM (VERBOSE, ANALYZE) detalle_pedido`, PostgreSQL reportó `recorrido de índice pasado por alto (1,63% de páginas con LP_DEAD < umbral del 2%)`, dejando `n_dead_tup` sin limpiar en `pg_stat_user_tables`. Se resolvió especificando `VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON)` sobre `pedido`, `detalle_pedido` y `producto`, reduciendo `n_dead_tup` a `0` sin recurrir a `VACUUM FULL`.
3. **Codificación en Windows PowerShell 5.1:** La lectura de scripts `.ps1` sin BOM en CP1252 interpretaba bytes UTF-8 acentuados (`0x93`) como cierre de comillas. Se normalizó el código fuente de los scripts `.ps1` y se fijó `PGCLIENTENCODING=UTF8`.

---

## 4. Mejora Concreta para Reducir Riesgo y Tiempo en la Siguiente Ejecución

- **Reducción de RTO:** Ejecutar `pg_restore` con paralelismo (`-j 4`) sobre el archivo `-Fc`, paralelizando la carga de tablas e índices pesados (`pk_detalle_pedido`, `idx_detalle_pedido_prod_covering`) para reducir el tiempo de restauración a menos de la mitad cuando la base escale a millones de filas.
- **Reducción de RPO y bloat:** Complementar el `pg_dump` diario con archivado continuo de WAL (*PITR*) para reducir el RPO de 24 h a `< 5 min`, y ajustar `ALTER TABLE detalle_pedido SET (autovacuum_vacuum_scale_factor = 0.05);` (5% en vez de 20%) para que `autovacuum` limpie las tablas de alta rotación sin esperar a acumular 80.000 tuplas muertas.

---

## 5. Trazabilidad de Uso de OpenCode y Verificación Humana

- **Asistencia de OpenCode:** A partir de `SPEC_U6.md`, se utilizó OpenCode para generar la estructura base de `backup_foodstore.ps1` (creación de carpetas, invocación de `pg_dump -Fc` y control de `$LASTEXITCODE`), `restore_test.ps1` (instrumentación con `System.Diagnostics.Stopwatch`) y la consulta diagnóstica de `maintenance.sql`.
- **Verificación y corrección humana:** Se auditó cada archivo verificando: **(a)** ausencia total de contraseñas o variables `$env:PGPASSWORD` (delegando la autenticación a `%APPDATA%\postgresql\pgpass.conf`); **(b)** reemplazo de `precio` por `precio_actual` según `TP1_FoodStore/schema.sql`; **(c)** exclusión de `VACUUM FULL` e incorporación de `INDEX_CLEANUP ON` tras inspeccionar el log real de `VACUUM VERBOSE`; y **(d)** ejecución íntegra contra la instancia local verificando que `foodstore` no sufrió modificaciones.
