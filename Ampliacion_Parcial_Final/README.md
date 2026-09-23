# Ampliación — cierre de los puntos 6 y 9 del parcial final

Esta carpeta no corresponde a un TP histórico de la cátedra: es la
ampliación puntual que cierra los dos objetivos del checklist de la
entrega parcial que quedaban parciales después de dividir el
repositorio (ver [`../Informe_General.md`](../Informe_General.md),
sección 6).

| Archivo | Objetivo que cubre | Depende de |
|---|---|---|
| [`soft_delete.sql`](soft_delete.sql) | Punto 9 — borrado lógico en `Cliente`, `Pedido` y `Detalle_Pedido`, con índices parciales y ejemplos de impacto en consultas | `TP1_FoodStore/schema.sql` |
| [`procedimientos.sql`](procedimientos.sql) | Punto 6 — dos procedimientos PL/pgSQL invocados con `CALL` | `soft_delete.sql` (usa `Cliente.eliminado`) y el trigger `fn_validar_stock_pedido` de `TP2_Concurrencia_IA/restricciones.sql` |

## Por qué no se modificó TP1_FoodStore/schema.sql directamente

`schema.sql` es el DDL tal como se entregó y se corrigió en el TP1.
Reescribirlo hubiera significado alterar un entregable ya evaluado.
En cambio, esta ampliación sigue el patrón real de evolución de un
esquema en producción: migraciones incrementales (`ALTER TABLE`)
que se aplican en orden, después del esquema base.

## Orden de aplicación

```bash
psql -d food_store -f TP1_FoodStore/schema.sql
psql -d food_store -f TP2_Concurrencia_IA/restricciones.sql
psql -d food_store -f TP5_Indices_Vistas/data.sql
psql -d food_store -f Ampliacion_Parcial_Final/soft_delete.sql
psql -d food_store -f Ampliacion_Parcial_Final/procedimientos.sql
```

## Cómo verificar (protocolo de seguridad de la cátedra)

Como con cualquier script generado o revisado con IA a lo largo del
proyecto, esta ampliación se prueba sobre una copia de trabajo y
dentro de una transacción reversible antes de aceptarla, siguiendo
[`../protocolo_seguridad.md`](../protocolo_seguridad.md):

```sql
BEGIN;
\i soft_delete.sql
\i procedimientos.sql

CALL sp_registrar_pedido(1500, 'EFECTIVO',
    '[{"id_producto": 1, "cantidad": 2}]'::jsonb);
CALL sp_dar_baja_cliente(1500);
SELECT id_cliente, eliminado FROM Cliente WHERE id_cliente = 1500;

-- Verifica que el índice parcial se use en el plan:
EXPLAIN ANALYZE
SELECT id_pedido, fecha_hora FROM Pedido
WHERE id_cliente = 1500 AND eliminado = FALSE
ORDER BY fecha_hora DESC;

ROLLBACK;
```

Resultado esperado: `sp_registrar_pedido` devuelve el `id_pedido`
generado y descuenta stock vía el trigger de TP2; `sp_dar_baja_cliente`
deja `eliminado = TRUE` en el cliente 1500; el `EXPLAIN ANALYZE` usa
`idx_pedido_vigente_cliente_fecha`.
