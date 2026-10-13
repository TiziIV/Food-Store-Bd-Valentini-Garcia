# Correcciones del trabajo

El PDF enviado y el repositorio contienen versiones diferentes. El PDF propone una tabla de agregados y deja espacios sin completar; el repositorio tiene una implementación posterior de columna precalculada. Esta entrega corregida toma como base la versión del repositorio y adopta el patrón que pide expresamente 5.2.b.

- Se conserva la teoría correcta de FNBC: dos claves candidatas, todos los atributos primos, cumplimiento de 3FN pero violación de FNBC y descomposición sin pérdida.
- Se aísla la demo de Parte 1 para no borrar tablas maestras reales. La verificación usa EXCEPT en ambos sentidos y cuenta 3 filas reconstruidas.
- La DF no preservada se controla tanto al modificar asignaciones como al cambiar el depósito de un responsable. Las pruebas rechazan solo el error esperado (`check_violation`); no ocultan cualquier excepción como si fuera éxito.
- Se usan las columnas reales del proyecto: `fecha_hora`, `id_pedido`, `id_producto`, `id_categoria`, `nombre_categoria` y `cantidad*precio_unitario`. El día se interpreta en Buenos Aires.
- Se mantiene la columna precalculada del repositorio, con propagación en ambas direcciones de cambio de catálogo. La instalación bloquea las fuentes y es atómica.
- Se agrega serialización conservadora de escrituras fuente para cubrir inserciones y renombres/reclasificaciones concurrentes. Se explicita su costo y su alcance READ COMMITTED.
- Se reemplazan los tiempos antiguos por corridas nuevas. No se atribuye a un scan el tiempo acumulado de todos sus nodos padres ni se suman tiempos de workers como tiempo total.
- La tabla compara planes reales y tiempos medidos. Se conserva la dispersión de las 7 repeticiones por consulta, incluso los valores atípicos.
- La equivalencia se comprueba automáticamente sobre TODOS los grupos del día, con EXCEPT ALL en ambos sentidos. No depende solo de mirar el top 5.
- Se agregan pruebas reversibles de bajas lógicas, cambio de día, categoría, producto, nombre repetido y borrado en cascada, más una prueba de dos transacciones concurrentes.
- Se entrega un PDF sin casilleros, un editable Markdown, scripts separados, capturas legibles, salidas originales y respaldo de la base ejecutada.

No se subieron archivos ni se hicieron commits en GitHub. El paquete está listo para copiar a la carpeta TP6 del repositorio y revisar.
