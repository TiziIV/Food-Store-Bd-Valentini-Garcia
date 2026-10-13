# TP U4 corregido - Food Store

Integrantes: Tiziano Valentini y Juan Martin Garcia. Base de Datos II, comisión 2PRO4, docente Sergio Neira.

## Entrega

Copiar el contenido de este paquete a `TP6_FNBC_Desnormalizacion/` en el repositorio. Los tres artefactos pedidos son `tp_fnbc_control_lote.sql`, `tp_desnormalizacion_top_categorias.sql` e `informe_fnbc_desnormalizacion.pdf`. El Markdown del informe permite editarlo. Las salidas y capturas adicionales documentan la ejecución. Actualizar el README raíz para incluir TP6 y entregar el enlace al repositorio luego de subir los archivos.

## Origen y mediciones

Esquema y carga de datos del repositorio https://github.com/TiziIV/Food-Store-Bd-Valentini-Garcia, commit `24eb62e53a1745eda763c4d9c30ee5350acfddaf`. Reconstrucción local realizada el 13/10/2026 con PostgreSQL 16.15. Datos de desarrollo generados por `data.sql`; no es un respaldo de ventas productivas. Se aplicaron las restricciones de TP2, los índices de TP3/TP4/TP5, soft delete, vistas, materializada y procedimientos de TP5, en el orden del README raíz.

Las salidas se generaron en esta sesión. Mediana de 7 corridas alternadas en el mismo estado físico: 77,258 ms antes, 65,942 ms después (14,65% menos). Los planes textuales adjuntos son corridas adicionales: 77,726 y 66,880 ms; no confundirlos con las medianas. Los 14 planes JSON conservan todas las repeticiones y sus valores atípicos. No se garantiza residencia completa en buffers: también hubo `shared read` después del calentamiento.

## Ejecutar de nuevo sobre una copia del proyecto

Con PostgreSQL 16 instalado y una base de trabajo poblada según el README raíz:

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\16\bin'
& "$pgBin\psql.exe" -X -v ON_ERROR_STOP=1 -d food_store_dev -f tp_preparar_datos_hoy.sql
& "$pgBin\pg_dump.exe" -d food_store_dev -Fc -f pre_u4.backup
& "$pgBin\psql.exe" -X -v ON_ERROR_STOP=1 -d food_store_dev -f tp_fnbc_control_lote.sql
& "$pgBin\psql.exe" -X -v ON_ERROR_STOP=1 -d food_store_dev -f tp_desnormalizacion_top_categorias.sql
& "$pgBin\psql.exe" -X -v ON_ERROR_STOP=1 -d food_store_dev -f pruebas_integridad.sql
& "$pgBin\psql.exe" -X -v ON_ERROR_STOP=1 -d food_store_dev -f medir_consultas.sql
```

Agregar `-h`, `-p` y `-U` según la conexión. La fecha y los montos cambian al regenerar datos aleatorios. No ejecutar sobre una base productiva. El preparador modifica fechas y requiere una copia de trabajo. Las pruebas de integridad terminan en ROLLBACK; las secuencias identity pueden conservar huecos.

Parte 1 corre en el esquema aislado `tp_u4_fnbc`, con maestros mínimos locales para exhibir el caso; no altera las tablas del proyecto. Se puede repetir: recrea únicamente las tres tablas de la demo y su vista. Parte 2 usa el esquema `public` real, conserva los triggers anteriores del proyecto y se puede repetir.

## Abrir la base ya ejecutada

`foodstore_u4_corregido.backup` contiene la instancia final completa. Restaurar en una base NUEVA:

```powershell
$pgBin = 'C:\Program Files\PostgreSQL\16\bin'
& "$pgBin\createdb.exe" food_store_u4_restaurado
& "$pgBin\pg_restore.exe" --exit-on-error --no-owner --no-privileges -d food_store_u4_restaurado foodstore_u4_corregido.backup
```

Los pedidos de las mediciones corresponden al 13/10/2026. Si se abre otro día y se quiere medir el reporte de hoy, ejecutar el preparador de datos de hoy. La instancia local temporal se detuvo al terminar la verificación.

## Sincronización y límites

La redundancia es `detalle_pedido.categoria_nombre`, una columna precalculada con disparadores (patrón explícito de 5.2.b). Se conserva la categoría vigente, igual que la consulta normalizada. La fecha y el subtotal no se duplican. El renombre y la reclasificación se propagan en la misma transacción.

Los triggers `a_u4_serializar` toman un bloqueo transaccional común antes de escribir Categoria, Producto o Detalle_Pedido. Evitan la carrera entre una inserción y un cambio de catálogo. Permiten SELECT, pero serializan escrituras y reducen concurrencia; es una solución conservadora para este TP. Requieren READ COMMITTED y rechazan otras modalidades. La garantía supone triggers habilitados y operaciones ordinarias sobre estas tablas; cualquier error o deadlock debe revertirse y reintentarse. No se ha medido throughput de escrituras. La auditoría debe devolver cero filas.

Para revertir el patrón ejecutar `revertir_desnormalizacion.sql`. Solo elimina los objetos y la columna derivados de U4; conserva las fuentes y los triggers de TP2/TP5. La materializada mensual de TP5 debe refrescarse si se necesita después de cambiar fechas con el preparador.

## Uso de asistencia

Corrección y generación de estos artefactos con Codex: lectura de consigna y trabajo, adaptación a la versión del repositorio, revisión de integridad, ejecución local y creación del informe. Las mediciones no se copiaron de los ejemplos del PDF. Revisar los cambios antes de subirlos al repositorio.

## Pruebas adicionales reproducibles

python verificar_concurrencia.py --db food_store_dev --user postgres reproduce las dos sesiones. python repetir_mediciones.py --db food_store_dev --user postgres guarda los 14 planes y calcula sus medianas. Ambas aceptan --host, --port y --psql. Se verificaron además restauración del respaldo, reejecución de ambos scripts y reversión: ver verificacion_reversibilidad.txt.
