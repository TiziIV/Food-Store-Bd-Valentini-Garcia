\set ON_ERROR_STOP on
BEGIN;
LOCK TABLE categoria,producto,detalle_pedido IN SHARE ROW EXCLUSIVE MODE;
DROP TRIGGER IF EXISTS a_u4_serializar ON categoria;
DROP TRIGGER IF EXISTS a_u4_serializar ON producto;
DROP TRIGGER IF EXISTS a_u4_serializar ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_dp_sync_categoria_nombre ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_categoria_propagar_nombre ON categoria;
DROP TRIGGER IF EXISTS trg_producto_propagar_categoria ON producto;
DROP FUNCTION IF EXISTS fn_u4_bloquear_categoria();
DROP FUNCTION IF EXISTS fn_dp_sync_categoria_nombre();
DROP FUNCTION IF EXISTS fn_categoria_propagar_nombre();
DROP FUNCTION IF EXISTS fn_producto_propagar_categoria();
ALTER TABLE detalle_pedido DROP COLUMN IF EXISTS categoria_nombre;
DROP TABLE IF EXISTS tp_u4_mutex_categoria;
COMMIT;
