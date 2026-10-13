\set ON_ERROR_STOP on
SET TIME ZONE 'America/Argentina/Buenos_Aires';
SET search_path=public;
BEGIN;
CREATE FUNCTION pg_temp.verificar_u4(etapa TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE n BIGINT;
BEGIN
 SELECT COUNT(*) INTO n FROM detalle_pedido dp JOIN producto pr USING(id_producto)
 JOIN categoria c USING(id_categoria) WHERE dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria;
 IF n<>0 THEN RAISE EXCEPTION 'Desincronizacion en %: %',etapa,n; END IF;
 WITH normal AS (
  SELECT c.nombre_categoria categoria,SUM(dp.cantidad*dp.precio_unitario) total
  FROM detalle_pedido dp JOIN producto pr USING(id_producto) JOIN categoria c USING(id_categoria)
  JOIN pedido ped USING(id_pedido) WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
  AND NOT dp.eliminado AND NOT ped.eliminado GROUP BY c.nombre_categoria
 ), red AS (
  SELECT dp.categoria_nombre categoria,SUM(dp.cantidad*dp.precio_unitario) total
  FROM detalle_pedido dp JOIN pedido ped USING(id_pedido)
  WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
  AND NOT dp.eliminado AND NOT ped.eliminado GROUP BY dp.categoria_nombre
 ), dif AS ((TABLE normal EXCEPT ALL TABLE red) UNION ALL (TABLE red EXCEPT ALL TABLE normal))
 SELECT COUNT(*) INTO n FROM dif;
 IF n<>0 THEN RAISE EXCEPTION 'Reporte no equivalente en %: %',etapa,n; END IF;
 RAISE NOTICE 'OK: %, auditoria=0 y diferencias=0',etapa;
END $$;
DO $$
DECLARE c1 BIGINT; c2 BIGINT; p1 BIGINT; p2 BIGINT; ped BIGINT;
BEGIN
 INSERT INTO categoria(nombre_categoria) VALUES('U4 Prueba A') RETURNING id_categoria INTO c1;
 INSERT INTO categoria(nombre_categoria) VALUES('U4 Prueba B') RETURNING id_categoria INTO c2;
 INSERT INTO producto(nombre_producto,precio_actual,stock,id_categoria)
 VALUES('U4 Prueba producto A',100,100,c1) RETURNING id_producto INTO p1;
 INSERT INTO producto(nombre_producto,precio_actual,stock,id_categoria)
 VALUES('U4 Prueba producto B',100,100,c2) RETURNING id_producto INTO p2;
 INSERT INTO pedido(fecha_hora,forma_pago,id_cliente)
 SELECT CURRENT_DATE+interval '12 hours','EFECTIVO',min(id_cliente) FROM cliente
 RETURNING id_pedido INTO ped;
 INSERT INTO detalle_pedido(id_pedido,id_producto,cantidad,precio_unitario,categoria_nombre)
 VALUES(ped,p1,1,100,'NOMBRE FALSO');
 PERFORM pg_temp.verificar_u4('INSERT y correccion de valor falso');
 UPDATE detalle_pedido SET categoria_nombre='OTRO FALSO' WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('UPDATE directo de columna redundante');
 UPDATE detalle_pedido SET id_producto=p2 WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('cambio de producto del detalle');
 UPDATE producto SET id_categoria=c1 WHERE id_producto=p2;
 PERFORM pg_temp.verificar_u4('reclasificacion de producto');
 UPDATE categoria SET nombre_categoria='U4 Prueba B' WHERE id_categoria=c1;
 PERFORM pg_temp.verificar_u4('renombre y nombres de categorias repetidos');
 UPDATE detalle_pedido SET eliminado=TRUE WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('baja logica de detalle');
 UPDATE detalle_pedido SET eliminado=FALSE WHERE id_pedido=ped;
 UPDATE pedido SET eliminado=TRUE WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('baja logica de pedido');
 UPDATE pedido SET eliminado=FALSE,fecha_hora=CURRENT_DATE-interval '1 day' WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('cambio de dia de pedido');
 DELETE FROM pedido WHERE id_pedido=ped;
 PERFORM pg_temp.verificar_u4('DELETE de pedido con cascada de detalles');
END $$;
ROLLBACK;
-- No quedan filas de prueba. Las secuencias identity pueden tener huecos.
