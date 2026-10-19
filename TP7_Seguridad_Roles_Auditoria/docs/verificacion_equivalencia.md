# Protección de Datos Personales: Anonimización y Verificación de Equivalencia (Parte D)

**Proyecto:** Food Store — Base de Datos II (Unidad 5: Administración y Seguridad)  
**Motor:** PostgreSQL 16+ (verificado en PostgreSQL 18.3)  
**Autores:** Tiziano Valentini y Juan Martin Garcia  
**Script vinculado:** [`sql/usuario_anon.sql`](../sql/usuario_anon.sql)  

---

## 1. Diseño de Anonimización Determinista (`public.usuario_anon`) (Punto 1)

Siguiendo el patrón de seudonimización determinista trabajado en la Clase 2, la tabla `public.usuario_anon` transforma irreversiblemente los atributos identificables y las credenciales de `public.usuario`, mientras conserva intactas las dimensiones analíticas (`rol` y `fecha_alta`) y la integridad referencial/cardinalidad (`id`):

| Columna en `usuario` | Columna en `usuario_anon` | Transformación Determinista Aplicada | Propósito |
|---|---|---|---|
| `id` | `id` | Se conserva el identificador numérico (`BIGINT PRIMARY KEY`). | Mantener unicidad y conteos exactos sin exponer PII. |
| `nombre` | `nombre_anon` | `'Usuario_' \|\| substr(md5('fs_nombre_' \|\| id::text), 1, 8)` | Reemplazar nombres reales por alias sintéticos reproducibles. |
| `email` | `email_anon` | `'usr_' \|\| substr(md5(lower(email)), 1, 10) \|\| '@anon.foodstore.local'` | Reemplazar correos reales manteniendo formato válido y restricción `UNIQUE`. |
| `password_hash` | `password_hash` | `encode(digest('anon_pwd_' \|\| password_hash, 'sha256'), 'hex')` | Impedir ataques de diccionario *offline* sobre los hashes reales. |
| `rol` | `rol` | Sin alteración (`cliente`, `soporte`, `logistica`, `reportes`, `auditor`, `admin`). | Preservar la distribución por rol para reportes y consultas agregadas. |
| `fecha_alta` | `fecha_alta` | Sin alteración (`TIMESTAMPTZ`). | Preservar las series de tiempo mensuales y diarias de incorporación. |

### Muestra comparativa verificada (`usuario` vs. `usuario_anon`)
```text
  id  |    nombre_real    |   nombre_anon    |             email_real             |             email_anon              |    rol    | fecha_alta 
------+-------------------+------------------+------------------------------------+-------------------------------------+-----------+------------
  101 | Tiziano Valentini | Usuario_03b5ca33 | tiziano.valentini@foodstore.com.ar | usr_4c5d3f7fac@anon.foodstore.local | admin     | 2026-01-05
  202 | Matías Quiroga    | Usuario_5ed5cca5 | matias.quiroga@foodstore.com.ar    | usr_971373c321@anon.foodstore.local | soporte   | 2026-02-18
  301 | Valeria Castro    | Usuario_6d98e924 | valeria.castro@foodstore.com.ar    | usr_7399d9dd15@anon.foodstore.local | reportes  | 2026-01-20
  801 | Inspector Gómez   | Usuario_6e4dea86 | inspector.gomez@foodstore.com.ar   | usr_df0c608bef@anon.foodstore.local | logistica | 2026-02-10
 1001 | Ana Gómez         | Usuario_4b5a8c73 | ana.gomez@example.com              | usr_fd9ffbf299@anon.foodstore.local | cliente   | 2026-01-06
(5 filas)
```

---

## 2. Consultas de Agregación Generadas con OpenCode (Punto 2)

Se especificó a **OpenCode** la consulta de agregación sobre `public.usuario_anon` agrupando por mes de alta (`YYYY-MM` en zona horaria local de Argentina) y `rol`, calculando la cantidad de usuarios dados de alta, la primera fecha de alta del mes y la última fecha de alta del mes, y se le solicitó la consulta equivalente sobre la tabla real `public.usuario`.

### 2.1. Consulta sobre `public.usuario_anon`
```sql
SELECT
    to_char(date_trunc('month', ua.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM') AS mes_alta,
    ua.rol,
    COUNT(*) AS cantidad_usuarios,
    MIN(ua.fecha_alta)::date AS primera_alta_mes,
    MAX(ua.fecha_alta)::date AS ultima_alta_mes
FROM public.usuario_anon ua
GROUP BY
    date_trunc('month', ua.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    ua.rol
ORDER BY
    mes_alta ASC,
    ua.rol ASC;
```

### 2.2. Consulta equivalente sobre `public.usuario`
```sql
SELECT
    to_char(date_trunc('month', u.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM') AS mes_alta,
    u.rol,
    COUNT(*) AS cantidad_usuarios,
    MIN(u.fecha_alta)::date AS primera_alta_mes,
    MAX(u.fecha_alta)::date AS ultima_alta_mes
FROM public.usuario u
GROUP BY
    date_trunc('month', u.fecha_alta AT TIME ZONE 'America/Argentina/Buenos_Aires'),
    u.rol
ORDER BY
    mes_alta ASC,
    u.rol ASC;
```

---

## 3. Verificación Lado a Lado de Equivalencia de Resultados (Punto 3)

Ambas consultas se ejecutaron sobre `food_store_dev` (242 usuarios totales distribuidos en 30 agrupamientos mes-rol). Los resultados coinciden al 100% en agrupamientos, conteos y extremos temporales:

| # | `usuario_anon`: `mes_alta` | `usuario_anon`: `rol` | `usuario_anon`: `cantidad` | `usuario_anon`: `rango_fechas` | $\iff$ | `usuario` (real): `mes_alta` | `usuario` (real): `rol` | `usuario` (real): `cantidad` | `usuario` (real): `rango_fechas` |
|---:|:---:|:---:|---:|:---:|:---:|:---:|:---:|---:|:---:|
| 1 | `2026-01` | `admin` | **2** | `2026-01-05` .. `2026-01-05` | $=$ | `2026-01` | `admin` | **2** | `2026-01-05` .. `2026-01-05` |
| 2 | `2026-01` | `auditor` | **1** | `2026-01-15` .. `2026-01-15` | $=$ | `2026-01` | `auditor` | **1** | `2026-01-15` .. `2026-01-15` |
| 3 | `2026-01` | `cliente` | **22** | `2026-01-06` .. `2026-01-26` | $=$ | `2026-01` | `cliente` | **22** | `2026-01-06` .. `2026-01-26` |
| 4 | `2026-01` | `reportes` | **1** | `2026-01-20` .. `2026-01-20` | $=$ | `2026-01` | `reportes` | **1** | `2026-01-20` .. `2026-01-20` |
| 5 | `2026-01` | `soporte` | **1** | `2026-01-12` .. `2026-01-12` | $=$ | `2026-01` | `soporte` | **1** | `2026-01-12` .. `2026-01-12` |
| 6 | `2026-02` | `admin` | **1** | `2026-02-01` .. `2026-02-01` | $=$ | `2026-02` | `admin` | **1** | `2026-02-01` .. `2026-02-01` |
| 7 | `2026-02` | `cliente` | **22** | `2026-02-04` .. `2026-02-24` | $=$ | `2026-02` | `cliente` | **22** | `2026-02-04` .. `2026-02-24` |
| 8 | `2026-02` | `logistica` | **2** | `2026-02-10` .. `2026-02-25` | $=$ | `2026-02` | `logistica` | **2** | `2026-02-10` .. `2026-02-25` |
| 9 | `2026-02` | `soporte` | **1** | `2026-02-18` .. `2026-02-18` | $=$ | `2026-02` | `soporte` | **1** | `2026-02-18` .. `2026-02-18` |
| 10 | `2026-03` | `cliente` | **22** | `2026-03-07` .. `2026-03-27` | $=$ | `2026-03` | `cliente` | **22** | `2026-03-07` .. `2026-03-27` |
| 11 | `2026-03` | `logistica` | **1** | `2026-03-12` .. `2026-03-12` | $=$ | `2026-03` | `logistica` | **1** | `2026-03-12` .. `2026-03-12` |
| 12 | `2026-03` | `soporte` | **1** | `2026-03-22` .. `2026-03-22` | $=$ | `2026-03` | `soporte` | **1** | `2026-03-22` .. `2026-03-22` |
| 13 | `2026-04` | `cliente` | **22** | `2026-04-05` .. `2026-04-25` | $=$ | `2026-04` | `cliente` | **22** | `2026-04-05` .. `2026-04-25` |
| 14 | `2026-04` | `logistica` | **1** | `2026-04-05` .. `2026-04-05` | $=$ | `2026-04` | `logistica` | **1** | `2026-04-05` .. `2026-04-05` |
| 15 | `2026-04` | `reportes` | **1** | `2026-04-11` .. `2026-04-11` | $=$ | `2026-04` | `reportes` | **1** | `2026-04-11` .. `2026-04-11` |
| 16 | `2026-05` | `auditor` | **1** | `2026-05-20` .. `2026-05-20` | $=$ | `2026-05` | `auditor` | **1** | `2026-05-20` .. `2026-05-20` |
| 17 | `2026-05` | `cliente` | **22** | `2026-05-03` .. `2026-05-23` | $=$ | `2026-05` | `cliente` | **22** | `2026-05-03` .. `2026-05-23` |
| 18 | `2026-05` | `soporte` | **1** | `2026-05-10` .. `2026-05-10` | $=$ | `2026-05` | `soporte` | **1** | `2026-05-10` .. `2026-05-10` |
| 19 | `2026-06` | `cliente` | **22** | `2026-06-06` .. `2026-06-26` | $=$ | `2026-06` | `cliente` | **22** | `2026-06-06` .. `2026-06-26` |
| 20 | `2026-06` | `logistica` | **1** | `2026-06-08` .. `2026-06-08` | $=$ | `2026-06` | `logistica` | **1** | `2026-06-08` .. `2026-06-08` |
| 21 | `2026-06` | `reportes` | **1** | `2026-06-19` .. `2026-06-19` | $=$ | `2026-06` | `reportes` | **1** | `2026-06-19` .. `2026-06-19` |
| 22 | `2026-07` | `cliente` | **22** | `2026-07-04` .. `2026-07-24` | $=$ | `2026-07` | `cliente` | **22** | `2026-07-04` .. `2026-07-24` |
| 23 | `2026-07` | `soporte` | **1** | `2026-07-04` .. `2026-07-04` | $=$ | `2026-07` | `soporte` | **1** | `2026-07-04` .. `2026-07-04` |
| 24 | `2026-08` | `cliente` | **22** | `2026-08-07` .. `2026-08-27` | $=$ | `2026-08` | `cliente` | **22** | `2026-08-07` .. `2026-08-27` |
| 25 | `2026-08` | `logistica` | **1** | `2026-08-14` .. `2026-08-14` | $=$ | `2026-08` | `logistica` | **1** | `2026-08-14` .. `2026-08-14` |
| 26 | `2026-08` | `reportes` | **1** | `2026-08-25` .. `2026-08-25` | $=$ | `2026-08` | `reportes` | **1** | `2026-08-25` .. `2026-08-25` |
| 27 | `2026-09` | `auditor` | **1** | `2026-09-01` .. `2026-09-01` | $=$ | `2026-09` | `auditor` | **1** | `2026-09-01` .. `2026-09-01` |
| 28 | `2026-09` | `cliente` | **22** | `2026-09-05` .. `2026-09-25` | $=$ | `2026-09` | `cliente` | **22** | `2026-09-05` .. `2026-09-25` |
| 29 | `2026-09` | `soporte` | **1** | `2026-09-14` .. `2026-09-14` | $=$ | `2026-09` | `soporte` | **1** | `2026-09-14` .. `2026-09-14` |
| 30 | `2026-10` | `cliente` | **22** | `2026-10-03` .. `2026-10-23` | $=$ | `2026-10` | `cliente` | **22** | `2026-10-03` .. `2026-10-23` |
| **Total** | **10 meses** | **6 roles** | **242** | — | $=$ | **10 meses** | **6 roles** | **242** | — |

### Verificación formal mediante diferencia simétrica (`EXCEPT ALL`)
```text
 mes_alta | rol | cantidad_usuarios | primera_alta_mes | ultima_alta_mes 
----------+-----+-------------------+------------------+-----------------
(0 filas)
```

---

## 4. Frontera de Privacidad: Qué Datos de Food Store Nunca Deben Salir hacia una IA (Punto 4)

> **Respuesta directa (Síntesis en tres oraciones según consigna Parte D.4):**  
> Jamás deben enviarse a un asistente de inteligencia artificial sin anonimizar los **datos personales identificables (PII)** almacenados en `Cliente` (`nombre`, `correo`, `telefono`) y en `usuario` (`nombre`, `email`), ni los **secretos de autenticación y acceso** (`usuario.password_hash`, contraseñas de roles en `CREATE/ALTER ROLE` o cadenas de conexión con credenciales reales).  
> Tampoco deben exponerse nunca **fragmentos de logs crudos del servidor** que contengan literales de consultas con correos, teléfonos, contraseñas enviadas a `fn_autenticar` o direcciones IP reales e infraestructura interna del entorno productivo.  
> Finalmente, no debe compartirse el cruce individualizado de historial de compras y medios de pago (`Pedido` y `Detalle_Pedido` vinculados a un `Cliente` real identificable), debiendo limitarse toda interacción con la IA a metadatos del esquema (`DDL`), planes de ejecución sobre volúmenes sintéticos o tablas previamente seudonimizadas como `usuario_anon`.
