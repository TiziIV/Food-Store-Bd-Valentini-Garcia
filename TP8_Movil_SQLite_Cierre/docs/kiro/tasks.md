# Lista de Tareas de Implementación (Tasks) — TP8

**Proyecto:** Food Store en la Feria — Base Móvil SQLite y Sincronización Offline  
**Equipo:** Tiziano Valentini y Juan Martin Garcia  
**Comisión:** 2PRO4 — Cátedra Base de Datos II (Ciclo Lectivo 2026)  
**Docente:** Sergio Neira  

---

## Tareas Planificadas para Ejecución

- [x] **TASK-01: Especificación Kiro y Notación EARS (Consigna 4.a)**
  - Redactar `requirements.md` con 6 requisitos funcionales rigurosos en sintaxis EARS (`WHEN ... THE SYSTEM SHALL ...`), enlazados a los casos C1 a C7.
  - Documentar `design.md` con arquitectura de sincronización asimétrica, esquema STRICT, lógica del semáforo y política de centavos enteros.
  - Generar `tasks.md` con el desglose secuencial del trabajo.

- [x] **TASK-02: Esquema SQLite de la Tablet (Consigna 1.b)**
  - Crear `movil/schema_sqlite.sql` iniciando con `PRAGMA foreign_keys = ON;`.
  - Definir con `STRICT` las 4 tablas obligatorias: `producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`.
  - Definir la tabla `snapshot_servidor` para recibir el lote de datos CSV del servidor central.
  - Configurar las restricciones `CHECK` de cantidades positivas, precios enteros no negativos y dominios cerrados de estados y formas de pago.

- [x] **TASK-03: Pruebas Transaccionales y Casos C1 y C7 en SQLite (Consigna 1.c)**
  - Escribir `movil/pruebas_sqlite.sql`.
  - Demostrar una transacción de guardado completo con `BEGIN ... COMMIT` (`pedido_borrador` + `item_borrador` + `cola_sync`).
  - Demostrar una transacción abortada con `ROLLBACK` y verificar que la base no conserva registros huérfanos.
  - Ejecutar el **Caso C1**: consulta local de catálogo disponible offline (`WHERE disponible = 1 AND eliminado = 0 AND stock_visto > 0`).
  - Ejecutar el **Caso C7**: probar intento de inserción con `cantidad = 0` (falla por `CHECK`) y con `producto_id` inexistente (falla por `FOREIGN KEY`), verificando que no se alteran las tablas.

- [x] **TASK-04: Instantánea de Servidor PostgreSQL y Exportación CSV (Consigna 2.a)**
  - Escribir `movil/vista_postgres_snapshot.sql` definiendo `v_snapshot_movil` sobre la base de producción `food_store_dev`.
  - Convertir `precio_actual` a `precio_centavos` con `ROUND(precio_actual * 100)::INT`.
  - Mapear banderas de vigencia (`disponible` y `eliminado`).
  - Exportar `movil/servidor_snapshot.csv` con 10 productos reales de Food Store.
  - Importar el CSV en `snapshot_servidor` y alimentar `producto_cache` registrando `fecha_copia`.

- [x] **TASK-05: Motor del Semáforo de Sincronización (Consigna 2.b)**
  - Desarrollar `movil/semaforo.sql` en SQLite.
  - Diseñar la consulta con `LEFT JOIN` de `item_borrador` a `snapshot_servidor` y agregación por solicitud.
  - Implementar la precedencia exacta:
    1. **Rojo (`RECHAZADO`)**: producto no encontrado, baja lógica (`eliminado = 't'`), deshabilitado (`disponible = 'f'`) o quiebre de stock (`cantidad > stock`).
    2. **Amarillo (`CONFLICTO`)**: paridad de stock y vigencia, pero discrepancia de precio (`precio_visto <> precio_actual`).
    3. **Verde (`SIMULADO_APROBADO`)**: paridad total.
  - Restringir la ejecución exclusivamente a solicitudes con `estado = 'PENDIENTE'`.

- [x] **TASK-06: Simulación y Captura de Evidencias de Casos C2 a C6 (Consigna 2.c)**
  - **Caso C2**: Borrador con precio desactualizado -> Semáforo da `CONFLICTO`. Cliente acepta precio -> reintento con nuevo UUID da `SIMULADO_APROBADO`.
  - **Caso C3**: Borrador solicitando más stock del disponible -> Semáforo da `RECHAZADO`.
  - **Caso C4**: Borrador con producto dado de baja lógica en el servidor (`eliminado = 't'`) -> Semáforo da `RECHAZADO`. Recarga de catálogo oculta el producto pero preserva la lápida en la base.
  - **Caso C5**: Borrador con datos perfectamente alineados al servidor -> Semáforo da `SIMULADO_APROBADO`.
  - **Caso C6**: Intento de reenviar el mismo `solicitud_uuid` -> Falla por clave primaria duplicada. Repetición del semáforo no altera solicitudes ya procesadas.
  - Comprobación final en PostgreSQL: verificar que `COUNT(*)` de `Pedido` y el `stock` de `Producto` se mantuvieron 100% inalterados.
  - Generar y consolidar la base binaria `movil/foodstore_movil.db`.

- [x] **TASK-07: Integración Arquitectónica y Auditoría de Cursada (Consigna 3)**
  - **3.a**: Redactar la matriz comparativa de los tres motores (PostgreSQL 16, MongoDB U7, SQLite U8), definiendo dominios de almacenamiento y Single Source of Truth.
  - **3.b**: Formular el plan de mantenimiento: estrategia de respaldos, protocolo de invalidación ante restauración de backup viejo y periodicidad de auditoría para `rol_soporte`.
  - **3.c**: Realizar code review cruzado con IA de los scripts de la cursada (`TP2`, `TP5`, `TP6`, `TP7`), documentando 4 hallazgos técnicos reales y al menos 1 hallazgo **DESCARTADO** con fundamento técnico sólido.

- [x] **TASK-08: Documentación de Entrega, Bitácora, DUIA y Defensa (Consignas 4.b, 4.c y Cierre)**
  - Redactar `docs/informe.md` estructurado y acotado (máximo 6 páginas) conteniendo 1.a, 2.c, 3.a, 3.b y 3.c con todas las salidas reales capturadas.
  - Completar `docs/bitacora_ia.md` con 4 registros exhaustivos de prompts, propuestas, aceptaciones y descartes.
  - Redactar `docs/DUIA.md` formal conforme al formato institucional de la cátedra.
  - Crear `README.md` con instrucciones de replicación desde cero y guion estructurado para la defensa oral de 10 minutos.
  - Realizar los 4 commits atómicos en Git con el co-author obligatorio y asignar el tag `tp8`.
