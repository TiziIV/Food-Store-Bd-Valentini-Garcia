# Informe técnico — TPI, segunda entrega

**Proyecto:** Food Store  
**Integrantes:** Tiziano Valentini ([TiziIV](https://github.com/TiziIV)) y Juan Martin Garcia ([juanmagarciat](https://github.com/juanmagarciat))  
**Cátedra:** Base de Datos II — UTN FRM — Ciclo 2026  
**Motores:** PostgreSQL 16+, MongoDB y SQLite  

Las unidades 4, 5 y 6 están en este repositorio. Las unidades 7 y 8 están en `Trabajos-Practicos-BD-Valentini-Garcia`.

## 1. Qué se implementó

- **Unidad 4.** `control_lote_almacen` se descompuso a FNBC en `responsable_deposito` y `asignacion_control_lote`. El reporte del día usa `detalle_pedido.categoria_nombre`, mantenida por triggers. Spec en `TP6_FNBC_Desnormalizacion/kiro/`. Reversión en `herramientas/revertir_desnormalizacion.sql`.
- **Unidad 5.** Seis roles de grupo y dos de login. `rol_soporte` no recibe `password_hash`. Las contraseñas de `app_web` y `admin_datos` no están en `sql/roles.sql`: se pasan con `-v app_web_password` y `-v admin_datos_password`.
- **Unidad 6.** Carpeta `TP8_Mantenimiento_Respaldo`: `backup_foodstore.ps1`, `health_check.sql`, `maintenance.sql` y `restore_test.ps1`. La restauración va a `foodstore_restore_test`.
- **Unidad 7.** Colección `pedidos` con cliente y líneas embebidas, en `TP7_NoSQL_MongoDB`.
- **Unidad 8.** SQLite `STRICT`, instantánea del catálogo real y semáforo. El caso C7 ejecuta los `INSERT` inválidos.

## 2. Cómo se probó

- Unidad 4: transacción con `EXCEPT` vacío y pruebas de la columna desnormalizada, revertidas al final.
- Unidad 5: `roles.sql` sobre la copia de trabajo, con las contraseñas fuera del archivo. El simulacro de incidente está en `sql/simulacro_incidente.sql` y `docs/informe_incidente.md`.
- Unidad 6: `pg_dump -Fc` y `pg_restore` sobre `foodstore_restore_test`, sin reemplazar `foodstore`.
- Unidad 8: `simulador.py` con el catálogo semilla (Muzzarella, Napolitana, Coca 1.5L, Agua Mineral, Flan Casero). C4 usa el Flan Casero, no un producto inventado.

## 3. Resultados

Simulacro de la Unidad 6, documentado en `TP8_Mantenimiento_Respaldo/informe_u6.md`:

- Respaldo `foodstore_20261109_221751.dump`.
- RTO observado: **5,183 segundos**. RTO previsto: 300 segundos.
- RPO observado: **1,58 segundos**. RPO previsto: 24 horas, porque el respaldo es diario.

Unidad 8, después de correr el simulador:

- C2: `CONFLICTO` y, al aceptar el precio, `SIMULADO_APROBADO`.
- C3: `RECHAZADO` por stock de la Napolitana.
- C4: `RECHAZADO` porque el Flan Casero está dado de baja.
- C5: `SIMULADO_APROBADO`. El reenvío del mismo UUID lo frena la clave primaria y el estado no cambia.

## 4. Decisiones de diseño

- La dependencia `responsable_control_id → deposito_id` viola FNBC. Se descompone aunque en 3FN no se vería, porque `deposito_id` es primo.
- La desnormalización copia solo el nombre de la categoría. Se puede retirar con `revertir_desnormalizacion.sql` sin perder cantidad ni precio.
- PostgreSQL sigue siendo la fuente de verdad. MongoDB es copia de lectura del pedido. La tablet no confirma ventas: `SIMULADO_APROBADO` no descuenta stock en el servidor.
- No hay `rol_cajero`. `rol_soporte` no lee `password_hash`.

## 5. Uso de IA

Kiro fija la spec de las unidades 4, 5 y 8. Cada script se leyó y se corrió sobre una copia de trabajo o sobre SQLite.

Se descartó copiar la fecha y el subtotal al detalle, y se descartó un `GRANT SELECT` de toda la tabla `usuario`. Las DUIA están en `TP6_FNBC_Desnormalizacion/DUIA.md`, `TP7_Seguridad_Roles_Auditoria/BITACORA.md` y `TP8_Movil_SQLite_Cierre/docs/DUIA.md` del otro repositorio.
