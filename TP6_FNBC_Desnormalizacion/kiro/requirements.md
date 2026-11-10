# Requisitos — Unidad 4: FNBC y desnormalización

**Proyecto:** Food Store  
**Equipo:** Tiziano Valentini y Juan Martin Garcia  
**Notación:** EARS

## REQ-U4-01 Migración sin pérdida

WHEN se descompone `control_lote_almacen` por la dependencia `responsable_control_id → deposito_id`, THE SYSTEM SHALL guardar el responsable en `responsable_deposito` y el lote en `asignacion_control_lote`, y la vista `vista_control_lote_almacen_fnbc` SHALL reconstruir las tres filas de la instancia (501/30/801, 502/30/801, 503/31/802) sin filas de más ni de menos.

Se prueba con el `EXCEPT` de `tp_fnbc_control_lote.sql`. Si el `EXCEPT` no es vacío, la transacción aborta.

## REQ-U4-02 Transacción reversible

WHEN la migración o la prueba de anomalías falla, THE SYSTEM SHALL dejar la instancia original intacta mediante `ROLLBACK`. Las demostraciones de inserción, borrado y actualización del esquema viejo corren cada una en su propia transacción y se revierten.

## REQ-U4-03 Plan de reversión

WHEN se retira la desnormalización del reporte diario, THE SYSTEM SHALL poder ejecutar `herramientas/revertir_desnormalizacion.sql` y volver a `detalle_pedido` sin `categoria_nombre`, sin perder cantidad ni precio. La columna es derivada: la fuente de verdad sigue siendo `categoria.nombre_categoria`.

## REQ-U4-04 Desnormalización con salvaguarda

WHEN cambia el nombre de una categoría, la categoría de un producto o el producto de un detalle, THE SYSTEM SHALL recalcular `detalle_pedido.categoria_nombre` en la misma transacción. Un valor enviado por el cliente no se conserva. La auditoría que compara la columna con la fuente SHALL devolver cero filas después de migrar.
