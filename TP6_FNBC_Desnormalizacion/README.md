# TP U4 - FNBC y desnormalización: Food Store

## Archivos de entrega

- `tp_fnbc_control_lote.sql`: esquema, descomposición, migración y verificaciones de Parte 1.
- `tp_desnormalizacion_top_categorias.sql`: implementación, consultas, auditoría y pruebas de Parte 2.
- `informe_fnbc_desnormalizacion.pdf`: análisis y evidencia de ejecución, incluidos ambos planes completos.

Este README contiene únicamente instrucciones de ejecución. La teoría, las mediciones y las capturas se incluyen en el PDF. Las herramientas y salidas auxiliares se conservaron como respaldo local.

## Ejecutar

PostgreSQL 16 y `psql`. Primero preparar una copia poblada siguiendo el README raíz del proyecto, incluyendo `soft_delete.sql`. La Parte 1 usa el esquema aislado `tp_u4_fnbc`; la Parte 2 usa las tablas del proyecto en `public`.

```bash
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_fnbc_control_lote.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_desnormalizacion_top_categorias.sql
```

Agregar host, puerto y usuario según la conexión. Ejecutar sobre una copia de trabajo y generar un respaldo previo. Ambos scripts contienen sus verificaciones; el de Parte 2 incluye el bloque de reversión comentado al final. Las pruebas con ROLLBACK pueden dejar huecos en las secuencias identity.

Si la copia no tiene ventas suficientes en el día actual, se puede aplicar la misma preparación de la instancia medida: reasignar uno de cada veinte pedidos a hoy, exclusivamente en la copia de trabajo.

```sql
BEGIN;
SET LOCAL TIME ZONE 'America/Argentina/Buenos_Aires';
UPDATE pedido
SET fecha_hora = date_trunc('day',now())
               + random() * (now() - date_trunc('day',now()))
WHERE id_pedido % 20 = 0;
ANALYZE pedido;
COMMIT;
```

Si se utiliza la materializada mensual de TP5, refrescarla después de cambiar las fechas. Las mediciones del PDF corresponden al 13/10/2026; nuevas ejecuciones pueden dar otros tiempos y montos.

## Entregar

Entregar el enlace al repositorio con los dos SQL y el PDF de esta carpeta.
