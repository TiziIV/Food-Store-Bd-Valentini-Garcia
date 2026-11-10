# Food Store — Proyecto Integrador (Base de Datos I y II)

Proyecto integrador de la Tecnicatura Universitaria en Programación
(UTN), desarrollado a lo largo de cinco trabajos prácticos (TP1 a
TP5) para la primera instancia parcial y ampliado con las entregas de
las Unidades 4, 5 y 6 (TP6, TP7 y TP8). Cubre las Unidades 1 a 6 de
Base de Datos II (integridad/transacciones/concurrencia,
optimización de consultas, índices/vistas/objetos programables,
FNBC/desnormalización, administración/seguridad/auditoría, y
mantenimiento/respaldo/recuperación).

Motor de referencia: **PostgreSQL 16+**. Herramientas de IA usadas a
lo largo de toda la cursada: **Kiro** (especificación) y **OpenCode**
(agente de codificación en terminal), según el protocolo de la
cátedra descripto en [`protocolo_seguridad.md`](protocolo_seguridad.md).

## Informe general de la entrega

Ver [`Informe_General.md`](Informe_General.md) para el resumen
técnico exigido por la consigna del parcial: qué se implementó en
cada unidad, cómo se probó, qué resultados dio, qué se optimizó y
con qué diferencia antes/después, y el uso de IA a lo largo del
proyecto.

## Estructura del repositorio

El repositorio está dividido por trabajo práctico. Cada carpeta
contiene el código y la documentación real de ese TP (no los PDF de
consigna ni de informe entregados a la cátedra, que quedan fuera del
repositorio, salvo cuando la consigna solicita el PDF en la carpeta del TP):

```
Food-Store-Bd-Valentini-Garcia/
├── README.md                     (este archivo)
├── Informe_General.md            (informe técnico general del proyecto integrador)
├── protocolo_seguridad.md        (copia de trabajo, transacción, respaldo — Parte 0 de TP2)
├── TP1_FoodStore/                 (Semana 1 — ER, modelo relacional, normalización, DDL)
│   ├── schema.sql
│   ├── diagrama-er.png
│   └── modelo_relacional_y_normalizacion.md
├── TP2_Concurrencia_IA/            (Semana 2 — integridad, transacciones, concurrencia)
│   ├── restricciones.sql
│   ├── informe_concurrencia.md
│   ├── ejercicio_lectura_critica.md
│   └── duia.md
├── TP3_Optimizacion_Indices/       (Semana 3 — filtros, EXPLAIN ANALYZE, índices)
│   ├── indices.sql
│   ├── queries.sql
│   ├── duia.md
│   └── informe_mediciones.md
├── TP4_Reportes_Analiticos/        (Semana 4 — joins, agregación, funciones de ventana)
│   ├── indices.sql
│   ├── queries.sql
│   ├── duia.md
│   └── informe_mediciones.md
├── TP5_Indices_Vistas/             (Semana 5 — índices, vistas, materializadas,
│   │                                borrado lógico y procedimientos)
│   ├── data.sql, queries.sql
│   ├── indices.sql, views.sql, materializadas.sql
│   ├── soft_delete.sql
│   ├── procedimientos.sql
│   ├── specs/, duia.md, informe_mediciones.md
│   └── README.md
├── TP6_FNBC_Desnormalizacion/      (Semana 8 — Unidad 4: FNBC y desnormalización controlada)
│   ├── tp_fnbc_control_lote.sql, tp_desnormalizacion_top_categorias.sql
│   ├── informe_fnbc_desnormalizacion.pdf
│   ├── evidencias/, herramientas/
│   └── README.md
├── TP7_Seguridad_Roles_Auditoria/  (Semana 9 — Unidad 5: roles, auditoría, incidentes y PII)
│   ├── sql/, docs/
│   ├── BITACORA.md
│   └── README.md
├── TP8_Mantenimiento_Respaldo/     (Semana 10 — Unidad 6: mantenimiento, respaldo y recuperación)
│   ├── SPEC_U6.md
│   ├── backup_foodstore.ps1, restore_test.ps1
│   ├── health_check.sql, maintenance.sql
│   ├── informe_u6.md, informe_u6.pdf
│   ├── evidencias/, logs/, backups/
│   └── README.md
├── TP7_NoSQL_MongoDB/              (Semana 11 — Unidad 7: NoSQL y modelo documental en MongoDB)
│   ├── consultas_mongodb.js
│   ├── consultas_postgresql.sql
│   ├── informe_nosql_mongodb.md, informe_nosql_mongodb.pdf
│   ├── duia.md
│   └── README.md
└── TP8_Movil_SQLite_Cierre/        (Semanas 12-13 — Unidad 8: base móvil SQLite y cierre de capa de datos)
    ├── movil/ (schema_sqlite.sql, pruebas_sqlite.sql, semaforo.sql, simulador.py, foodstore_movil.db, etc.)
    ├── docs/ (informe.md, informe.pdf, bitacora_ia.md, DUIA.md, kiro/)
    └── README.md
```

**Nota de diseño:** el esquema (`schema.sql`) vive una sola vez, en
`TP1_FoodStore/`, porque es la pieza fundacional del proyecto y no se
modifica en los trabajos posteriores. La carga de datos ampliada
(`data.sql`, con la carga masiva de TP3/TP4) y las consultas de
negocio (`queries.sql`) quedan consolidadas en `TP5_Indices_Vistas/`,
que es el estado más reciente del proyecto. Cada TP2, TP3 y TP4
agrega solo lo que le es propio (restricciones, índices, consultas
analíticas, documentación) sobre esa base compartida.

## Cómo reproducir el proyecto completo, en orden

Requisitos: PostgreSQL 16+ y `psql` disponible en la terminal.

```bash
createdb food_store

# TP1 — esquema base
psql -d food_store -f TP1_FoodStore/schema.sql

# Carga masiva ANTES del trigger de stock. data.sql inserta ~400.000
# detalles con stock aleatorio de 0 a 200; si el trigger ya está
# activo, miles de líneas fallan con "Stock insuficiente" y el
# BEGIN/COMMIT de data.sql revierte toda la carga.
psql -d food_store -f TP5_Indices_Vistas/data.sql

# TP2 — restricciones y disparadores (después de los datos)
psql -d food_store -f TP2_Concurrencia_IA/restricciones.sql

# Índices. TP3 y TP4 no recrean los que TP5 define iguales
# (idx_pedido_cliente_fecha_desc e idx_detalle_pedido_prod_covering).
psql -d food_store -f TP3_Optimizacion_Indices/indices.sql
psql -d food_store -f TP4_Reportes_Analiticos/indices.sql
psql -d food_store -f TP5_Indices_Vistas/indices.sql

# Borrado lógico antes de vistas: las vistas y la materializada
# filtran eliminado = FALSE.
psql -d food_store -f TP5_Indices_Vistas/soft_delete.sql
psql -d food_store -f TP5_Indices_Vistas/views.sql
psql -d food_store -f TP5_Indices_Vistas/materializadas.sql
psql -d food_store -f TP5_Indices_Vistas/procedimientos.sql
```

Cada carpeta tiene su propio detalle de verificación (`EXPLAIN
ANALYZE` antes/después, verificación de equivalencia con `EXCEPT`,
DUIA) en su `duia.md` e `informe_mediciones.md` correspondientes.

## Flujo de trabajo con IA (transversal a todo el proyecto)

Cada pieza del proyecto —cada restricción, índice, vista o
consulta— siguió el mismo proceso en todos los TP: especificación en
Kiro, generación con OpenCode como agente de codificación en
terminal, lectura línea por línea del resultado antes de ejecutarlo,
prueba sobre una copia de la base dentro de una transacción
reversible (protocolo de `protocolo_seguridad.md`). El detalle de qué se
aceptó, modificó o descartó de cada propuesta de la IA está en el
`duia.md` de cada carpeta.


## Unidad 4: TP6 - FNBC y desnormalización

La entrega está en [TP6_FNBC_Desnormalizacion](TP6_FNBC_Desnormalizacion/README.md). Los dos SQL y el informe PDF están en la raíz de TP6; las salidas y capturas en `evidencias/`, y los scripts auxiliares en `herramientas/`.

## Unidad 5: TP7 - Administración y seguridad de Food Store (roles, auditoría, incidentes y protección de datos personales)

La entrega está en [TP7_Seguridad_Roles_Auditoria](TP7_Seguridad_Roles_Auditoria/README.md). Incluye los scripts SQL (`sql/roles.sql`, `sql/auditoria_test.sql`, `sql/simulacro_incidente.sql`, `sql/usuario_anon.sql`), la especificación Kiro (`docs/kiro_roles_spec/requirements.md` y `design.md`), los logs e informes técnicos (`docs/informe_auditoria.md`, `docs/log_auditoria_prueba.txt`, `docs/log_simulacro_anonimizado.txt`, `docs/informe_incidente.md`, `docs/verificacion_equivalencia.md`) y la bitácora consolidada de uso crítico de IA en [`TP7_Seguridad_Roles_Auditoria/BITACORA.md`](TP7_Seguridad_Roles_Auditoria/BITACORA.md).

## Unidad 6: TP8 - Mantenimiento, respaldo y recuperación de Food Store

La entrega está en [TP8_Mantenimiento_Respaldo](TP8_Mantenimiento_Respaldo/README.md). Incluye la especificación y plan de mantenimiento ([`SPEC_U6.md`](TP8_Mantenimiento_Respaldo/SPEC_U6.md)), el script PowerShell de respaldo lógico automatizable en formato custom ([`backup_foodstore.ps1`](TP8_Mantenimiento_Respaldo/backup_foodstore.ps1)), las consultas de monitoreo diario ([`health_check.sql`](TP8_Mantenimiento_Respaldo/health_check.sql)) y mantenimiento preventivo justificado con `VACUUM (VERBOSE, ANALYZE)` ([`maintenance.sql`](TP8_Mantenimiento_Respaldo/maintenance.sql)), el simulacro automatizado de recuperación ante desastres contra reloj sobre `foodstore_restore_test` con medición de RPO y RTO ([`restore_test.ps1`](TP8_Mantenimiento_Respaldo/restore_test.ps1)), las evidencias de ejecución en `evidencias/` y `logs/`, y el informe post-incidente en [`informe_u6.md`](TP8_Mantenimiento_Respaldo/informe_u6.md) e [`informe_u6.pdf`](TP8_Mantenimiento_Respaldo/informe_u6.pdf).

## Unidad 7: TP7 NoSQL - Modelado Documental en MongoDB y Validación Cruzada

La entrega está en [TP7_NoSQL_MongoDB](TP7_NoSQL_MongoDB/README.md). Cubre el modelado documental desnormalizado en MongoDB (`food_store_nosql.pedidos`) con validador formal `$jsonSchema`, importes exactos en `Decimal128` (`NumberDecimal`), migración de 6 pedidos reales desde PostgreSQL, consultas en `mongosh` y `psql`, tabla de verificación cruzada y bitácora/lectura crítica de IA con evidencias de laboratorio ([`informe_nosql_mongodb.md`](TP7_NoSQL_MongoDB/informe_nosql_mongodb.md), [`informe_nosql_mongodb.pdf`](TP7_NoSQL_MongoDB/informe_nosql_mongodb.pdf) y [`duia.md`](TP7_NoSQL_MongoDB/duia.md)).

## Unidad 8: TP8 Móvil - La Base de la Tablet (SQLite) y Cierre de la Capa de Datos

La entrega está en [TP8_Movil_SQLite_Cierre](TP8_Movil_SQLite_Cierre/README.md). Cubre la sincronización offline-first asimétrica (*"El móvil propone, el servidor dispone"*), el esquema SQLite 3.37+ con `STRICT` y `PRAGMA foreign_keys = ON` ([`schema_sqlite.sql`](TP8_Movil_SQLite_Cierre/movil/schema_sqlite.sql)), las pruebas transaccionales ([`pruebas_sqlite.sql`](TP8_Movil_SQLite_Cierre/movil/pruebas_sqlite.sql)), el motor del semáforo de resolución ([`semaforo.sql`](TP8_Movil_SQLite_Cierre/movil/semaforo.sql) y [`simulador.py`](TP8_Movil_SQLite_Cierre/movil/simulador.py)), la especificación EARS en Kiro (`docs/kiro/`), la bitácora de uso de IA ([`bitacora_ia.md`](TP8_Movil_SQLite_Cierre/docs/bitacora_ia.md), [`DUIA.md`](TP8_Movil_SQLite_Cierre/docs/DUIA.md)) y el informe integrador de cierre de los 3 motores ([`informe.md`](TP8_Movil_SQLite_Cierre/docs/informe.md) e [`informe.pdf`](TP8_Movil_SQLite_Cierre/docs/informe.pdf)).

