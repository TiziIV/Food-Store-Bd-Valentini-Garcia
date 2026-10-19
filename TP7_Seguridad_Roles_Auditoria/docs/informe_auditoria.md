# Informe de Configuración y Prueba de Auditoría (Parte B)

**Proyecto:** Food Store — Base de Datos II (Unidad 5: Administración y Seguridad)  
**Motor:** PostgreSQL 16+ (ejecutado sobre PostgreSQL 18.3)  
**Autores:** Tiziano Valentini y Juan Martin Garcia  
**Archivos vinculados:** [`sql/auditoria_test.sql`](../sql/auditoria_test.sql) y [`docs/log_auditoria_prueba.txt`](log_auditoria_prueba.txt)  

---

## 1. Parámetros de Auditoría Activados (Parte B.1)

Para dotar a la base de datos de **Food Store** de capacidad de rendición de cuentas (*accountability*) y reconstrucción forense sin necesidad de reiniciar el servicio, se modificó la configuración mediante `ALTER SYSTEM SET` (persistido en `postgresql.auto.conf`) seguido de `SELECT pg_reload_conf();`:

| Parámetro | Valor Anterior | Valor Configurado | Contexto | Propósito en la Auditoría de Food Store |
|---|---|---|---|---|
| `logging_collector` | `on` | `on` | `postmaster` | Captura el flujo de `stderr` y lo persiste en archivos rotativos dentro de `PGDATA/log/`. |
| `log_connections` | `""` (off) | `on` | `superuser-backend` | Registra cada intento de conexión TCP/socket recibido, el método de autenticación evaluado (`pg_hba.conf`) y la autorización de ingreso. |
| `log_disconnections` | `off` | `on` | `superuser-backend` | Registra el cierre de cada sesión junto con la duración exacta (`duración de sesión: HH:MM:SS.ms`). |
| `log_statement` | `none` | `mod` *(global)* / `all` *(rol en prueba)* | `superuser` | En nivel `'mod'` registra todo DDL (`CREATE`, `ALTER`, `DROP`, `GRANT`) y todo DML de modificación (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`). Para capturar la lectura (`SELECT`) en la sesión de prueba de `app_web`, se aplicó temporalmente `ALTER ROLE app_web SET log_statement = 'all';`. |
| `log_min_messages` | `warning` | `notice` | `superuser` | Permite registrar tanto alertas de seguridad (`RAISE WARNING 'AUTH_FAIL...'`) como eventos exitosos de autenticación (`RAISE NOTICE 'AUTH_OK...'`) emitidos por `fn_autenticar` y `fn_resetear_password`. |
| `log_min_error_statement` | `error` | `error` | `superuser` | Garantiza que ante cualquier excepción o fallo de permisos (`ERROR` / `FATAL`) quede registrada la sentencia SQL exacta que lo provocó. |
| `log_line_prefix` | `'%t '` | `'%m [%p] %q[app=%a] [user=%u@%d] [host=%h] '` | `sighup` | Enriquece cada línea con marca temporal con milisegundos (`%m`), PID del proceso backend (`%p`), aplicación cliente (`%a`), usuario y base (`%u@%d`), y dirección IP origen (`%h`). |

---

## 2. Análisis del Fragmento de Log Capturado (Parte B.3)

Sobre el fragmento real capturado en [`docs/log_auditoria_prueba.txt`](log_auditoria_prueba.txt), se identifican las cuatro dimensiones fundamentales de auditoría y las limitaciones del mecanismo nativo frente a `pgaudit`:

### 2.1. Qué información aporta el log nativo (Quién, Qué, Cuándo, Desde dónde)

1. **Cuándo (`%m` y duración de desconexión):**
   - Cada evento posee precisión de milisegundos y huso horario (`2026-10-19 15:57:27.771 -03`).
   - Al desconectar (`15:57:27.805 -03`), el motor informa la ventana exacta de actividad de la sesión (`duración de sesión: 0:00:00.042`).
2. **Quién (`%u@%d`, `%p` y contexto de funciones):**
   - El prefijo identifica la cuenta de motor y la base (`[user=app_web@food_store_dev]`) y el identificador de proceso `[25924]`, lo que permite correlacionar todas las operaciones de una misma conexión aunque concurran decenas de sesiones simultáneas.
   - En la invocación a `fn_autenticar` (`SECURITY DEFINER`), el mensaje de `WARNING` distingue entre quien abrió la sesión (`session_user=app_web`), el propietario efectivo de ejecución (`current_user=postgres`) y la identidad de negocio que intentó autenticarse (`email=sofia.pereyra@foodstore.com.ar`).
   - En el intento fallido de conexión a nivel motor (`PID [15172]`), registra la identidad reclamada (`user=intruso_externo@food_store_dev`).
3. **Desde dónde (`%h`, puerto y `%a`):**
   - Registra el host remoto (`[host=127.0.0.1]`) y el puerto efímero de origen (`port=58044` para `app_web` y `port=58046` para `intruso_externo`), además del `application_name` declarado (`[app=foodstore_auditoria_test]`).
4. **Qué ocurrió (Sentencias y estados de terminación):**
   - **Lectura (`15:57:27.773`):** `SELECT id_producto, nombre_producto, precio_actual, stock FROM public.producto WHERE id_producto IN (1, 2, 3)...`
   - **Inserción (`15:57:27.775`):** `WITH nuevo_pedido AS (INSERT INTO public.pedido ...) INSERT INTO public.detalle_pedido ...`
   - **Actualización (`15:57:27.779`):** `UPDATE public.producto SET stock = stock + 10 WHERE id_producto = 1;`
   - **Inicio de sesión fallido (`15:57:27.781` y `15:57:27.841`):**
     - A nivel aplicación: `WARNING: AUTH_FAIL: intento de inicio de sesion fallido para email=sofia.pereyra@foodstore.com.ar`.
     - A nivel motor: `FATAL: no existe el rol «intruso_externo»`.

### 2.2. Qué queda fuera del alcance del log nativo y qué aportaría `pgaudit`

Si Food Store requiriera un nivel de auditoría superior para cumplimiento normativo estricto, el mecanismo nativo (`log_statement`) presenta las siguientes limitaciones que justifican el uso de la extensión **`pgaudit`** (o triggers de datos):

- **Falta de granularidad por objeto en lecturas (`SELECT`):** Con `log_statement = 'mod'`, las lecturas masivas sobre tablas críticas (`usuario`, `cliente`) no se registran; pero si se activa `log_statement = 'all'`, se registran absolutamente todos los `SELECT` de catálogo (`producto`, `categoria`), degradando el rendimiento de E/S e inundando el disco. **`pgaudit`** resuelve esto mediante *Object Audit Logging* (`pgaudit.role = 'rol_auditor'`), permitiendo auditar únicamente los `SELECT` o `UPDATE` que toquen tablas sensibles específicas (por ejemplo, `GRANT SELECT ON public.usuario TO rol_auditor;`) sin registrar lecturas inocuas del catálogo.
- **Visibilidad de sentencias ejecutadas dentro de funciones/procedimientos (`PL/pgSQL`):** El log nativo solo muestra la llamada externa (`CALL sp_registrar_pedido(...)` o `SELECT * FROM fn_autenticar(...)`), pero **no** desglosa los `SELECT`, `INSERT` o `UPDATE` internos que esa rutina ejecuta ni los objetos subyacentes afectados. **`pgaudit`** abre la caja negra registrando cada sub-sentencia ejecutada dentro del cuerpo de la función junto con el tipo de comando (`READ`, `WRITE`, `FUNCTION`) y el objeto afectado (`public.usuario`, `public.pedido`).
- **Detalle fila por fila y valores anteriores/nuevos (*Row-level before/after values*):** Ni `log_statement` ni `pgaudit` registran cuántas filas exactas devolvió un `SELECT` ni cuál era el valor anterior (`OLD`) y nuevo (`NEW`) de cada tupla modificada por un `UPDATE` masivo (por ejemplo, saber qué stock tenía `producto` antes del `UPDATE`). Para alcanzar trazabilidad fila por fila de valores previos y posteriores es necesario combinar `pgaudit` con **triggers de auditoría (`AFTER INSERT OR UPDATE OR DELETE FOR EACH ROW`)** hacia una tabla inmutable de historial o replicación lógica (CDC).

---

## 3. El Archivo de Log como Activo Sensible y Permisos en el SO / Motor (Parte B.4)

> **Respuesta directa (Síntesis en tres oraciones según consigna Parte B.4):**  
> Sí, el archivo de log del motor es en sí mismo un **activo altamente sensible** porque almacena en texto plano los parámetros literales de las sentencias auditadas —incluyendo correos electrónicos, datos personales de clientes e incluso contraseñas en claro cuando se invocan funciones como `fn_autenticar('usuario@mail.com', 'ClaveSecreta')` o `ALTER ROLE ... PASSWORD`—, además de exponer la estructura interna del esquema y errores del sistema.  
> Por ello, únicamente debe poder leerlo la cuenta de servicio del motor en el sistema operativo (`postgres`) y, de forma controlada, el equipo de seguridad/administración de infraestructura (o un agente recolector SIEM), **nunca** los desarrolladores generales ni los roles de aplicación (`app_web`, `rol_soporte`, `rol_reportes`).  
> A nivel de sistema operativo debe protegerse con permisos **`0600`** (`-rw-------`, solo lectura/escritura para el propietario `postgres`) o como máximo **`0640`** (`-rw-r-----` para el grupo de auditoría `postgres` configurando `log_file_mode = 0600` en `postgresql.conf`), y a nivel del motor revocando a todos los roles no superusuarios la membresía en los roles predefinidos `pg_read_server_files` y `pg_monitor` para impedir la lectura mediante `pg_read_file()`.
