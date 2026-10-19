# Informe de Laboratorio: Simulacro de Incidente de Acceso Indebido (Parte C)

**Proyecto:** Food Store — Base de Datos II (Unidad 5: Administración y Seguridad)  
**Motor:** PostgreSQL 16+ (verificado en PostgreSQL 18.3)  
**Autores:** Tiziano Valentini y Juan Martin Garcia  
**Archivos vinculados:** [`sql/simulacro_incidente.sql`](../sql/simulacro_incidente.sql) y [`docs/log_simulacro_anonimizado.txt`](log_simulacro_anonimizado.txt)  

---

## 1. Diseño del Escenario y Verificación del Bloqueo de Escalamiento (Puntos 1 y 2)

El script [`sql/simulacro_incidente.sql`](../sql/simulacro_incidente.sql) reproduce, exclusivamente sobre el entorno aislado de desarrollo (`food_store_dev`), una intrusión en cuatro fases operando bajo el rol de conexión de bajo privilegio `app_web` (`PID [12492]`):

1. **Fase 1 — Fuerza bruta / *Credential Stuffing* (`16:00:07.437` a `16:00:07.442`):**
   - 2 intentos fallidos contra la cuenta administrativa `tiziano.valentini@foodstore.com.ar` (`id = 101`).
   - 3 intentos fallidos contra la cuenta de soporte `matias.quiroga@foodstore.com.ar` (`id = 202`).
2. **Fase 2 — Inicio de sesión exitoso (`16:00:07.442`):**
   - Sexto intento exitoso contra `fn_autenticar('matias.quiroga@foodstore.com.ar', 'SoporteMatias#26')`, devolviendo `autenticado = true, usuario_id = 202, rol_usuario = 'soporte'`.
3. **Fase 3 — Intento de exfiltración y lectura masiva de `public.usuario` (`16:00:07.442` a `16:00:07.467`):**
   - Primero intenta `SELECT * FROM public.usuario;`, operación que **falla inmediatamente** con `ERROR: permiso denegado a la tabla usuario` gracias a que `rol_app_lectura` solo posee privilegios de selección a nivel de columnas específicas y **no** sobre `password_hash`.
   - Luego ejecuta `SELECT id, nombre, email, rol, fecha_alta FROM public.usuario ORDER BY id;`, logrando leer las columnas no secretas del padrón.
4. **Fase 4 — Intentos de escalamiento de privilegios y sabotaje (`16:00:07.467` a `16:00:07.469`):**
   - **Verificación de fallo (Punto 2):** Se comprueba y deja constancia documental de que **todos los intentos de escalamiento fallaron efectivamente**:
     - `SET ROLE admin_datos;` $\rightarrow$ Rechazado con `ERROR: se ha denegado el permiso para definir el rol «admin_datos»`.
     - `GRANT admin_datos TO app_web;` $\rightarrow$ Rechazado con `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos» (Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol)`.
     - `GRANT admin_datos TO rol_app_escritura;` $\rightarrow$ Rechazado con el mismo error de carencia de `ADMIN OPTION` y `NOCREATEROLE`.
     - `DELETE FROM public.usuario WHERE rol = 'admin';` $\rightarrow$ Rechazado con `ERROR: permiso denegado a la tabla usuario`.
   - La consulta de cierre confirma el estado inalterado de la sesión:
     ```text
      usuario_sesion | usuario_efectivo | tiene_admin_datos 
     ----------------+------------------+-------------------
      app_web        | app_web          | f
     ```

---

## 2. Anonimización del Log previo a su Envío a la IA (Punto 3)

Siguiendo la regla de frontera de seguridad de datos de la Clase 2, antes de enviar el fragmento de log del proceso `[12492]` a **OpenCode**, se reemplazaron todos los identificadores personales y secretos por valores sintéticos deterministas consistentes con `usuario_anon`:

| Dato Real en Entorno de Prueba | Valor Sintético en `log_simulacro_anonimizado.txt` | Criterio Aplicado |
|---|---|---|
| `tiziano.valentini@foodstore.com.ar` (`id=101`) | `usr_4c5d3f7fac@anon.foodstore.local` | `'usr_' \|\| substr(md5(lower(email)), 1, 10) \|\| '@anon.foodstore.local'` |
| `matias.quiroga@foodstore.com.ar` (`id=202`) | `usr_971373c321@anon.foodstore.local` | `'usr_' \|\| substr(md5(lower(email)), 1, 10) \|\| '@anon.foodstore.local'` |
| Contraseñas fallidas y exitosa en `fn_autenticar` | `<SECRET_REDACTED_FAIL_01..05>` y `<SECRET_REDACTED_OK>` | Supresión total de literales de credenciales en logs |
| IP local `127.0.0.1` y ruta absoluta `C:/Program Files/...` | `198.51.100.47` (bloque documental RFC 5737 `TEST-NET-2`) y `pg_hba.conf:115` | Ofuscación de topología e infraestructura del servidor |

---

## 3. Reconstrucción e Hipótesis Generada por la IA (OpenCode) (Punto 4)

### 3.1. Prompt entregado a OpenCode (sin contexto adicional al log)
> *"Analizá el siguiente fragmento de log de PostgreSQL (`docs/log_simulacro_anonimizado.txt`). Sin asumir contexto externo al que ofrece el log, reconstruí cronológicamente qué ocurrió durante la sesión del proceso [12492] y proponé una hipótesis de contención para el incidente."*

### 3.2. Respuesta completa recibida de OpenCode
> **Reconstrucción del incidente (PID 12492):**
> 1. **Ingreso inicial (`16:00:07.434 - 16:00:07.437`):** Un atacante externo ubicado en la dirección IP pública `198.51.100.47` estableció una conexión directa al motor PostgreSQL utilizando un cliente `psql` y autenticándose con el rol `app_web` en la base `food_store_dev`. Inmediatamente camufló su sesión cambiando el `application_name` a `'foodstore_web_gateway'` para simular tráfico legítimo del backend.
> 2. **Ataque de fuerza bruta y compromiso de cuenta (`16:00:07.437 - 16:00:07.442`):** En un lapso de 5 milisegundos, el atacante ejecutó un ataque automatizado de diccionario invocando `public.fn_autenticar`. Realizó 2 intentos fallidos sobre la cuenta `usr_4c5d3f7fac@anon.foodstore.local` y 3 intentos fallidos sobre `usr_971373c321@anon.foodstore.local`. En el sexto intento (`16:00:07.442`), logró adivinar la contraseña de `usr_971373c321@anon.foodstore.local` (`usuario_id=202`), obteniendo los permisos del rol `soporte` dentro de la base de datos.
> 3. **Exfiltración masiva de datos (`16:00:07.442 - 16:00:07.467`):** Tras autenticarse, intentó ejecutar `SELECT * FROM public.usuario;`, lo cual fue denegado. Sin embargo, corrigió la consulta especificando las columnas `SELECT id, nombre, email, rol, fecha_alta FROM public.usuario ORDER BY id;`, logrando exfiltrar la totalidad de los registros de clientes y administradores de la tabla `usuario` (incluyendo sus correos y metadatos de acceso). Es altamente probable que haya aprovechado una vulnerabilidad de SQL Injection (SQLi) en el endpoint de login del gateway web para inyectar estas consultas encadenadas.
> 4. **Intento de escalamiento de privilegios y sabotaje (`16:00:07.467 - 16:00:07.469`):** El atacante intentó escalar privilegios ejecutando `SET ROLE admin_datos;`, `GRANT admin_datos TO app_web;` y `GRANT admin_datos TO rol_app_escritura;`, además de intentar eliminar a los administradores mediante `DELETE FROM public.usuario WHERE rol = 'admin';`. Todas estas operaciones fueron bloqueadas por el motor con errores de permiso denegado (`ERROR: se ha denegado el permiso...`). Finalmente verificó sus permisos actuales y cerró la conexión a las `16:00:07.602` tras 175 ms de sesión.
>
> **Hipótesis y medidas de contención propuestas por la IA:**
> - **Bloqueo inmediato de red:** Bloquear en el firewall perimetral y en `pg_hba.conf` la IP pública externa `198.51.100.47`.
> - **Revocación del rol `soporte` en PostgreSQL:** Ejecutar `REVOKE rol_soporte FROM app_web;` y `ALTER ROLE soporte NOLOGIN;` porque el atacante escaló al rol `soporte` tras el login exitoso.
> - **Baja de emergencia del servicio y restauración de backup:** Detener el servicio de PostgreSQL y restaurar el último snapshot limpio de la base de datos ante el riesgo de que el atacante haya alterado registros durante la ventana en que `current_user=postgres` apareció en los mensajes de `fn_autenticar`.
> - **Reseteo masivo de contraseñas:** Forzar el cambio de contraseña de todos los usuarios de la tabla `usuario` y del rol `app_web`.

---

## 4. Lectura Crítica: Contraste entre la Reconstrucción de la IA y lo Ejecutado (Punto 5)

El equipo contrastó línea por línea la respuesta de OpenCode contra el script real ([`sql/simulacro_incidente.sql`](../sql/simulacro_incidente.sql)) y la evidencia objetiva de [`docs/log_simulacro_anonimizado.txt`](log_simulacro_anonimizado.txt):

| Categoría de Análisis | Detalle Técnico Detectado por el Equipo Humano |
|---|---|
| **1. Qué acertó la IA** | • Identificó con exactitud la ventana temporal (`175 ms` totales y `5 ms` para la ráfaga de autenticación) y el PID `[12492]`.<br/>• Reconstruyó correctamente los 5 intentos fallidos previos (2 contra el primer correo y 3 contra el segundo) y el sexto intento exitoso sobre `usuario_id=202`.<br/>• Detectó que el atacante intentó primero `SELECT * FROM public.usuario` (rechazado por el permiso a nivel de columna que protege `password_hash`) y luego enumeró las 5 columnas permitidas (`id, nombre, email, rol, fecha_alta`).<br/>• Confirmó correctamente que los tres intentos de escalamiento a `admin_datos` y el `DELETE` sobre `usuario` fallaron por falta de permisos. |
| **2. Qué omitió la IA** | • **Omitió el hallazgo de exposición de secretos en el propio log:** No advirtió que tener `log_statement = 'all'` activo sobre un rol que invoca `SELECT * FROM fn_autenticar(email, password)` provoca que las contraseñas ingresadas viajen en texto plano al archivo de log del motor.<br/>• **Omitió analizar la consulta final de verificación (`SELECT session_user, current_user, pg_has_role(...)`):** El log muestra la sentencia a las `16:00:07.469`, pero la IA la pasó por alto sin explicar por qué el atacante comprobó su membresía en `admin_datos`. |
| **3. Qué afirmó la IA sin sustento en el log (Alucinaciones / Inferencias erróneas)** | • **Error crítico 1 — Confusión entre el rol de aplicación (`usuario.rol = 'soporte'`) y el rol del motor (`rol_soporte`):** La IA afirmó que tras `fn_autenticar` el atacante *"obtuvo los permisos del rol `soporte` dentro de la base de datos"* y propuso ejecutar `REVOKE rol_soporte FROM app_web;`. El log **no sustenta** esto: `rol=soporte` en el `NOTICE: AUTH_OK` es únicamente un valor de la columna `public.usuario.rol` devuelto a la capa de aplicación; la sesión de PostgreSQL jamás ejecutó `SET ROLE rol_soporte` ni `app_web` es miembro de `rol_soporte`.<br/>• **Error crítico 2 — Malinterpretación de `current_user=postgres` en una función `SECURITY DEFINER`:** La IA sugirió restaurar un backup completo temiendo que el atacante hubiera ejecutado comandos como superusuario porque el log dice `(invocado por session_user=app_web, current_user=postgres)`. La IA no comprendió que `current_user=postgres` solo existe **dentro del ámbito encapsulado** de `fn_autenticar` por ser `SECURITY DEFINER`, y que fuera de esa función `current_user` siguió siendo `app_web` en todo momento.<br/>• **Error 3 — Asunción de vector de ataque (SQL Injection en endpoint web) e IP pública real:** El log muestra una conexión directa con `nombre_de_aplicación=psql` que luego ejecuta `SET application_name = 'foodstore_web_gateway';`. No hay ninguna evidencia en el log de una inyección SQL concatenada desde una aplicación web, y la IP `198.51.100.47` pertenece al rango reservado de documentación `198.51.100.0/24` (`TEST-NET-2`, RFC 5737) usado en la anonimización. |

---

## 5. Decisión Final de Contención del Equipo Humano (Punto 6)

> [!IMPORTANT]
> Las siguientes medidas constituyen la **decisión final tomada con criterio propio por el equipo humano (Tiziano Valentini y Juan Martin Garcia)** a partir de la evidencia verificada en el log y en el esquema de permisos, descartando las acciones automáticas o desproporcionadas sugeridas por la IA.

En un incidente real con esta evidencia exacta, el equipo aplica el siguiente plan de contención en cuatro pasos ordenados por prioridad:

1. **Contención inmediata de las dos identidades efectivamente comprometidas (`app_web` y `usuario_id = 202`):**
   - Dado que el atacante inició una sesión directa con `psql` autenticándose como el rol de motor `app_web`, la credencial de base de datos del backend fue expuesta. Se rota inmediatamente la contraseña de `app_web` (`ALTER ROLE app_web WITH PASSWORD '...';`), se cierran sus sesiones activas sospechosas con `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'app_web' AND client_addr = ...;` y se restringe en `pg_hba.conf` el acceso de `app_web` exclusivamente a la IP privada fija del servidor de aplicaciones (nunca rangos amplios).
   - Se fuerza el blanqueo inmediato de la contraseña de la cuenta de aplicación comprometida (`usuario_id = 202`, `matias.quiroga@foodstore.com.ar`) invocando `SELECT public.fn_resetear_password(202, '<NuevaClaveSegura>');` e invalidando sus tokens de sesión web. **No** se fuerza el reseteo masivo de los otros 241 usuarios porque el log demuestra fehacientemente que `SELECT * FROM public.usuario` falló y que `password_hash` **nunca fue leído**.
2. **Descarte fundamentado de las medidas erróneas propuestas por la IA:**
   - **No se apaga el servidor ni se restaura un backup:** El log demuestra con certeza completa (`log_statement = 'all'`) que todas las sentencias ejecutadas por el PID `[12492]` fueron de lectura (`SELECT`) o intentos fallidos (`ERROR`), sin ningún `INSERT`, `UPDATE`, `DELETE` ni `DDL` exitoso. Bajar la base en producción causaría una denegación de servicio autoinfligida sin justificación técnica.
   - **No se ejecuta `REVOKE rol_soporte FROM app_web`:** Como verificamos en la Parte A (`\du`), `app_web` no posee membresía en `rol_soporte`; la recomendación de la IA fue producto de confundir un dato de negocio con un rol del motor.
3. **Mitigación de exposición de datos personales (PII) leídos en la Fase 3:**
   - Como el atacante sí logró ejecutar `SELECT id, nombre, email, rol, fecha_alta FROM public.usuario`, tuvo acceso a la lista de nombres y correos electrónicos. Se revoca de `rol_app_lectura` el permiso `SELECT (id, nombre, email, rol, fecha_alta) ON public.usuario` para que `app_web` no pueda listar la tabla `usuario` directamente, encapsulando la consulta del perfil propio dentro de una función `fn_obtener_perfil_usuario(p_id BIGINT)` que devuelva como máximo 1 fila.
4. **Corrección preventiva en autenticación y auditoría:**
   - Se incorpora control de intentos fallidos (*rate limiting* / bloqueo temporal tras 5 intentos fallidos en 5 minutos) dentro de `fn_autenticar`, y se mantiene `log_statement = 'mod'` en operación normal para evitar que contraseñas pasadas por parámetro a funciones de autenticación queden escritas en texto plano en los archivos de log del servidor.
