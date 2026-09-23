# spec: idx_pedido_forma_pago (DESCARTADO)

Objetivo original: evaluar si conviene indexar Pedido por
forma_pago para reportes de medios de pago.

Propuesta de OpenCode:
```sql
CREATE INDEX idx_pedido_forma_pago ON Pedido (forma_pago);
```

Motivo del descarte (sobreindexación):
- Baja cardinalidad: forma_pago_enum tiene solo 4 valores
  posibles (EFECTIVO, TARJETA, TRANSFERENCIA,
  BILLETERA_DIGITAL), ~25% de la tabla cada uno.
- El planificador de PostgreSQL descarta sistemáticamente este
  tipo de índice y usa Seq Scan, porque saltar aleatoriamente
  del índice al heap es más costoso que leer las páginas en
  bloque.
- Mantenerlo penalizaría los INSERT de Pedido y ocuparía memoria
  del buffer pool sin ningún beneficio real de lectura.

Decisión: NO se crea. Documentado como ejemplo de propuesta de
IA rechazada por el equipo, conforme a la consigna 4.1.6 del TP.
