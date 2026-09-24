# TP1 — Modelo ER, derivación relacional y normalización

Trabajo Práctico N.º 1 — Base de Datos I — Proyecto integrador Food Store

Este documento reúne las Partes 1, 2 y 3 del TP1 (diccionario de
entidades, derivación al modelo relacional y normalización hasta
BCNF). La Parte 4 (DDL) es [`schema.sql`](schema.sql).

[`diagrama-er.png`](diagrama-er.png) es el diagrama físico de
dbdiagram (notación pata de gallo): muestra las tablas ya
resueltas y la cardinalidad. La participación (total o parcial) y
la relación N:M Pedido–Producto **antes** de crear Detalle_Pedido
están en el texto de esta Parte 1, no en el png.

## Parte 1 — Modelo entidad-relación

### Diccionario de entidades y atributos

| Entidad | Atributo | Tipo | Descripción / Restricción |
|---|---|---|---|
| Cliente | id_cliente | Numérico | Clave primaria autogenerada. |
| Cliente | nombre | Texto | Nombre completo del cliente. |
| Cliente | correo | Texto | Clave candidata. Identificador único del cliente (Regla R6). |
| Cliente | telefono | Texto | Teléfono de contacto opcional. |
| Categoría | id_categoria | Numérico | Clave primaria autogenerada. |
| Categoría | nombre_categoria | Texto | Nombre de la categoría (ej. Pizzas, Bebidas). |
| Categoría | descripcion | Texto | Descripción opcional de la categoría. |
| Producto | id_producto | Numérico | Clave primaria autogenerada. |
| Producto | nombre_producto | Texto | Nombre del producto. |
| Producto | precio_actual | Numérico | Precio de lista vigente del producto. |
| Producto | stock | Numérico (entero) | Cantidad disponible en stock (no negativo — R5). |
| Producto | activo | Booleano | Disponibilidad de catálogo: TRUE = se puede vender. No es el borrado lógico. |
| Producto | id_categoria | Numérico | Clave foránea que referencia a la categoría. |
| Pedido | id_pedido | Numérico | Clave primaria autogenerada. |
| Pedido | fecha_hora | Fecha/Hora | Momento exacto en que se realizó el pedido. |
| Pedido | forma_pago | Texto | Método de pago utilizado (ej. Efectivo, Tarjeta). |
| Pedido | id_cliente | Numérico | Clave foránea que referencia al cliente que hizo el pedido. |
| Detalle_Pedido | id_pedido | Numérico | Clave foránea / parte de la PK compuesta. |
| Detalle_Pedido | id_producto | Numérico | Clave foránea / parte de la PK compuesta. |
| Detalle_Pedido | cantidad | Numérico (entero) | Unidades pedidas de ese producto en particular. |
| Detalle_Pedido | precio_unitario | Numérico | Precio histórico congelado al momento de la venta (Regla R4). |

### Relaciones, cardinalidades y participaciones

- **Categoría → Producto (1:N):** una categoría tiene muchos productos, o
  ninguno todavía (participación parcial de Categoría). Un producto
  pertenece exactamente a una categoría (participación total de
  Producto).
- **Cliente → Pedido (1:N):** un cliente puede no haber hecho pedidos
  aún (participación parcial) o haber hecho varios. Un pedido pertenece
  exactamente a un cliente (participación total).
- **Pedido ↔ Producto (N:M), antes de resolverla:** un pedido incluye
  varios productos y un producto aparece en muchos pedidos. No es 1:N.
  La participación de ambos lados es total en el negocio actual (un
  pedido tiene al menos un producto; el producto de una línea existe).
  **Después de resolverla:** la entidad asociativa Detalle_Pedido
  parte la N:M en dos 1:N (Pedido → Detalle_Pedido y Producto →
  Detalle_Pedido). Ahí viven `cantidad` y `precio_unitario`.

### Respuestas a las preguntas guía

**¿Por qué la relación entre producto y pedido no puede resolverse como
una relación binaria simple 1:N?**
Porque un pedido puede tener muchos productos y un producto puede estar
en muchos pedidos (es una relación N:M). Si se modelara como 1:N se
perdería la capacidad de asociar múltiples productos a un mismo ticket.
Además, la regla R4 exige guardar la `cantidad` y el `precio_unitario`
histórico de ese producto en ese pedido puntual; esos atributos no
pueden vivir ni en `Producto` ni en `Pedido` por separado, necesitan la
entidad intermedia.

**¿Qué entidad tiene participación parcial y cuál total en la relación
con Categoría?**
`Categoria` tiene participación parcial (puede existir una categoría
recién creada sin productos todavía). `Producto` tiene participación
total (todo producto debe pertenecer a exactamente una categoría). Si se
invirtiera la lectura, no podría registrarse una categoría nueva antes
de dar de alta sus productos.

**¿Alguno de los atributos podría descomponerse?**
El `nombre` del cliente podría separarse en `nombre` y `apellido` para
mayor prolijidad en reportes; se optó por dejarlo simple dado el alcance
acotado del sistema.

## Parte 2 — Derivación al modelo relacional

```
Cliente (id_cliente, nombre, correo, telefono)
Categoria (id_categoria, nombre_categoria, descripcion)
Producto (id_producto, nombre_producto, precio_actual, stock, activo,
          id_categoria -> Categoria.id_categoria)
Pedido (id_pedido, fecha_hora, forma_pago,
        id_cliente -> Cliente.id_cliente)
Detalle_Pedido (id_pedido -> Pedido.id_pedido,
                id_producto -> Producto.id_producto,
                cantidad, precio_unitario)
```

### Respuestas a las preguntas guía

**¿Qué pasaría si la tabla intermedia no tuviera ambas FK como NOT
NULL?**
`Detalle_Pedido` solo tiene sentido uniendo un `Pedido` con un
`Producto`; si `id_pedido` o `id_producto` pudieran ser `NULL` se podría
guardar una fila sin sentido (un detalle que no está ligado a ningún
pedido o a ningún producto). Como ambas columnas ya forman parte de la
PK compuesta, en la práctica ya vienen obligadas a `NOT NULL`, pero
conviene dejarlo explícito en el diseño.

**¿Si un pedido pudiera existir sin productos, cambia la
participación?**
Sí. En el modelo actual un pedido siempre tiene al menos un producto
(participación total, equivalente a 1,N). Si se permitiera un pedido
"en proceso" sin productos todavía, la participación pasaría a ser
opcional (0,N). Esto no afecta el `NOT NULL` de las columnas de
`Detalle_Pedido` (esas siguen siendo obligatorias si existe la fila);
solo cambia si es obligatorio que exista al menos una fila de detalle
por pedido — eso no se puede garantizar solo con FK/`NOT NULL`, haría
falta un trigger o validación de aplicación.

**¿PK compuesta o subrogada en la tabla intermedia?**
Se eligió PK compuesta `(id_pedido, id_producto)` porque:

1. Evita que el mismo producto se repita dos veces en el mismo pedido,
   sin necesidad de un `UNIQUE` aparte.
2. Ninguna otra tabla necesita referenciar una fila de `Detalle_Pedido`
   por sí sola, así que no se justifica un id subrogado.
3. La PK compuesta deja explícito que cada línea de pedido es única por
   la combinación pedido-producto.

## Parte 3 — Normalización hasta 3FN/BCNF

Punto de partida: planilla plana con columnas `nro_pedido, fecha,
cliente, producto, categoria, precio_unitario, cant, subtotal,
forma_pago`.

### Paso 1 — Clave candidata de la relación universal

Dado que dentro de un mismo pedido un producto no se repite en más de
una línea, la clave candidata es `(nro_pedido, producto)`.

### Paso 2 — Dependencias funcionales identificadas

1. `nro_pedido → fecha, cliente, forma_pago` (cada pedido tiene una
   única fecha, cliente y forma de pago).
2. `producto → categoria` (cada producto pertenece a una única
   categoría).
3. `nro_pedido, producto → cant, precio_unitario, subtotal` (atributos
   propios de la línea del pedido).

### Paso 3 — Verificación de 1FN

Cumple: todos los atributos tienen valores atómicos, no hay listas ni
grupos repetidos dentro de una misma celda.

### Paso 4 — Verificación y corrección de 2FN

Hay dependencias parciales: `fecha`, `cliente` y `forma_pago` dependen
solo de `nro_pedido` (no del producto); `categoria` depende solo de
`producto`. Se separan en tablas independientes:

- **Pedido** `(nro_pedido, fecha, cliente, forma_pago)`
- **Producto** `(producto, categoria)`
- **Detalle_Pedido** `(nro_pedido, producto, cant, subtotal,
  precio_unitario)`

### Paso 5 — Verificación y corrección de 3FN

Al separar cabecera (Pedido), catálogo (Producto) y detalle
(Detalle_Pedido) se eliminan las dependencias transitivas de la
planilla. El `subtotal` (`cant * precio_unitario`) depende de otros
atributos no clave de la misma fila: guardarlo viola 3FN. No se
persiste.

### Paso 6 — Verificación de BCNF

Sin `subtotal`, en Pedido, Producto y Detalle_Pedido todo determinante
es clave candidata. Ese es el esquema que implementa `schema.sql`, y
cumple BCNF. Si se volviera a guardar `subtotal`, Detalle_Pedido
dejaría de estar en 3FN y por lo tanto tampoco en BCNF.

### Paso 7 — Conjunto final de tablas normalizadas

1. `Pedido (nro_pedido PK, fecha, cliente, forma_pago)`
2. `Producto (producto PK, categoria)`
3. `Detalle_Pedido (nro_pedido FK, producto FK, cant, precio_unitario)`
   — PK compuesta `(nro_pedido, producto)`. Sin `subtotal`.

### Preguntas de integración

**Comparación con el ER de la Parte 1.**
Las tablas normalizadas a partir de la planilla histórica coinciden
conceptualmente con las entidades del ER (Cliente, Pedido, Producto,
Categoria, Detalle_Pedido). Atributos como el correo del cliente no
estaban en la planilla histórica porque el negocio no lo registraba en
sus papeles iniciales — normalizar datos históricos existentes da una
estructura base, pero modelar desde un enunciado permite anticipar
datos necesarios (correo, stock) que el papel no mostraba.

**Sobre el subtotal.**
Es `cantidad * precio_unitario`. Guardarlo violaría 3FN, así que
`schema.sql` no tiene esa columna. El precio histórico ya queda
congelado en `precio_unitario`; el subtotal se calcula en
`vista_detalle_pedido_producto`.
