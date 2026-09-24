# DUIA — Declaración de Uso de IA

Cátedra: Base de Datos II — Unidad 1, Semana 2 — Laboratorio de Concurrencia
Herramientas: Kiro (especificación) y OpenCode (agente de codificación en terminal)

---

## Parte 1 — Restricciones de integridad y disparadores

| Campo | Registro documentado |
|---|---|
| Herramienta | Kiro (especificación de las reglas de negocio) y OpenCode (generación del `ALTER TABLE`/`CREATE TRIGGER`) |
| Spec o prompt entregado | "Necesito garantizar en el motor: que el correo del cliente tenga formato válido, que el precio de un producto y el precio unitario histórico de un detalle de pedido no puedan ser cero, que un detalle ya facturado no pueda cambiar su cantidad ni su precio, y que no se pueda vender más unidades de las que hay en stock." |
| Qué propuso la IA | Una primera versión con `CHECK` sobre `Pedido.estado` (transición de estado) y `Pedido.fecha_entrega >= Pedido.fecha_pedido`, además del trigger de validación de stock sobre `Detalle_Pedido`. |
| Qué se aceptó | El trigger de validación de stock (`fn_validar_stock_pedido`), tal cual lo propuso la IA: usa columnas reales (`Producto.stock`, `Detalle_Pedido.id_producto`, `Detalle_Pedido.cantidad`) y ya venía completo y correcto. |
| Qué se modificó o descartó, y por qué | Se descartaron las reglas sobre `Pedido.estado` y `Pedido.fecha_entrega`/`fecha_pedido`: esas columnas no existen en el esquema real de Food Store (`schema.sql` solo tiene `fecha_hora`, `forma_pago`, `id_cliente`). La IA las tomó del esquema genérico de ejemplo de la cátedra (el mismo que usa `Usuario` con `estado`/`eliminado`), no del proyecto propio. Se reemplazaron por reglas equivalentes sobre columnas reales: formato de correo en `Cliente`, precio estrictamente positivo en `Producto` y `Detalle_Pedido`, y un trigger que bloquea la modificación de `cantidad`/`precio_unitario` en un detalle ya creado (refuerza la Regla R4 del TP1: el precio facturado no se altera). |
| Verificación realizada | Revisión línea por línea del script contra `TP1_FoodStore/schema.sql` (columnas y tipos reales), y ejecución dentro de `BEGIN ... ROLLBACK` con `INSERT`/`UPDATE` válidos e inválidos sobre una copia de trabajo, según el protocolo de seguridad de la Parte 0 (`protocolo_seguridad.md`). |

## Parte 2 — Laboratorio de anomalías con dos sesiones concurrentes

| Campo | Registro documentado |
|---|---|
| Herramienta | OpenCode, para reconstruir y explicar cada escenario de concurrencia a partir de la secuencia de comandos de las dos sesiones. |
| Spec o prompt entregado | "Tengo estas dos sesiones concurrentes sobre `Producto`/`Pedido` [se adjuntó la secuencia exacta de `BEGIN`, `SELECT`, `UPDATE`, `COMMIT` de cada sesión]. Explicame qué anomalía ocurre y qué nivel de aislamiento o mecanismo de bloqueo la evita." |
| Qué propuso la IA | Para el Escenario 1 (pérdida de actualización sobre `Producto.stock`): identificó la anomalía y propuso `SELECT ... FOR UPDATE` como bloqueo pesimista. Para el Escenario 2 (lectura no repetible sobre `Producto.precio_actual`): propuso subir el nivel de aislamiento a `REPEATABLE READ`. Para el Escenario 3 (prevención de interbloqueos): propuso un orden determinista de acceso a las filas más `lock_timeout` y manejo del error `40P01`. |
| Qué se aceptó | Las tres explicaciones y soluciones, documentadas en detalle en [`informe_concurrencia.md`](informe_concurrencia.md). |
| Qué se modificó o descartó, y por qué | No se descartó ninguna explicación de fondo, pero se corrigió la referencia genérica a "usuario"/"pool de conexiones" del Escenario 3 para hablar en términos del propio dominio (`Producto`, `Detalle_Pedido`), evitando dejar terminología del ejemplo genérico de cátedra en el informe final. |
| Verificación realizada | Cada explicación se contrastó reproduciendo la secuencia de comandos en dos sesiones (`psql`) reales sobre una copia de trabajo de la base, confirmando que el resultado observado en el motor coincide con lo que predijo la IA (ver el detalle paso a paso en `informe_concurrencia.md`). |

## Parte 3 — Lectura crítica de scripts generados por IA

Documentada íntegramente en [`ejercicio_lectura_critica.md`](ejercicio_lectura_critica.md), incluida su propia tabla de DUIA al final de ese archivo (herramienta, prompt, qué se aceptó/descartó y verificación con datos `NULL`).

---

## Nota sobre el flujo de trabajo

Como en el resto del proyecto, cada pieza de este TP siguió el mismo
proceso: especificar primero en Kiro, generar con OpenCode, leer el
diff línea por línea antes de aplicarlo, probar sobre una copia de la
base siguiendo `protocolo_seguridad.md`, y versionar cada pieza en un
commit separado y descriptivo.

## Revisión posterior de la entrega (Cursor)

| Campo | Registro documentado |
|---|---|
| Herramienta | Cursor (agente en el IDE), sobre el SQL e informe ya armados con Kiro/OpenCode |
| Para qué | Revisión de la entrega parcial: detectar huecos de concurrencia y remediación |
| Qué detectó / propuso | Que el trigger de stock leía sin `FOR UPDATE`; que un `DO` con `EXCEPTION WHEN serialization_failure` reintenta dentro del mismo snapshot (no sirve ante `40001`); que la demo de atomicidad debía usar `sp_registrar_pedido` y no un `INSERT` suelto |
| Qué se aceptó | `FOR UPDATE` en `fn_validar_stock_pedido`; sección 6 del informe con atomicidad vía `CALL`, reintento **desde el cliente** con `BEGIN` nuevo, y mensajes `40001` / `40P01`; alineación del nombre de base a `food_store_dev` |
| Qué se descartó | El bloque `DO $$ ... EXCEPTION WHEN serialization_failure` como “evidencia” de reintento: engaña porque falla las N veces sin cambiar de transacción |
