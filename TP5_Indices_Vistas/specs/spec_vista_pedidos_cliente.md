# spec: vista_pedidos_cliente

Objetivo: simplificar y proteger el acceso a los pedidos junto
con los datos del cliente que los realizó, para reportes que no
deben tener acceso a datos de contacto sensibles.

Columnas a exponer: id_pedido, fecha_hora, forma_pago,
id_cliente, nombre_cliente, correo.

Filtro de vigencia: no aplica (se listan todos los pedidos).

Columnas a ocultar por seguridad: telefono (columna de Cliente).
Nota de diseño: Food Store nunca modeló autenticación de
clientes (no existe columna de contraseña en el esquema desde
TP1), por lo que el dato de contacto más sensible a proteger en
un reporte compartido es el teléfono, no una credencial. Este es
el criterio de seguridad exigido por la consigna 4.2.4: la vista
debe permitir otorgar SELECT sin exponer un dato de contacto
directo del cliente.

Criterio de aceptación: el resultado de la vista debe coincidir
exactamente (0 filas de diferencia con EXCEPT en ambos sentidos)
con la consulta manual equivalente, y no debe incluir en ningún
caso la columna telefono.

Verificación realizada: EXCEPT en ambos sentidos, 0 filas.
Se confirmó además que \d vista_pedidos_cliente no lista la
columna telefono. Aceptada con este ajuste de nombres (Cliente
en vez de Usuario) para que coincida con el esquema real del
proyecto definido en TP1.
