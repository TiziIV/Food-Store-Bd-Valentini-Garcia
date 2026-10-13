"""Prueba reproducible: ejecutar sobre una COPIA de Food Store con U4 instalado.
Ejemplo: python verificar_concurrencia.py --db food_store_dev --user postgres
Usa psql; las credenciales se resuelven con .pgpass / PGPASSWORD del entorno.
"""
import argparse,subprocess,os,time,pathlib

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--psql',default=r'C:\Program Files\PostgreSQL\16\bin\psql.exe')
 parser.add_argument('--host',default='127.0.0.1');parser.add_argument('--port',default='5432')
 parser.add_argument('--user',default='postgres');parser.add_argument('--db',required=True)
 args=parser.parse_args()
 base=[args.psql,'-h',args.host,'-p',args.port,'-U',args.user,'-d',args.db,'-X','-Atq','-v','ON_ERROR_STOP=1']
 env=dict(os.environ,PGCLIENTENCODING='UTF8',PGTZ='America/Argentina/Buenos_Aires')
 def sql(text):
  result=subprocess.run(base+['-c',text],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  if result.returncode: raise RuntimeError(result.stderr.decode('utf8','replace'))
  return result.stdout.decode('utf8','replace').strip()
 cat=prod=ped=None; session=None
 try:
  cat=int(sql("INSERT INTO categoria(nombre_categoria) VALUES('U4 Concurrente antes') RETURNING id_categoria"))
  prod=int(sql(f"INSERT INTO producto(nombre_producto,precio_actual,stock,id_categoria) VALUES('U4 Concurrente',100,10,{cat}) RETURNING id_producto"))
  ped=int(sql("INSERT INTO pedido(forma_pago,id_cliente) SELECT 'EFECTIVO',MIN(id_cliente) FROM cliente RETURNING id_pedido"))
  session=subprocess.Popen(base+['-c',f"SET application_name='u4_concurrencia_A'; BEGIN; UPDATE categoria SET nombre_categoria='U4 Concurrente despues' WHERE id_categoria={cat}; SELECT pg_sleep(4); COMMIT;"],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  ready=False
  for _ in range(60):
   if sql("SELECT EXISTS(SELECT 1 FROM pg_locks l JOIN pg_stat_activity a USING(pid) WHERE a.application_name='u4_concurrencia_A' AND l.relation='tp_u4_mutex_categoria'::regclass AND l.granted AND l.mode='ShareRowExclusiveLock')")=='t': ready=True;break
   time.sleep(.05)
  if not ready: raise RuntimeError('La sesion A no obtuvo el bloqueo esperado')
  start=time.perf_counter()
  nombre=sql(f"INSERT INTO detalle_pedido(id_pedido,id_producto,cantidad,precio_unitario,categoria_nombre) VALUES({ped},{prod},1,100,'FALSO') RETURNING categoria_nombre")
  elapsed=time.perf_counter()-start
  _,err=session.communicate(timeout=30)
  if session.returncode: raise RuntimeError(err.decode('utf8','replace'))
  if nombre!='U4 Concurrente despues': raise RuntimeError('Nombre derivado incorrecto: '+nombre)
  count=sql("SELECT COUNT(*) FROM detalle_pedido dp JOIN producto pr USING(id_producto) JOIN categoria c USING(id_categoria) WHERE dp.categoria_nombre IS DISTINCT FROM c.nombre_categoria")
  if count!='0': raise RuntimeError('Auditoria con diferencias: '+count)
  print(f'OK: B espero {elapsed:.3f} s; nombre={nombre}; auditoria={count}')
 finally:
  if session is not None and session.poll() is None: session.communicate(timeout=30)
  if ped is not None: sql(f'DELETE FROM pedido WHERE id_pedido={ped}')
  if prod is not None: sql(f'DELETE FROM producto WHERE id_producto={prod}')
  if cat is not None: sql(f'DELETE FROM categoria WHERE id_categoria={cat}')

if __name__=='__main__':main()
