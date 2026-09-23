# spec: vista_detalle_pedido_producto

Objetivo: simplificar el acceso al detalle de cada pedido junto
con el nombre del producto, evitando que cada reporte tenga que
repetir el JOIN contra Producto.

Columnas a exponer: id_pedido, id_producto, nombre_producto,
cantidad, precio_unitario, subtotal (calculado como
cantidad × precio_unitario).

Filtro de vigencia: no aplica (se listan todos los detalles,
incluso de productos que luego fueron dados de baja, para no
alterar el historial de pedidos ya facturados).

Columnas a ocultar por seguridad: ninguna (no aplica en esta
vista).

Criterio de aceptación: el resultado de la vista debe coincidir
exactamente (0 filas de diferencia con EXCEPT en ambos sentidos)
con la consulta manual equivalente.

Verificación realizada: EXCEPT en ambos sentidos, 0 filas.
Aceptada agregando el cálculo de subtotal, que no formaba parte
de la primera propuesta de OpenCode.
