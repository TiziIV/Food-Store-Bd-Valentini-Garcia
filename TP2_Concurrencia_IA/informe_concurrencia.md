# Informe de Concurrencia y Manejo Transaccional (Parte 2)
**Proyecto:** Food Store  
**Entorno de prueba:** PostgreSQL — base `food_store_dev` (copia de `food_store`, según `protocolo_seguridad.md`)

---

## 1. Introducción Teórica: Niveles de Aislamiento y Fenómenos Anómalos

En motores relacionales bajo el estándar SQL-92 existen cuatro niveles de aislamiento clásicos diseñados para mitigar anomalías de concurrencia:

| Nivel de Aislamiento | Lectura Sucia (Dirty Read) | Lectura No Repetible (Non-Repeatable Read) | Lectura Fantasma (Phantom Read) | Pérdida de Actualización (Lost Update) |
| :--- | :---: | :---: | :---: | :---: |
| **Read Uncommitted** | Evitado en PG (*) | Posible | Posible | Posible |
| **Read Committed** (Default PG) | Evitado | Posible | Posible | Posible |
| **Repeatable Read** | Evitado | Evitado | Evitado en PG (**) | Evitado (Falla por serialización) |
| **Serializable** | Evitado | Evitado | Evitado | Evitado |

> **Nota técnica sobre PostgreSQL (MVCC):**
> * En PostgreSQL, `Read Uncommitted` se comporta automáticamente como `Read Committed` debido a la arquitectura MVCC (Multiversion Concurrency Control); nunca se leen datos de transacciones no confirmadas.
> * El nivel `Repeatable Read` en PostgreSQL también previene lecturas fantasma a nivel de instantánea (*snapshot isolation*).

---

## 2. Escenario 1: Pérdida de Actualización (Lost Update) sobre stock

### Descripción
Dos sesiones leen el mismo `Producto.stock`, descuentan y confirman. Sin bloqueo, la segunda sobrescribe el descuento de la primera.

### Solución aplicada
`SELECT ... FOR UPDATE` sobre la fila de `Producto` antes de actualizar. El trigger `fn_validar_stock_pedido` (en `restricciones.sql`) ya usa ese bloqueo al insertar un `Detalle_Pedido`.

### Secuencia (dos ventanas `psql`)

**Sesión A**
```sql
BEGIN;
SELECT stock FROM Producto WHERE id_producto = 1 FOR UPDATE;
UPDATE Producto SET stock = stock - 5 WHERE id_producto = 1;
-- sin COMMIT todavía
```

**Sesión B** (al mismo tiempo)
```sql
BEGIN;
SELECT stock FROM Producto WHERE id_producto = 1 FOR UPDATE;
-- queda esperando el bloqueo de A
```

**Sesión A:** `COMMIT;`

**Sesión B** continúa: lee el stock ya descontado y recién ahí actualiza. Sin `FOR UPDATE`, ambas habrían leído el mismo valor inicial.

---

## 3. Escenario 2: Lectura No Repetible

### Descripción
En `READ COMMITTED`, dos `SELECT` de la misma fila dentro de una transacción pueden ver valores distintos si otra sesión hace `COMMIT` en el medio.

### Solución aplicada
Subir a `REPEATABLE READ` (o `SERIALIZABLE`) para que la sesión conserve el snapshot de inicio.

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT precio_actual FROM Producto WHERE id_producto = 2;
-- si otra sesión confirma un UPDATE acá, esta sigue viendo el precio del snapshot
SELECT precio_actual FROM Producto WHERE id_producto = 2;
COMMIT;
```

---

## 4. Escenario 3: Prevención de Deadlocks (Interbloqueos)

### Descripción del problema
La Transacción 1 bloquea el producto A y espera el B; la Transacción 2 bloquea el B y espera el A.

### Reglas de prevención implementadas
1. **Orden determinista de acceso:** bloquear productos en orden ascendente de `id_producto`. `sp_registrar_pedido` aplica `ORDER BY (value->>'id_producto')::bigint` sobre el JSONB de ítems por ese motivo.
2. **Timeouts:** `lock_timeout` / `statement_timeout` para que una espera no quede colgada.
3. **Manejo de `40P01`:** la capa cliente captura `deadlock_detected` y reintenta la **transacción completa** (nuevo `BEGIN`), no un bloque interno.

---

## 5. Conclusiones
* `READ COMMITTED` alcanza para operaciones de bajo conflicto, pero el inventario necesita `FOR UPDATE` (o el trigger de stock que ya lo usa).
* `REPEATABLE READ` sirve para reportes que no deben ver cambios ajenos a mitad de camino.
* Un reintento ante `40001` / `40P01` **no** puede hacerse con `EXCEPTION` dentro del mismo `BEGIN`: el snapshot no cambia. Hay que abortar y abrir una transacción nueva desde el cliente.

---

## 6. Evidencia en `psql`

Los comandos de esta sección se corren sobre `food_store_dev` con
`restricciones.sql`, `soft_delete.sql` y `procedimientos.sql` ya
aplicados. Las salidas entre bloques ` ```text ` son las del motor
(mensajes fijos de PostgreSQL / del trigger).

### 6.1 Atomicidad con `sp_registrar_pedido`

Un pedido con un ítem válido y otro sin stock no debe dejar ni el
pedido ni el detalle, y el stock del ítem válido no debe quedar
descontado tras el fallo.

```sql
SELECT id_producto, stock AS stock_antes
FROM Producto WHERE id_producto = 1;

BEGIN;
CALL sp_registrar_pedido(
    1500,
    'EFECTIVO',
    '[
       {"id_producto": 1, "cantidad": 2},
       {"id_producto": 1, "cantidad": 999999}
     ]'::jsonb
);
```

El motor responde con el mensaje del trigger (texto fijo de nuestra
`RAISE EXCEPTION`; el número de “Disponible” es el stock tras el
primer ítem de esa misma llamada, antes del fallo):

```text
ERROR:  Stock insuficiente para el producto ID 1: Disponible <n>, Solicitado 999999
CONTEXT:  PL/pgSQL function fn_validar_stock_pedido() ...
```

La excepción aborta todo el `CALL`. Sin hacer `COMMIT` de un pedido
parcial (no hay nada que confirmar: el procedimiento falló):

```sql
-- Misma sesión, tras el ERROR (la transacción del CALL ya abortó;
-- si el BEGIN exterior sigue abierto, hacer ROLLBACK).
ROLLBACK;

SELECT count(*) AS pedidos_recien
FROM Pedido
WHERE id_cliente = 1500
  AND fecha_hora >= now() - interval '1 minute';

SELECT stock AS stock_despues FROM Producto WHERE id_producto = 1;
```

`pedidos_recien` debe ser `0` y `stock_despues` igual a `stock_antes`.
Pegar acá debajo la salida real de esas dos consultas al reproducir
en `food_store_dev`:

```text
(pegar salida de psql)
```

### 6.2 Pérdida de actualización evitada (`FOR UPDATE`)

Misma secuencia de la sección 2. Tras el `COMMIT` de A, B no lee el
stock original: lee el valor ya descontado. El trigger de stock usa
el mismo `FOR UPDATE`, así que el error ante falta de unidades es
`Stock insuficiente`, no el `CHECK stock >= 0`.

### 6.3 `SERIALIZABLE` y reintento ante `40001`

**Mal (no usar):** un `DO $$ ... EXCEPTION WHEN serialization_failure`
que reintenta el `UPDATE` **dentro de la misma transacción**. El
snapshot no cambia: el `UPDATE` vuelve a fallar las N veces.

**Bien:** el cliente aborta y abre un `BEGIN` nuevo.

Sesión A y sesión B:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
UPDATE Producto SET stock = stock - 1 WHERE id_producto = 1 AND stock >= 1;
COMMIT;
```

La que llega segunda al `COMMIT` recibe:

```text
ERROR:  could not serialize access due to concurrent update
SQLSTATE: 40001
```

Reintento desde el cliente (nueva transacción; pseudocódigo / `psql`
en bucle, no un `DO` interno):

```text
intento = 0
mientras intento < 3:
    intento++
    BEGIN ISOLATION LEVEL SERIALIZABLE;
    UPDATE Producto SET stock = stock - 1
      WHERE id_producto = 1 AND stock >= 1;
    COMMIT;          -- si OK, salir
    -- si SQLSTATE = 40001: la transacción ya quedó abortada;
    --                      volver al while con un BEGIN nuevo
    -- si otro error: propagar
```

En una aplicación real eso vive en el pool / driver (capturar
`40001` o `40P01`, `ROLLBACK` implícito y repetir el unit of work).

### 6.4 Interbloqueo (`40P01`)

Sin orden fijo: A bloquea producto 1 y pide 2; B bloquea 2 y pide 1.

```text
ERROR:  deadlock detected
SQLSTATE: 40P01
DETAIL:  Process ... waits for ShareLock on transaction ...; blocked by process ...
```

`sp_registrar_pedido` evita ese cruce ordenando los ítems por
`id_producto` antes de insertar.
