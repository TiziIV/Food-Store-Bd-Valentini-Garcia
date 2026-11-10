# TP8 (Unidad 6) — Mantenimiento, Respaldo y Recuperación de Food Store

**Asignatura:** Base de Datos II — Unidad 6: Mantenimiento, respaldo y recuperación (Semana 10)  
**Integrantes:** Valentini, Tiziano — García, Juan Martín  
**Motor:** PostgreSQL 16+ (verificado en PostgreSQL 18.3 sobre Windows / PowerShell)  
**Herramientas:** Kiro / Especificación (`SPEC_U6.md`), OpenCode (asistente de terminal) y Git

---

## Estructura del Entregable

```text
TP8_Mantenimiento_Respaldo/
├── SPEC_U6.md                         # Parte 1: Especificación y plan de mantenimiento (máx. 1 página)
├── backup_foodstore.ps1               # Parte 2: Script PowerShell de respaldo lógico automatizable (-Fc)
├── health_check.sql                   # Parte 3A: Consultas obligatorias de chequeo diario de salud
├── maintenance.sql                    # Parte 3B: Diagnóstico de tuplas muertas y VACUUM (VERBOSE, ANALYZE)
├── restore_test.ps1                   # Parte 4: Simulacro automatizado contra reloj (medición RTO y RPO)
├── informe_u6.md                      # Parte 5: Informe post-incidente en formato Markdown
├── informe_u6.pdf                     # Parte 5: Informe post-incidente exportado a PDF (1 carilla)
├── README.md                          # Guía de ejecución paso a paso y configuración segura
├── backups/
│   └── .gitkeep                       # Destino de archivos *.dump (ignorados en .gitignore por tamaño)
├── logs/
│   └── backup_20261109.log            # Bitácora de ejecución de backup_foodstore.ps1
└── evidencias/
    ├── evidencia_respaldo.txt         # Evidencia de creación, tamaño, fecha y hash SHA-256 del .dump
    ├── salida_health_check.txt        # Salida real de los 4 controles de health_check.sql
    ├── salida_maintenance.txt         # Salida real del diagnóstico y limpieza con maintenance.sql
    └── resultado_simulacro_rto_rpo.txt# Reporte completo del simulacro con RPO, RTO y validaciones
```

---

## Prerrequisitos y Configuración Segura de Credenciales (Cero Contraseñas Expuestas)

Ningún script (`.ps1` o `.sql`) contiene contraseñas hardcodeadas ni define `$env:PGPASSWORD` en texto plano. Para la ejecución automatizada en Windows sin solicitar contraseña interactiva:

1. Crear o editar el archivo `%APPDATA%\postgresql\pgpass.conf` con el formato:
   ```text
   localhost:5432:*:postgres:<contraseña_segura>
   ```
2. Asegurar que los permisos NTFS del archivo `pgpass.conf` estén restringidos exclusivamente al usuario actual del sistema operativo.

---

## Instrucciones de Ejecución Paso a Paso

Posicionado en la raíz del repositorio (`Food-Store-BD-Valentini-Garcia`):

### 1. Generar respaldo lógico automatizado (`Parte 2`)
Ejecuta `pg_dump -Fc` sobre `foodstore`, valida `$LASTEXITCODE` y el tamaño del archivo (`> 0 bytes`), y deja registro en `logs/` y `evidencias/`:
```powershell
powershell -ExecutionPolicy Bypass -File "TP8_Mantenimiento_Respaldo\backup_foodstore.ps1"
```

### 2. Ejecutar chequeo diario de salud (`Parte 3 - Monitoreo`)
Ejecuta los cuatro controles obligatorios (tamaño de `foodstore`, commits/rollbacks en `pg_stat_database`, tuplas vivas/muertas y último autovacuum/autoanalyze en `pg_stat_user_tables`, y consultas activas en `pg_stat_activity`):
```powershell
psql -X -v ON_ERROR_STOP=1 -h localhost -p 5432 -U postgres -d foodstore -f "TP8_Mantenimiento_Respaldo\health_check.sql"
```

### 3. Ejecutar mantenimiento preventivo semanal (`Parte 3 - Mantenimiento`)
Consulta la proporción de tuplas muertas (`n_dead_tup`) y desactualización de estadísticas (`n_mod_since_analyze`), ejecuta `VACUUM (VERBOSE, ANALYZE, INDEX_CLEANUP ON)` sobre las tablas críticas de alta rotación (`pedido`, `detalle_pedido`, `producto`) —sin utilizar `VACUUM FULL`— y verifica la limpieza posterior:
```powershell
psql -X -v ON_ERROR_STOP=1 -h localhost -p 5432 -U postgres -d foodstore -f "TP8_Mantenimiento_Respaldo\maintenance.sql"
```

### 4. Ejecutar simulacro de desastre contra reloj (`Parte 4 - Recuperación y Validación`)
Toma el último archivo `.dump` de `backups/`, calcula el **RPO observado**, inicia el cronómetro (`System.Diagnostics.Stopwatch`), recrea la base descartable `foodstore_restore_test` (sin tocar `foodstore`), restaura con `pg_restore --no-owner --no-privileges`, ejecuta las 3 consultas de validación mínima comparando contra `foodstore`, detiene el cronómetro determinando el **RTO observado**, y guarda el dictamen en `evidencias/resultado_simulacro_rto_rpo.txt`:
```powershell
powershell -ExecutionPolicy Bypass -File "TP8_Mantenimiento_Respaldo\restore_test.ps1"
```
