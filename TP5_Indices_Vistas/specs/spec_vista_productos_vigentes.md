# spec: vista_productos_vigentes

Objetivo: simplificar el acceso a los productos activos junto con
el nombre de su categoría, para uso del catálogo y de reportes.

Columnas a exponer: id_producto, nombre_producto, precio_actual,
id_categoria, nombre_categoria.

Filtro de vigencia: activo = TRUE (los productos dados de baja no
deben aparecer en esta vista).

Columnas a ocultar por seguridad: ninguna (no aplica en esta
vista).

Criterio de aceptación: el resultado de la vista debe coincidir
exactamente (0 filas de diferencia con EXCEPT en ambos sentidos)
con la consulta manual equivalente que hace el JOIN entre
Producto y Categoria filtrando por activo = TRUE.

Verificación realizada: EXCEPT en ambos sentidos, 0 filas.
Aceptada sin modificaciones.
