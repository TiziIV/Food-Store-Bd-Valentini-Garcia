# Bitácora de Uso de Inteligencia Artificial (TP8)

**Proyecto:** Food Store en la Feria — Base Móvil SQLite y Cierre de la Capa de Datos  
**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)  
**Integrantes:** Tiziano Valentini y Juan Martin Garcia  
**Comisión:** 2PRO4 — Ciclo Lectivo 2026  
**Docente:** Sergio Neira  
**Herramientas de IA Utilizadas:** Kiro (especificación EARS) y OpenCode / Asistente Terminal  

---

## Entrada 1: Tipado de Precios y Esquema en SQLite

* **Fecha:** 2026-11-02
* **Prompt Enviado a la IA:**
  > *"Generá el script DDL para la tablet SQLite con las tablas producto_cache, pedido_borrador, item_borrador y cola_sync. Incluí precios con dos decimales y asegurá que no se puedan cargar valores negativos."*
* **Propuesta de la IA:**
  La IA propuso columnas de precio con tipo `REAL` o `DECIMAL(10,2)` y no incluyó la directiva `STRICT` en los `CREATE TABLE`. Además, no incluyó la activación de claves foráneas con `PRAGMA foreign_keys = ON;`.
* **Qué se aceptó:**
  La estructura general de nombres de tablas y las relaciones básicas mediante claves foráneas.
* **Qué se descartó y por qué:**
  1. **Se descartó `REAL` / `DECIMAL` en SQLite:** SQLite por defecto tiene afinidad de tipos dinámica (*Type Affinity*) y almacena `REAL` como coma flotante binaria IEEE 754 de 64 bits. En cálculos comerciales y comparaciones de igualdad en el semáforo (`visto = actual`), los redondeos binarios provocan falsos conflictos (ej. `10.50` vs `10.500000000000001`). Se reemplazó estrictamente por **centavos enteros (`INTEGER CHECK (precio_centavos >= 0)`)**.
  2. **Se exigió `STRICT` y `PRAGMA foreign_keys = ON;`:** Sin `STRICT`, SQLite permite insertar cadenas en columnas enteras. Se forzó `STRICT` en las 5 tablas y la activación de FKs en la primera línea.
* **Verificación en Base:**
  Se probó insertar una cadena `'diez'` en `precio_centavos`, arrojando error de casteo estricto (`cannot store TEXT value in INT column`).

---

## Entrada 2: Sincronización y Regla de Oro ("El móvil propone, el servidor dispone")

* **Fecha:** 2026-11-02
* **Prompt Enviado a la IA:**
  > *"Creá un trigger en SQLite para que cada vez que se agregue un item_borrador o se apruebe una solicitud en cola_sync, se descuente automáticamente el stock de producto_cache para reflejar la venta en la tablet."*
* **Propuesta de la IA:**
  La IA escribió un `CREATE TRIGGER trg_descontar_stock_tablet AFTER INSERT ON item_borrador ... UPDATE producto_cache SET stock_visto = stock_visto - NEW.cantidad ...` y sugirió considerar `SIMULADO_APROBADO` como una venta cerrada.
* **Qué se aceptó:**
  Nada de la lógica propuesta de triggers de stock.
* **Qué se descartó y por qué (DESCARTE CRÍTICO):**
  **DESCARTADO TOTALMENTE POR VIOLAR LA REGLA DE ORO DEL TP**. La consigna del docente es taxativa:
  > *"El móvil propone, el servidor dispone. La tablet nunca cambia el stock ni el precio del servidor, ni confirma ventas: SIMULADO_APROBADO no es una venta."*  
  Si la tablet descontara stock localmente de forma autónoma sin confirmación de PostgreSQL, dos tablets en la feria generarían stock fantasma o sobreventas que colisionarían al sincronizar. El stock solo se modifica en PostgreSQL mediante la transacción oficial con `FOR UPDATE`. En SQLite, `stock_visto` es de solo lectura y representa una foto pasada.
* **Verificación en Base:**
  Se verificó que `producto_cache` no tenga ningún trigger de modificación y que el stock de PostgreSQL permanezca invariante tras todas las simulaciones.

---

## Entrada 3: Manejo de Booleanos en Importación CSV (psql -> SQLite)

* **Fecha:** 2026-11-02
* **Prompt Enviado a la IA:**
  > *"Diseñá la consulta SQL del semáforo para comparar item_borrador con snapshot_servidor y marcar RECHAZADO si el producto está eliminado o no disponible."*
* **Propuesta de la IA:**
  La IA propuso: `WHERE s.eliminado = 1 OR s.disponible = 0`.
* **Qué se aceptó:**
  El uso de `LEFT JOIN` y la función agregada con `CASE WHEN` para evaluar causales de rechazo antes que de conflicto.
* **Qué se descartó y por qué:**
  Se descartó comparar directamente contra los enteros `1` y `0`. Al exportar desde PostgreSQL mediante `\copy TO CSV`, los campos booleanos se escriben como literales `'t'` y `'f'`. En la tabla `snapshot_servidor` de SQLite, esos valores se importan como cadenas de texto. Comparar `s.eliminado = 1` en SQLite fallaba silenciosamente, tratando productos eliminados como vigentes. Se corrigió contemplando la condición: `s.eliminado IN ('t', '1')` y `s.disponible IN ('f', '0')`.
* **Verificación en Base:**
  En el Caso C4, la comprobación con `'t'` detectó con éxito la baja lógica del producto 7, marcándolo en `RECHAZADO`.

---

## Entrada 4: Idempotencia y Prevención de Duplicados en Reenvío

* **Fecha:** 2026-11-02
* **Prompt Enviado a la IA:**
  > *"¿Cómo aseguramos que si una tablet pierde conexión y reenvía el borrador varias veces no se dupliquen las solicitudes en cola_sync ni se revalúe el semáforo?"*
* **Propuesta de la IA:**
  La IA propuso vaciar la tabla `cola_sync` antes de cada sincronización (`DELETE FROM cola_sync;`) o hacer un `INSERT OR REPLACE INTO cola_sync`.
* **Qué se aceptó:**
  La necesidad de filtrar por `solicitud_uuid`.
* **Qué se descartó y por qué:**
  Se descartó `DELETE FROM cola_sync` o `INSERT OR REPLACE`. Borrar la cola destruye la auditoría de solicitudes previas y sobrescribir con `OR REPLACE` puede reabrir a `PENDIENTE` una solicitud que ya había sido diagnosticada con `CONFLICTO` o `RECHAZADO`. Se implementó la solución arquitectónicamente correcta:
  1. `solicitud_uuid TEXT PRIMARY KEY` en `cola_sync`: el intento de reenvío falla limpiamente por violación de clave primaria.
  2. El semáforo solo procesa `WHERE estado = 'PENDIENTE'`: las solicitudes previamente evaluadas son matemáticamente invariantes ante sucesivas ejecuciones del motor.
* **Verificación en Base:**
  Ejecución del Caso C6, donde la repetición arrojó `UNIQUE constraint failed` y la solicitud previa retuvo su estado `SIMULADO_APROBADO`.
