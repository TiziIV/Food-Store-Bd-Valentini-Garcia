# Requisitos del Sistema: Base Móvil Offline y Sincronización (TP8)

**Proyecto:** Food Store en la Feria — Base Móvil SQLite y Sincronización Offline  
**Equipo:** Tiziano Valentini y Juan Martin Garcia  
**Comisión:** 2PRO4 — Cátedra Base de Datos II (Ciclo Lectivo 2026)  
**Docente:** Sergio Neira  
**Metodología:** Easy Approach to Requirements Syntax (EARS)  

---

## 1. Contexto y Filosofía Operativa

En el contexto de Food Store operando en un food truck en una feria gastronómica sin conectividad a Internet, la tablet del punto de venta debe permitir la consulta del catálogo y la confección transaccional de pedidos en modo estrictamente offline. 

Bajo la **Regla de Oro** del proyecto:
> *"El móvil propone, el servidor dispone."*  
> La tablet solo consulta y arma borradores. El precio definitivo, el stock real y la confirmación de ventas son potestad exclusiva de PostgreSQL. `SIMULADO_APROBADO` es un estado de pre-aprobación en la tablet ante una instantánea del servidor, nunca una venta consumada.

---

## 2. Requisitos Funcionales en Notación EARS Estricta

### REQ-01: Detección de Discrepancia de Precios (Conflicto)
* **EARS:** `WHEN` una solicitud de sincronización en estado `PENDIENTE` contiene un ítem cuyo `precio_centavos_visto` difiere del `precio_centavos` registrado en `snapshot_servidor` y no existen causales de quiebre de stock ni baja de producto, `THE SYSTEM SHALL` marcar el estado de la solicitud en `cola_sync` como `CONFLICTO` y registrar el motivo detallando la diferencia de tarifa detectada.
* **Caso de Prueba Vinculado:** **Caso C2** (Cambio de precio en el servidor tras confeccionar el borrador; luego actualización consentida por el cliente y reevaluación a `SIMULADO_APROBADO`).

### REQ-02: Rechazo por Quiebre o Insuficiencia de Stock
* **EARS:** `WHEN` una solicitud de sincronización en estado `PENDIENTE` incluye una cantidad solicitada que supera el stock disponible en `snapshot_servidor` para alguno de sus ítems, `THE SYSTEM SHALL` marcar el estado de la solicitud en `cola_sync` como `RECHAZADO` e indicar en el motivo el producto que causó el desabastecimiento.
* **Caso de Prueba Vinculado:** **Caso C3** (Borrador por mayor cantidad de unidades que las existentes en el servidor).

### REQ-03: Rechazo por Baja Lógica de Producto (Lápida / Tombstone)
* **EARS:** `WHEN` una solicitud de sincronización en estado `PENDIENTE` contiene un producto cuya marca de baja lógica `eliminado` en `snapshot_servidor` es verdadera (`'t'` o `1`) o cuyo flag `disponible` es falso (`'f'` o `0`), `THE SYSTEM SHALL` marcar el estado de la solicitud en `cola_sync` como `RECHAZADO` y documentar en el motivo que el producto no está habilitado para la venta.
* **Caso de Prueba Vinculado:** **Caso C4** (Borrador con producto vigente que posteriormente recibe baja lógica en el servidor; el producto permanece en la base como lápida pero se excluye de las ventas).

### REQ-04: Pre-aprobación por Coincidencia Total de Catálogo
* **EARS:** `WHEN` todos los ítems de una solicitud de sincronización en estado `PENDIENTE` existen en `snapshot_servidor`, están habilitados (`disponible = 't'`, `eliminado = 'f'`), cuentan con stock suficiente (`cantidad <= stock`) y coinciden exactamente en precio (`precio_centavos_visto = precio_centavos`), `THE SYSTEM SHALL` actualizar el estado de la solicitud en `cola_sync` a `SIMULADO_APROBADO` con motivo de conformidad.
* **Caso de Prueba Vinculado:** **Caso C5** (Borrador sin alteraciones respecto al servidor) y **Caso C1** (Consulta local autónoma del catálogo vigente `WHERE disponible = 1 AND eliminado = 0 AND stock_visto > 0`).

### REQ-05: Garantía de Idempotencia y Prevención de Duplicados
* **EARS:** `WHEN` la tablet intenta insertar en `cola_sync` una solicitud con un `solicitud_uuid` ya existente o cuando el semáforo se ejecuta sobre una solicitud cuyo estado es distinto de `PENDIENTE`, `THE SYSTEM SHALL` rechazar la inserción por violación de clave primaria y omitir su reevaluación en el semáforo, manteniendo el estado final previo inalterado.
* **Caso de Prueba Vinculado:** **Caso C6** (Reenvío de solicitud con idéntico UUID; control de clave primaria e invariancia del estado final en el semáforo).

### REQ-06: Integridad Transaccional y Tipado Estricto en SQLite
* **EARS:** `WHEN` se ejecuta una transacción de carga de borrador (`pedido_borrador`, `item_borrador`, `cola_sync`) con datos que violan las restricciones de dominio (`cantidad <= 0`, `precio_centavos < 0`) o referencias a productos inexistentes, `THE SYSTEM SHALL` abortar la operación mediante error de restricción (`CHECK` o `FOREIGN KEY`), revertir la transacción sin dejar registros huérfanos y mantener la base en estado consistente.
* **Caso de Prueba Vinculado:** **Caso C7** (Inserción inválida con cantidad 0 y FK inexistente, demostrando rollback automático y limpieza de tablas).

---

## 3. Matriz de Trazabilidad de Requisitos

| ID Requisito | Cláusula EARS Resumida | Tabla Principal | Caso de Prueba | Criterio de Éxito |
| :--- | :--- | :--- | :--- | :--- |
| **REQ-01** | `WHEN precio_visto <> precio_actual` | `cola_sync`, `item_borrador` | **C2** | Estado `CONFLICTO`; reintento con precio actualizado da `SIMULADO_APROBADO`. |
| **REQ-02** | `WHEN cantidad > stock` | `cola_sync`, `item_borrador` | **C3** | Estado `RECHAZADO` con mensaje explicativo de falta de stock. |
| **REQ-03** | `WHEN eliminado = 't' OR disponible = 'f'` | `cola_sync`, `item_borrador` | **C4** | Estado `RECHAZADO`; recarga de caché excluye el producto de la oferta. |
| **REQ-04** | `WHEN paridad_total = TRUE` | `cola_sync`, `producto_cache` | **C1 / C5** | C1 lista catálogo offline; C5 marca `SIMULADO_APROBADO`. |
| **REQ-05** | `WHEN solicitud_uuid DUPLICADO` | `cola_sync` | **C6** | Error `PRIMARY KEY constraint failed`; semáforo ignora procesados. |
| **REQ-06** | `WHEN cantidad <= 0 OR fk_invalida` | `item_borrador` | **C7** | Error `CHECK constraint failed` / `FOREIGN KEY failed`; 0 filas basura. |
