# Diseño — Unidad 4

## Dependencias del esquema heredado

- DF1: `{lote_id, deposito_id} → responsable_control_id`
- DF2: `responsable_control_id → deposito_id`

Claves candidatas: `{lote_id, deposito_id}` y `{lote_id, responsable_control_id}`. DF2 viola FNBC porque su determinante no es superclave. En 3FN no se vería, porque `deposito_id` es primo.

## Descomposición

- `responsable_deposito (responsable_control_id, deposito_id)` con clave `responsable_control_id`
- `asignacion_control_lote (lote_id, responsable_control_id)`

El atributo común es clave de la primera tabla, así que la reunión natural es sin pérdida. Dos triggers impiden que un mismo lote y depósito queden con dos responsables: la descomposición no preserva DF1 solo con claves.

La migración y la comprobación `EXCEPT` viven en una transacción. Si no reconstruye la instancia, `RAISE EXCEPTION` y `ROLLBACK`.

## Desnormalización

Se agrega `detalle_pedido.categoria_nombre` para el top 5 de categorías del día. No se copia la fecha ni el subtotal. La sincronización son tres triggers más un mutex de escritura en `READ COMMITTED`.

Reversión: `herramientas/revertir_desnormalizacion.sql` dropea triggers, funciones y la columna. No toca cantidad ni precio unitario.
