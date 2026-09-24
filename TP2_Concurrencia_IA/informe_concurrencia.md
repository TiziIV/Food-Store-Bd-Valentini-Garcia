# Informe de Concurrencia y Manejo Transaccional (Parte 2)
**Proyecto:** FoodStore  
**Entorno de prueba:** PostgreSQL - Base de datos `foodstore_dev_concurrencia`

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

## 2. Escenario 1: Pérdida de Actualización (Lost Update) en Stock

### Descripción del problema
Dos clientes compran concurrentemente unidades del mismo producto (ej. Producto ID = 1 con `stock = 10`). Ambas transacciones leen el stock al mismo tiempo, calculan el descuento en memoria y ejecutan un `UPDATE`, provocando que la última transacción pise el cambio de la primera sin descontar ambas cantidades.

### Simulación paso a paso:
1. **Paso 1 (T1):** Inicia transacción y consulta stock.
   ```sql
   BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
   SELECT stock FROM Producto WHERE id_producto = 1; -- Retorna 10
   ```
2. **Paso 2 (T2):** Inicia en paralelo y consulta el mismo stock.
   ```sql
   BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
   SELECT stock FROM Producto WHERE id_producto = 1; -- Retorna 10
   ```
3. **Paso 3 (T1):** Descuenta 2 unidades y actualiza.
   ```sql
   UPDATE Producto SET stock = 10 - 2 WHERE id_producto = 1; -- stock local = 8
   COMMIT;
   ```
4. **Paso 4 (T2):** Descuenta 3 unidades calculando sobre su lectura original (10) y sobreescribe.
   ```sql
   UPDATE Producto SET stock = 10 - 3 WHERE id_producto = 1; -- stock final = 7 (debería ser 5)
   COMMIT;
   ```

### Solución aplicada (Bloqueo Pesimista / For Update):
Para evitar el Lost Update sin elevar el aislamiento global se utiliza la cláusula `FOR UPDATE`, que bloquea las filas seleccionadas hasta el fin de la transacción:

```sql
BEGIN;
SELECT stock FROM Producto WHERE id_producto = 1 FOR UPDATE;
-- Cualquier otra transacción que intente leer con FOR UPDATE o modificar esta fila quedará en espera.
UPDATE Producto SET stock = stock - 2 WHERE id_producto = 1;
COMMIT;
```

---

## 3. Escenario 2: Lectura No Repetible (Non-Repeatable Read)

### Descripción del problema
Una transacción de auditoría o facturación consulta los totales de venta de un pedido dos veces dentro de su bloque. Una transacción concurrente modifica el precio de un ítem en el medio, arrojando valores discrepantes en la misma sesión.

### Simulación paso a paso:
1. **Sesión 1 (Lectura inicial):**
   ```sql
   BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
   SELECT precio_actual FROM Producto WHERE id_producto = 2; -- Valor: $1500.00
   ```
2. **Sesión 2 (Modificación concurrente):**
   ```sql
   BEGIN;
   UPDATE Producto SET precio_actual = 1800.00 WHERE id_producto = 2;
   COMMIT;
   ```
3. **Sesión 1 (Segunda lectura dentro de la misma transacción):**
   ```sql
   SELECT precio_actual FROM Producto WHERE id_producto = 2; -- Valor: $1800.00 (Inconsistente con la primera lectura)
   COMMIT;
   ```

### Solución aplicada:
Configurar el nivel de aislamiento en `REPEATABLE READ`:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT precio_actual FROM Producto WHERE id_producto = 2; -- Toma snapshot de inicio
-- Si Sesión 2 hace commit de un UPDATE aquí, Sesión 1 sigue leyendo $1500.00
SELECT precio_actual FROM Producto WHERE id_producto = 2; -- Sigue siendo $1500.00
COMMIT;
```

---

## 4. Escenario 3: Prevención de Deadlocks (Interbloqueos)

### Descripción del problema
Ocurre cuando la Transacción 1 bloquea el Recurso A y espera el Recurso B, mientras la Transacción 2 bloquea el Recurso B y espera el Recurso A.

### Reglas de prevención implementadas:
1. **Orden determinista de acceso:** Siempre bloquear o actualizar tablas y registros en un orden prefijado (por ejemplo, orden ascendente de `id_producto`).
2. **Uso de timeouts:** configurar `lock_timeout` o `statement_timeout` para que una espera de bloqueo no quede colgada.
3. **Manejo de excepciones:** Diseñar la capa de persistencia para capturar el código de error `40P01` (deadlock_detected) y reintentar la transacción con backoff exponencial.

---

## 5. Conclusiones
* `READ COMMITTED` es adecuado para operaciones estándar de bajo conflicto, pero crítico en operaciones de inventario si no se refuerza con bloqueos explícitos (`FOR UPDATE`).
* `REPEATABLE READ` garantiza consistencia total para reportes financieros y auditorías sin generar bloqueos destructivos gracias al MVCC de PostgreSQL.

---

## 6. Evidencia: atomicidad, dos sesiones y reintento 40001

Los tiempos de las secciones anteriores no se reimprimen acá. Lo que
sigue es el guion que se corre en `psql` y el mensaje que devuelve
el motor. El trigger de stock (`fn_validar_stock_pedido`) lee la
fila de `Producto` con `FOR UPDATE`: la segunda venta espera y, si
no alcanza, falla con `Stock insuficiente`, no con el `CHECK`
`stock >= 0`.

### Atomicidad con ROLLBACK

```sql
BEGIN;
INSERT INTO Cliente (nombre, correo)
VALUES ('Prueba rollback', 'rollback-atomicidad@foodstore.test');
ROLLBACK;

SELECT count(*) AS filas
FROM Cliente
WHERE correo = 'rollback-atomicidad@foodstore.test';
```

Salida del `SELECT`: `filas = 0`. El `INSERT` no quedó.

### Pérdida de actualización (dos sesiones, READ COMMITTED)

Sesión A:

```sql
BEGIN;
SELECT stock FROM Producto WHERE id_producto = 1 FOR UPDATE;
-- anotar el stock, por ejemplo 40
UPDATE Producto SET stock = stock - 5 WHERE id_producto = 1;
-- no hacer COMMIT todavía
```

Sesión B, al mismo tiempo:

```sql
BEGIN;
SELECT stock FROM Producto WHERE id_producto = 1 FOR UPDATE;
-- queda esperando el bloqueo de A
```

Sesión A: `COMMIT;`

Sesión B continúa, lee el stock ya descontado (35, no 40) y recién
ahí descuenta. Sin `FOR UPDATE` las dos habrían leído 40.

### SERIALIZABLE y reintento ante 40001

Sesión A y sesión B, las dos en `SERIALIZABLE`, actualizan la misma
fila de `Producto` y hacen `COMMIT`. La que llega segunda recibe:

```text
ERROR:  could not serialize access due to concurrent update
SQLSTATE: 40001
```

El reintento captura ese estado y vuelve a correr la transacción:

```sql
DO $$
DECLARE
    v_intentos INT := 0;
BEGIN
    LOOP
        v_intentos := v_intentos + 1;
        BEGIN
            UPDATE Producto
            SET stock = stock - 1
            WHERE id_producto = 1 AND stock >= 1;
            EXIT;
        EXCEPTION
            WHEN serialization_failure THEN  -- SQLSTATE 40001
                IF v_intentos >= 3 THEN
                    RAISE;
                END IF;
        END;
    END LOOP;
END $$;
```

Ese bloque va dentro de `BEGIN ISOLATION LEVEL SERIALIZABLE`
en cada sesión. Si las dos commitean a la vez, una termina y la
otra entra al `EXCEPTION` y reintenta.

### Interbloqueo (40P01)

Sesión A bloquea el producto 1 y después pide el 2. Sesión B bloquea
el 2 y después pide el 1. Una de las dos recibe:

```text
ERROR:  deadlock detected
SQLSTATE: 40P01
```

El orden fijo por `id_producto` ascendente evita ese cruce.