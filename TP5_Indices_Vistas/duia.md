# DUIA — Declaración de Uso de IA

Cátedra: Base de Datos II — Unidad 3, Semana 5
Herramientas: Kiro (especificación) y OpenCode (agente de codificación en terminal)

---

## Parte A — Plan de indexado

| Campo | Registro documentado |
|---|---|
| Herramienta | Kiro (especificación de requerimientos) y OpenCode (agente terminal de codificación) |
| Spec o prompt entregado | "Acelerar la consulta de productos por categoría y precio excluyendo inactivos, optimizar el historial cronológico de pedidos por cliente, y evaluar índice en Detalle_Pedido minimizando Seq Scan." |
| Qué propuso la IA | Creación de índices sobre Producto, Pedido y Detalle_Pedido, y un índice B-Tree simple sobre Pedido (forma_pago). |
| Qué se aceptó | Los tres índices compuestos, el índice parcial (WHERE activo = TRUE) y el uso de INCLUDE para covering index. |
| Qué se descartó y por qué | `idx_pedido_forma_pago` por baja cardinalidad (4 valores enum) y sobreindexación: penalizaba las escrituras sin ser utilizado por el optimizador. |
| Verificación realizada | Comparación de planes y tiempos con EXPLAIN ANALYZE antes/después de cada índice, y medición de la degradación en la carga de 1.000 INSERT. |

---

## Parte B — Vistas

| Campo | Registro documentado |
|---|---|
| Herramienta | Kiro (especificación de las tres vistas) y OpenCode (generación del CREATE VIEW) |
| Spec o prompt entregado | "Generar tres vistas de solo lectura: productos vigentes con categoría, pedidos con datos del cliente que los realizó, y detalle de pedido con nombre de producto y subtotal." |
| Qué propuso la IA | Las tres vistas con JOIN explícito sobre las tablas base. En la primera versión de `vista_pedidos_cliente`, la IA usó por defecto los nombres genéricos del ejemplo de cátedra (tabla `Usuario`, columna `contraseña`); se corrigió a mano para usar la entidad real del proyecto (`Cliente`, sin columna de contraseña, ya que Food Store no modela autenticación) y ocultar en su lugar el `telefono`. |
| Qué se aceptó | Las tres definiciones de vista, con esa corrección de nombres aplicada en `vista_pedidos_cliente`. |
| Qué se descartó y por qué | No se descartó ninguna vista; se agregó manualmente el cálculo del subtotal en `vista_detalle_pedido_producto`, que no formaba parte de la primera propuesta de la IA. |
| Verificación realizada | Comparación con EXCEPT (en ambos sentidos) entre cada vista y su consulta manual equivalente; 0 filas de diferencia en los tres casos. |

---

## Parte C — Vista materializada

| Campo | Registro documentado |
|---|---|
| Herramienta | Kiro (especificación del reporte a materializar) y OpenCode (generación de la vista materializada e índice) |
| Spec o prompt entregado | "Crear una vista materializada de facturación por categoría y mes, con WITH DATA y un índice único que permita REFRESH CONCURRENTLY a futuro." |
| Qué propuso la IA | La definición de la vista materializada con los cuatro JOIN necesarios, el índice único sobre (id_categoria, mes) y la sugerencia de agregar también cantidad_pedidos como métrica adicional. |
| Qué se aceptó | La vista materializada completa, el índice único propuesto y la métrica adicional cantidad_pedidos. |
| Qué se descartó y por qué | Se descartó la alternativa de un REFRESH automático cada hora mediante un job programado, por resultar innecesario para un reporte de uso mensual y generar carga de escritura evitable sobre la base. |
| Verificación realizada | Medición con EXPLAIN ANALYZE de la consulta agregada original contra la consulta sobre la vista materializada, comparando planes y tiempos de ejecución. |

---

## Nota sobre el flujo de trabajo

En cada una de las tres partes se siguió el mismo flujo exigido por
la cátedra: especificar primero en Kiro (archivos en `specs/`),
generar el SQL con OpenCode a partir de esa especificación, leer y
comprender línea por línea lo generado antes de ejecutarlo, probar
sobre una copia de la base, y versionar cada índice/vista en un
commit separado y descriptivo en Git.

## Nota sobre corrección de nombres (Cliente vs. Usuario)

Al revisar el trabajo completo del proyecto integrador (desde TP1),
se detectó que la primera propuesta de OpenCode para `vista_pedidos_*`
copió el nombre genérico `Usuario` usado como ejemplo ilustrativo en
el enunciado de la cátedra, en lugar de la entidad `Cliente` definida
en el modelo ER y el `schema.sql` reales del proyecto desde la
Semana 1. Se corrigió antes de aceptar la vista, ya que `Usuario` no
existe en el esquema y hubiera roto la ejecución de `views.sql`.

## Revisión posterior de la entrega (Cursor)

| Campo | Registro documentado |
|---|---|
| Herramienta | Cursor (agente en el IDE), sobre índices/vistas/procedimientos ya generados con Kiro/OpenCode |
| Para qué | Revisión de la entrega parcial: huecos de objetivos 5, 6 y 9, y sobreindexación |
| Qué detectó / propuso | Falta de función invocable en PL/pgSQL; `HAVING` ausente o con umbral que no filtraba; soft delete sin llegar a vistas/MV/UNIQUE; deadlock posible en `sp_registrar_pedido` con `FOR UPDATE`; índices duplicados entre TP3/TP4/TP5; reponer stock al anular líneas de la carga masiva |
| Qué se aceptó | `fn_total_pedido` en `LANGUAGE plpgsql` (excepción si no existe); `HAVING` vs promedio entre categorías; propagación de `eliminado`; `uq_cliente_correo_vigente`; `ORDER BY id_producto` en el `FOR` del procedimiento; `stock_descontado`; deduplicación de índices; baja de `idx_detalle_pedido_vigente` (redundante con la PK) |
| Qué se descartó | Umbral fijo `> 100000` en el `HAVING`; recrear el parcial de detalle por `id_pedido`; declarar que “solo se usó Kiro y OpenCode” sin mencionar esta revisión |
