# DUIA — Unidad 4

| Campo | Contenido |
| --- | --- |
| Herramienta | Kiro para la especificación y un asistente de terminal para el SQL |
| Spec | `kiro/requirements.md` y `kiro/design.md` |
| Qué se aceptó | La descomposición en `responsable_deposito` y `asignacion_control_lote`, la vista de reunión natural y la columna `categoria_nombre` con triggers |
| Qué se descartó | Copiar también la fecha del pedido o el subtotal al detalle. Era redundancia que la consigna no pedía y el filtro por día sigue siendo sargable sobre `pedido.fecha_hora` |
| Cómo se probó | `tp_fnbc_control_lote.sql` sobre `foodstore`: el `EXCEPT` no deja filas y las tres anomalías quedan revertidas. La reversión de la Parte 2 está en `herramientas/revertir_desnormalizacion.sql` |
