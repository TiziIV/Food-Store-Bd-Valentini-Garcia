import argparse,subprocess,os,json,statistics,pathlib
p=argparse.ArgumentParser()
p.add_argument('--psql',default=r'C:/Program Files/PostgreSQL/16/bin/psql.exe')
p.add_argument('--db',required=True)
p.add_argument('--host',default='127.0.0.1')
p.add_argument('--port',default='5432')
p.add_argument('--user',default='postgres')
p.add_argument('--output',default='mediciones_nuevas.json')
args=p.parse_args()
env=dict(os.environ,PGCLIENTENCODING='UTF8',PGTZ='America/Argentina/Buenos_Aires')
def sql(q):
 r=subprocess.run([args.psql,'-h',args.host,'-p',args.port,'-U',args.user,'-d',args.db,'-X','-Atq','-v','ON_ERROR_STOP=1','-c',q],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 if r.returncode: raise RuntimeError(r.stderr.decode('utf8','replace'))
 return r.stdout.decode('utf8')
before='''SELECT c.nombre_categoria AS categoria,SUM(dp.cantidad*dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp JOIN producto pr USING(id_producto) JOIN categoria c USING(id_categoria)
JOIN pedido ped USING(id_pedido) WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
AND NOT dp.eliminado AND NOT ped.eliminado GROUP BY c.nombre_categoria ORDER BY total_vendido DESC LIMIT 5'''
after='''SELECT dp.categoria_nombre AS categoria,SUM(dp.cantidad*dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp JOIN pedido ped USING(id_pedido)
WHERE ped.fecha_hora>=CURRENT_DATE AND ped.fecha_hora<CURRENT_DATE+1
AND NOT dp.eliminado AND NOT ped.eliminado GROUP BY dp.categoria_nombre ORDER BY total_vendido DESC LIMIT 5'''
plans={'antes':[],'despues':[]}
# Calentamiento para las dos consultas.
for q in [before,after]: sql('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+q)
for i in range(7):
 for label,q in ([('antes',before),('despues',after)] if i%2==0 else [('despues',after),('antes',before)]):
  plan=json.loads(sql('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+q))[0]
  plans[label].append(plan)
times={k:[p['Execution Time'] for p in v] for k,v in plans.items()}
med={k:statistics.median(v) for k,v in times.items()}
result={'planes':plans,'tiempos_ms':times,'medianas_ms':med,'reduccion_porcentual':(1-med['despues']/med['antes'])*100}
pathlib.Path(args.output).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'medianas_ms':med,'reduccion_porcentual':result['reduccion_porcentual']},indent=2))
