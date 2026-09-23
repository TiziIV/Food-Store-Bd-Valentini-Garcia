# DUIA — Declaración de Uso de IA

Cátedra: Base de Datos II — Unidad 2, Semana 3 — Optimización asistida por IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode | Generar el script de carga masiva de datos (Parte 1). | "Generá un script SQL para PostgreSQL que inserte 50.000 filas en Producto, 20.000 en Cliente y 200.000 en Pedido usando `generate_series`." | Se aceptó. El script respetó las restricciones (CHECK, UNIQUE, FK) y no usó PL/pgSQL innecesariamente. Queda integrado en [`TP5_Indices_Vistas/data.sql`](../TP5_Indices_Vistas/data.sql), sección "Carga masiva". |
| Kiro | Optimizar la consulta lenta sobre `Detalle_Pedido` (Parte 2, Consulta 3). | "Tengo un plan de ejecución con un Seq Scan lento sobre Detalle_Pedido. ¿Qué índice me sugerís para filtrar por `precio_unitario`?" | Se aceptó. Propuso un índice simple sobre `precio_unitario` (`idx_detalle_pedido_precio`) que redujo el tiempo de ejecución un 86,9%. |
| OpenCode | Explicar en lenguaje natural el plan de ejecución ya optimizado (Parte 3). | "Explicá en lenguaje natural este EXPLAIN ANALYZE con Index Scan, nodo por nodo." | Se descartó parcialmente: la explicación confundió el `Planning Time` con el `Execution Time`, y atribuyó al plan optimizado un descarte de filas (`Rows Removed by Filter`) que en realidad correspondía al plan anterior. El detalle de la corrección está en la tabla de lectura crítica de `informe_mediciones.md`. |
| OpenCode | Generar las consultas resumen y de subconsulta bajo especificación precisa (Parte 4). | Especificaciones detalladas de recaudación por categoría y de clientes sin pedidos (ver [`queries.sql`](queries.sql)). | Se aceptó. Cumplió las restricciones solicitadas (filtro de vigencia, columnas de salida, orden) y las verificaciones `EXCEPT` confirmaron equivalencia entre ambas versiones de cada consulta. |

## Nota sobre el índice de pedidos por cliente y fecha

En la Parte 2, la propuesta original de índice para la Consulta 2
(`idx_pedido_cliente_fecha_hora` sobre `Pedido(id_cliente,
fecha_hora DESC)`) se aceptó tal cual. Ese mismo índice se retomó y
mejoró en el TP5 (`idx_pedido_cliente_fecha_desc`), documentado en su
propia especificación dentro de `TP5_Indices_Vistas/specs/`.
