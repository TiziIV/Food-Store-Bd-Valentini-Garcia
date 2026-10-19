# Especificación de Requerimientos (Kiro) — Esquema de Roles y Mínimo Privilegio

**Proyecto:** Food Store — Base de Datos II (Unidad 5: Administración y Seguridad)  
**Motor de referencia:** PostgreSQL 16+ (verificado en PostgreSQL 18.3)  
**Autores:** Tiziano Valentini y Juan Martin Garcia  
**Herramienta de especificación:** Kiro  

---

## 1. Contexto y Objetivo de Seguridad

El sistema **Food Store** gestiona operaciones de comercio electrónico minorista (`Cliente`, `Categoria`, `Producto`, `Pedido`, `Detalle_Pedido`), reportes analíticos (`vista_productos_vigentes`, `vista_pedidos_cliente`, `vista_detalle_pedido_producto`, `mv_facturacion_categoria_mes`), control mayorista de lotes (`lote`, `deposito`, `control_lote_almacen`, `responsable_deposito`, `asignacion_control_lote`) y gestión de identidades (`usuario`, `usuario_anon`).

Hasta la Unidad 4, las ejecuciones de desarrollo se realizaban con el superusuario `postgres`. El objetivo de esta especificación es definir un modelo de control de acceso basado en roles (**RBAC**) aplicando estrictamente el **Principio de Mínimo Privilegio (PoLP)**: cada identidad recibe exclusivamente los permisos indispensables para cumplir su función operativa, revocando todo privilegio implícito del rol `PUBLIC` y aislando las credenciales (`password_hash`) y datos personales de contacto (`telefono`).

---

## 2. Relevamiento y Justificación de Roles (Regla de Una Oración por Rol)

De acuerdo con la consigna de la Parte A.1, se especifican los **cuatro roles de grupo base**, los **dos roles de login base** y **dos roles adicionales propios** requeridos por la arquitectura real de nuestro proyecto Food Store (`rol_logistica` para la extensión de depósitos/lotes de TP6 y `rol_auditor` para seguridad y cumplimiento):

### 2.1. Roles de Grupo (Sin Login — `NOLOGIN`)

1. **`rol_app_lectura`**: Habilita únicamente la lectura (`SELECT`) sobre el catálogo comercial vigente (`categoria`, `producto`, `vista_productos_vigentes`) porque la navegación pública del escaparate web solo requiere consultar productos disponibles sin alterar datos ni acceder a clientes o pedidos de terceros.
2. **`rol_app_escritura`**: Habilita la inserción y actualización transaccional sobre el circuito de compra (`cliente`, `pedido`, `detalle_pedido`, `producto`) y la ejecución de `sp_registrar_pedido`, `sp_anular_pedido`, `fn_total_pedido` y `fn_autenticar` porque el backend de ventas debe procesar órdenes de compra atómicas sin poseer permisos de borrado físico (`DELETE`, `TRUNCATE`) ni modificación estructural (`ALTER`, `DROP`).
3. **`rol_soporte`**: Habilita la consulta acotada de clientes y pedidos (`vista_pedidos_cliente`, `vista_detalle_pedido_producto`), la lectura parcial de `usuario` a nivel de columnas (`id, nombre, email, rol, fecha_alta`, excluyendo `password_hash`) y la ejecución de `fn_resetear_password` y `sp_dar_baja_cliente` porque el equipo de atención al cliente necesita asistir usuarios y gestionar bajas lógicas sin conocer jamás los hashes de contraseñas ni alterar precios o facturación.
4. **`rol_reportes`**: Habilita exclusivamente la lectura (`SELECT`) sobre las vistas analíticas (`mv_facturacion_categoria_mes`, `vista_pedidos_cliente`, `vista_detalle_pedido_producto`, `vista_productos_vigentes`) y sobre el padrón anonimizado (`usuario_anon`) porque el área de Business Intelligence requiere indicadores agregados sin exponerse a datos personales identificables crudos (`cliente.telefono`, `usuario.email` real o `usuario.password_hash`).
5. **`rol_logistica` *(Rol adicional propio de Food Store)***: Habilita la consulta de catálogo y líneas de pedidos (`categoria`, `producto`, `vista_detalle_pedido_producto`), la gestión de las tablas de control de almacén de TP6 (`lote`, `deposito`, `control_lote_almacen`, `responsable_deposito`, `asignacion_control_lote`) y la actualización a nivel de columna sobre inventario (`UPDATE (stock, activo) ON producto`) porque los inspectores de depósito deben ajustar existencias físicas y controlar lotes sin poder modificar los precios de venta (`precio_actual`) ni la facturación.
6. **`rol_auditor` *(Rol adicional propio de Food Store)***: Habilita la inspección de solo lectura sobre metadatos de usuarios sin secretos (`SELECT (id, nombre, email, rol, fecha_alta) ON usuario`), vistas de control (`vista_control_lote_almacen_fnbc`, `vista_pedidos_cliente`) y datos anonimizados (`usuario_anon`) porque el área de seguridad informática debe auditar accesos y verificar consistencia normativa sin capacidad de alterar ninguna fila ni extraer credenciales (`password_hash`).

### 2.2. Roles de Inicio de Sesión (`LOGIN`)

7. **`app_web`**: Habilita la conexión autenticada del backend de la aplicación heredando únicamente `rol_app_lectura` y `rol_app_escritura` (`INHERIT`, `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`) porque el servidor web necesita operar el flujo comercial continuo bajo una identidad acotada que impida el escalamiento de privilegios en caso de compromiso de la capa de aplicación.
8. **`admin_datos`**: Habilita la conexión administrativa sobre los datos y objetos del esquema de Food Store (mantenimiento de tablas operativas, secuencias y refresco de vistas materializadas como `mv_facturacion_categoria_mes`) sin privilegios de superusuario (`NOSUPERUSER`, `NOCREATEROLE`, `NOCREATEDB`) porque el administrador de datos del negocio debe gestionar el almacenamiento sin tener control sobre el sistema operativo ni sobre la configuración global de auditoría del clúster.

---

## 3. Requerimientos Funcionales y de Seguridad (Historias EARS)

- **REQ-01 (Revocación de `PUBLIC`):** **CUANDO** cualquier rol se conecte a la base de datos `food_store`, **EL SISTEMA DEBERÁ** denegar por defecto el acceso a todas las tablas, secuencias, funciones y procedimientos del esquema `public` a menos que exista un `GRANT` explícito hacia dicho rol o hacia un grupo del cual sea miembro.
- **REQ-02 (Protección de secretos por columna en `usuario`):** **CUANDO** un miembro de `rol_soporte` o `rol_auditor` ejecute una consulta sobre la tabla `usuario`, **EL SISTEMA DEBERÁ** permitir la proyección de las columnas `(id, nombre, email, rol, fecha_alta)` y rechazar con `permission denied for table usuario` cualquier intento de leer la columna `password_hash` o ejecutar `SELECT * FROM usuario`.
- **REQ-03 (Protección de precios por columna en `producto`):** **CUANDO** un miembro de `rol_logistica` actualice la tabla `producto`, **EL SISTEMA DEBERÁ** permitir exclusivamente `UPDATE (stock, activo)` y rechazar cualquier intento de modificar `precio_actual`, `nombre_producto` o `id_categoria`.
- **REQ-04 (Encapsulamiento de credenciales con `SECURITY DEFINER`):** **CUANDO** `app_web` invoque `fn_autenticar(email, password)` o `rol_soporte` invoque `fn_resetear_password(usuario_id, nueva_password)`, **EL SISTEMA DEBERÁ** validar o actualizar el `password_hash` mediante funciones `SECURITY DEFINER` con `search_path` fijo (`public, pg_temp`), evitando otorgar permisos de lectura o escritura directa sobre `usuario.password_hash`.
- **REQ-05 (Persistencia en objetos futuros):** **CUANDO** `postgres` o `admin_datos` creen nuevas tablas o secuencias en el esquema `public`, **EL SISTEMA DEBERÁ** aplicar automáticamente la política por defecto (`ALTER DEFAULT PRIVILEGES`) otorgando `SELECT` a `rol_app_lectura` e `INSERT, UPDATE` a `rol_app_escritura`.
- **REQ-06 (Bloqueo de escalamiento de privilegios):** **CUANDO** un rol de bajo privilegio (como `app_web` o `rol_soporte`) intente ejecutar `SET ROLE admin_datos` o `GRANT admin_datos TO ...`, **EL SISTEMA DEBERÁ** abortar la operación con error de permisos y registrar el evento en el log de auditoría del servidor.
