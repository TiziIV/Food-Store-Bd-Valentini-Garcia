# Food Store — Proyecto Integrador (Base de Datos I y II)

Proyecto integrador de la Tecnicatura Universitaria en Programación
(UTN), desarrollado a lo largo de cinco trabajos prácticos (TP1 a
TP5). Esta entrega corresponde a la primera instancia parcial del
Trabajo Práctico Integrador (TPI): cubre las Unidades 1, 2 y 3 de
Base de Datos II (integridad/transacciones/concurrencia,
optimización de consultas, e índices/vistas/objetos programables).

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
repositorio):

```
Food-Store-Bd-Valentini-Garcia/
├── README.md                     (este archivo)
├── Informe_General.md            (informe técnico del parcial: 9 puntos + por unidad)
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
├── TP5_Indices_Vistas/             (Semana 5 — plan de indexado, vistas, vista materializada)
│   ├── data.sql, queries.sql
│   ├── indices.sql, views.sql, materializadas.sql
│   ├── specs/, duia.md, informe_mediciones.md
│   └── README.md
└── Ampliacion_Parcial_Final/       (cierra los puntos 6 y 9 del checklist del parcial)
    ├── soft_delete.sql             (borrado lógico en Cliente, Pedido, Detalle_Pedido)
    ├── procedimientos.sql          (sp_registrar_pedido, sp_dar_baja_cliente — CALL)
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

# TP2 — restricciones de integridad y disparadores adicionales
psql -d food_store -f TP2_Concurrencia_IA/restricciones.sql

# TP5 — carga de datos (incluye la carga masiva usada desde TP3)
psql -d food_store -f TP5_Indices_Vistas/data.sql

# TP3 — índices de la Semana 3
psql -d food_store -f TP3_Optimizacion_Indices/indices.sql

# TP4 — índices de la Semana 4
psql -d food_store -f TP4_Reportes_Analiticos/indices.sql

# TP5 — plan de indexado final, vistas y vista materializada
psql -d food_store -f TP5_Indices_Vistas/indices.sql
psql -d food_store -f TP5_Indices_Vistas/views.sql
psql -d food_store -f TP5_Indices_Vistas/materializadas.sql

# Ampliación — borrado lógico y procedimientos con CALL (puntos 6 y 9)
psql -d food_store -f Ampliacion_Parcial_Final/soft_delete.sql
psql -d food_store -f Ampliacion_Parcial_Final/procedimientos.sql
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
reversible (protocolo de `protocolo_seguridad.md`), y un commit de
Git separado y descriptivo por cada pieza. El detalle de qué se
aceptó, modificó o descartó de cada propuesta de la IA está en el
`duia.md` de cada carpeta.
