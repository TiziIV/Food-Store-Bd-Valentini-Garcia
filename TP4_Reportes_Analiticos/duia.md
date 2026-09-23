# DUIA — Declaración de Uso de IA

Cátedra: Base de Datos II — Unidad 2, Semana 4 — Reportes analíticos asistidos por IA

| Herramienta | Propósito de uso | Consigna / especificación prompteada | Criterio de validación y fundamento |
|---|---|---|---|
| Asistente IA (OpenCode) | Optimización y reescritura de las consultas de la Sección 1 (facturación por categoría/producto y clientes por gasto en 180 días). | "Ante este plan de ejecución ineficiente, proponé índices o cambios de estructura para mejorar el rendimiento..." (plan real de `EXPLAIN ANALYZE` adjunto). | Aceptado: la propuesta de pre-agregación mediante CTE + Index Only Scan bajó los tiempos de cómputo un 73,6%–75,0%, coherente con la semántica de las uniones reales del modelo. |
| Asistente IA (OpenCode) | Interpretación técnica de los nodos del plan en la Sección 2 (lectura crítica). | "Detallá en profundidad el comportamiento de cada nodo en el plan provisto..." | Rechazado parcialmente: la herramienta invirtió la relación externa/interna en el `Nested Loop`, confundió el `cost` estimado con tiempo real, y atribuyó la elección de `Hash Join` a la ausencia de clave primaria (falso: `Detalle_Pedido` sí tiene PK compuesta). Las tres correcciones se documentan en `informe_mediciones.md`. |
| Asistente IA (OpenCode) | Construcción de las consultas analíticas de la Sección 3 (ranking y subconsulta correlacionada). | Diseño de versión 1 y versión 2 de cada consulta bajo especificación estricta, para su posterior validación con `EXCEPT`. | Aceptado: el código resultante preservó las restricciones lógicas (`activo = TRUE`) y el uso explícito de `DENSE_RANK()`; la verificación `EXCEPT` en ambos sentidos dio 0 filas para las dos consultas. |

## Nota sobre los índices de la Parte 1

Los tres índices propuestos (`idx_producto_activo_categoria`,
`idx_detalle_pedido_facturacion`, `idx_pedido_fecha_cliente`) se
aceptaron tal cual los propuso la IA; el detalle de cost/tiempo antes
y después de cada uno está en `informe_mediciones.md`.
