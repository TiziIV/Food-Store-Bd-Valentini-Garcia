# Especificación y Plan de Mantenimiento — Unidad 6 (`SPEC_U6.md`)

**Proyecto:** Food Store (Base de Datos II — Semana 10) · **Motor:** PostgreSQL 16+ (verificado en PostgreSQL 18.3, Windows / PowerShell)  
**Integrantes:** Valentini, Tiziano — García, Juan Martín  
**Base principal (producción):** `foodstore` · **Base descartable (simulacro):** `foodstore_restore_test`

---

## 1. Objetivo y Alcance
Definir el procedimiento operativo automatizable de **respaldo lógico, monitoreo de salud, mantenimiento preventivo y recuperación ante desastres (DRP)** para la base de datos `foodstore`. Esta especificación actúa como contrato técnico previo a la generación y ajuste de scripts con **OpenCode**, garantizando que ninguna operación ponga en riesgo la disponibilidad ni la integridad de la base principal.

---

## 2. Plan de Mantenimiento y Automatización

| Tarea mínima | Frecuencia propuesta | Script / Artefacto | Condición de confirmación de éxito | Evidencia generada |
| :--- | :--- | :--- | :--- | :--- |
| **Respaldo de `foodstore`** | **Diaria** (02:00 AM, ventana de baja carga) | `backup_foodstore.ps1` (`pg_dump -Fc`) | `$LASTEXITCODE -eq 0`, archivo `.dump` existente en `backups/` con tamaño `> 0 bytes` y hash SHA-256 calculado. | Archivo `backups/foodstore_YYYYMMDD_HHMMSS.dump`, `logs/backup_YYYYMMDD.log` y `evidencias/evidencia_respaldo.txt`. |
| **Chequeo de salud** | **Diaria** (08:00 AM, inicio de jornada) | `health_check.sql` | Ejecución sin errores (`ON_ERROR_STOP=1`) de los 4 controles: tamaño de base, commits/rollbacks, estado de tuplas/autovacuum y consultas activas sin bloqueos. | `evidencias/salida_health_check.txt`. |
| **Revisión de mantenimiento** | **Semanal** (Domingos 03:00 AM) | `maintenance.sql` | Diagnóstico previo de `n_dead_tup` y `n_mod_since_analyze`; ejecución de `VACUUM (VERBOSE, ANALYZE)` en `pedido`, `detalle_pedido` y `producto`; descenso de `n_dead_tup` a `0`. | `evidencias/salida_maintenance.txt`. |
| **Restauración de prueba** | **Semanal** (Domingos 04:00 AM, post-backup) | `restore_test.ps1` (`createdb` + `pg_restore`) | Restauración completa en `foodstore_restore_test` (`$LASTEXITCODE -eq 0`), conteos de filas idénticos a `foodstore`, `productos_invalidos = 0`, `detalles_invalidos = 0` y RTO/RPO medidos. | `evidencias/resultado_simulacro_rto_rpo.txt`. |

---

## 3. Reglas Críticas de Seguridad y Operación

1. **Cero contraseñas expuestas:** Ningún script (`.ps1` o `.sql`) ni archivo versionado en Git puede contener contraseñas hardcodeadas ni asignaciones `$env:PGPASSWORD` en texto plano. La autenticación desatendida se resuelve exclusivamente mediante `%APPDATA%\postgresql\pgpass.conf` (formato `localhost:5432:*:postgres:<password>`, con permisos restringidos al usuario del sistema operativo) o variables de entorno externas inyectadas de forma segura por el programador de tareas.
2. **Protección estricta de la base principal (`foodstore`):** La base `foodstore` jamás se elimina, trunca ni sobrescribe durante las pruebas. Todo ensayo de recuperación o prueba destructiva se ejecuta de manera aislada sobre `foodstore_restore_test`.
3. **Prohibición de `VACUUM FULL` periódico:** Queda prohibido incluir `VACUUM FULL` en el mantenimiento programado porque reescribe físicamente las tablas y adquiere un bloqueo `ACCESS EXCLUSIVE` que bloquea lecturas y escrituras concurrentes. Sólo se autoriza `VACUUM (VERBOSE, ANALYZE)` sobre las tablas de alta rotación (`pedido`, `detalle_pedido`, `producto`), justificado por la observación previa de tuplas muertas (`n_dead_tup`) acumuladas por debajo del umbral de disparo automático (`autovacuum_vacuum_scale_factor = 0.20`).
4. **Respeto por el esquema físico real (`TP1_FoodStore/schema.sql`):** Las consultas de validación e integridad deben emplear los nombres reales del proyecto (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`, `usuario`), utilizando `producto.precio_actual` (y no el nombre genérico `precio`) junto con `detalle_pedido.precio_unitario`.
5. **Formato de respaldo:** El respaldo se realiza en formato binario comprimido *Custom* (`-Fc`) para habilitar restauración selectiva, verificación de catálogo y uso de `pg_restore --no-owner --no-privileges`.

---

## 4. Trazabilidad y Subordinación del Trabajo con OpenCode

- **Flujo de trabajo:** `SPEC_U6.md` se utiliza como especificación de entrada para generar la primera versión de `backup_foodstore.ps1`, `health_check.sql`, `maintenance.sql` y `restore_test.ps1` con **OpenCode**.
- **Verificación humana obligatoria antes de ejecutar:**
  1. Inspección estática del código generado para verificar la ausencia total de credenciales y comandos destructivos sobre `foodstore`.
  2. Adaptación de nombres de columnas al esquema real del repositorio (`precio_actual` en `producto`).
  3. Ejecución manual supervisada en consola PowerShell contra PostgreSQL local antes de dar por aprobado cada script para programación periódica.
