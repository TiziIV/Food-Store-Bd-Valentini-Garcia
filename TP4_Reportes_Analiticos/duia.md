# DUIA — Declaración de Uso de IA

Cátedra: Base de Datos II — Unidad 2, Semana 4 — Reportes analíticos asistidos por IA

## 1. Optimización de las consultas de la Sección 1

- **Herramienta:** Asistente IA (OpenCode).
- **Consigna / spec prompteada:** "Ante este plan de ejecución ineficiente,
  proponé índices o cambios de estructura para mejorar el rendimiento..."
  (con el plan real de `EXPLAIN ANALYZE` adjunto).
- **Criterio de validación y fundamento:** aceptado. La propuesta de
  pre-agregación mediante CTE + Index Only Scan bajó los tiempos de cómputo
  entre 73,6% y 75,0%, coherente con la semántica de las uniones reales del
  modelo.

## 2. Interpretación técnica de los planes de join (Sección 2)

- **Herramienta:** Asistente IA (OpenCode).
- **Consigna / spec prompteada:** "Detallá en profundidad el comportamiento
  de cada nodo en el plan provisto..."
- **Criterio de validación y fundamento:** rechazado parcialmente. La
  herramienta invirtió la relación externa/interna en el `Nested Loop`,
  confundió el `cost` estimado con tiempo real, y atribuyó la elección de
  `Hash Join` a la ausencia de clave primaria (falso: `Detalle_Pedido` sí
  tiene PK compuesta). Las tres correcciones se documentan en
  `informe_mediciones.md`.

## 3. Consultas analíticas de la Sección 3 (ranking y correlacionada)

- **Herramienta:** Asistente IA (OpenCode).
- **Consigna / spec prompteada:** diseño de versión 1 y versión 2 de cada
  consulta bajo especificación estricta, para su posterior validación con
  `EXCEPT`.
- **Criterio de validación y fundamento:** aceptado. El código resultante
  preservó las restricciones lógicas (`activo = TRUE`) y el uso explícito
  de `DENSE_RANK()`; la verificación `EXCEPT` en ambos sentidos dio 0 filas
  para las dos consultas.

## Nota sobre los índices de la Parte 1

Los tres índices propuestos (`idx_producto_activo_categoria`,
`idx_detalle_pedido_facturacion`, `idx_pedido_fecha_cliente`) se
aceptaron tal cual los propuso la IA; el detalle de cost/tiempo antes
y después de cada uno está en `informe_mediciones.md`.
