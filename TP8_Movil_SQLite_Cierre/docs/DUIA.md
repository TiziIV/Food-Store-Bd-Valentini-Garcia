# DUIA — Declaración de Uso de IA

**Cátedra:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)  
**Trabajo Práctico N.º 8:** Food Store en la Feria: La Base de la Tablet y el Cierre de la Capa de Datos  
**Unidad:** Unidad 8 / Semanas 12 y 13  
**Integrantes:** Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)  
**Docente:** Sergio Neira  
**Herramientas:** Kiro (especificación EARS) y OpenCode / Asistente Terminal de IA  

---

## Parte A — Especificación de Requerimientos y Diseño (Kiro)

| Campo | Registro Documentado |
| :--- | :--- |
| **Herramienta** | Kiro (especificación formal de requisitos EARS) y OpenCode. |
| **Spec o prompt entregado** | "Formular requisitos en notación EARS estricta (WHEN ... THE SYSTEM SHALL ...) para sincronización offline de tablet en feria sin señal: detección de conflicto por precio, rechazo por falta de stock, rechazo por lápida de baja lógica, pre-aprobación por paridad e idempotencia ante reenvío." |
| **Qué propuso la IA** | Requisitos genéricos en lenguaje natural sin cumplir la cláusula condicional EARS y asumiendo confirmación de venta directa en SQLite. |
| **Qué se aceptó** | Estructuración en 6 requisitos formales EARS vinculados a los Casos C1, C2, C3, C4, C5, C6 y C7, con matrices de trazabilidad y diseño offline-first asimétrico. |
| **Qué se descartó y por qué** | Se descartó cualquier cláusula que asignara a la tablet la potestad de confirmar ventas definitivas o alterar inventario maestro, respetando la Regla de Oro (*"El móvil propone, el servidor dispone"*). |
| **Verificación realizada** | Revisión de sintaxis EARS y correspondencia unívoca de cada requisito con los casos de prueba ejecutables en SQLite. |

---

## Parte B — Esquema SQLite y Pruebas Transaccionales (Consigna 1)

| Campo | Registro Documentado |
| :--- | :--- |
| **Herramienta** | OpenCode (generación de DDL SQLite). |
| **Spec o prompt entregado** | "Generar schema_sqlite.sql con PRAGMA foreign_keys = ON; y las cuatro tablas en modo STRICT: producto_cache, pedido_borrador, item_borrador, cola_sync, más snapshot_servidor. Probar transacciones BEGIN...COMMIT y ROLLBACK, y casos C1 y C7." |
| **Qué propuso la IA** | Esquema con tipos permisivos `REAL` para importes y sin activar la restricción de claves foráneas por defecto de SQLite. |
| **Qué se aceptó** | Los nombres de entidades y la lógica de relación jerárquica pedido -> ítem -> producto. |
| **Qué se descartó y por qué** | Se descartó el tipo `REAL` reemplazándolo por `precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0)` para evitar imprecisiones de coma flotante. Se exigió la directiva `STRICT` en todas las tablas y `PRAGMA foreign_keys = ON;`. |
| **Verificación realizada** | Ejecución de `pruebas_sqlite.sql`: verificación de rollback exitoso (0 filas residuales), caso C1 (catálogo vendible) y caso C7 (captura de `CHECK constraint failed` por cantidad 0 y `FOREIGN KEY constraint failed` por producto inexistente). |

---

## Parte C — Sincronización, Semáforo y Simulación C2 a C6 (Consigna 2)

| Campo | Registro Documentado |
| :--- | :--- |
| **Herramienta** | OpenCode (generación de vista PostgreSQL, consulta del semáforo y simulador Python). |
| **Spec o prompt entregado** | "Crear v_snapshot_movil en PostgreSQL exportable a CSV. Diseñar semaforo.sql en SQLite que procese solo PENDIENTE con precedencia Rojo (falta stock, baja, no disponible) > Amarillo (precio distinto) > Verde (coincidencia). Simular casos C2 a C6." |
| **Qué propuso la IA** | Comparación booleana con enteros `1` y `0` sobre el CSV de PostgreSQL y triggers en SQLite para descontar stock local. |
| **Qué se aceptó** | La consulta CTE de agregación con `CASE WHEN` y `LEFT JOIN` a `snapshot_servidor`, y la actualización basada en precedencia. |
| **Qué se descartó y por qué** | Se descartaron los triggers de stock en la tablet (violación de la Regla de Oro). Se descartó la comparación `s.eliminado = 1` y se ajustó a `s.eliminado IN ('t', '1')` por el formato texto generado por `\copy` en PostgreSQL. Se descartó reevaluar solicitudes resueltas. |
| **Verificación realizada** | Ejecución de `simulador.py` generando `foodstore_movil.db`. Verificación en PostgreSQL con `COUNT(*)` de `Pedido` (200.003) y stock de `Producto` inalterados. |

---

## Parte D — Integración Arquitectónica y Code Review de la Cursada (Consigna 3)

| Campo | Registro Documentado |
| :--- | :--- |
| **Herramienta** | OpenCode / Asistente Terminal en rol Plan. |
| **Spec o prompt entregado** | "Auditar scripts acumulados de TP1 a TP7. Identificar oportunidades de optimización y evaluar sugerencias críticas. Mapear los 3 motores (PostgreSQL, MongoDB, SQLite) y plan de contingencia." |
| **Qué propuso la IA** | Sugirió eliminar el `FOR UPDATE` en concurrencia (TP2) para 'acelerar lecturas', crear índices redundantes en `Detalle_Pedido` (TP5), y dar permisos amplios `SELECT ON ALL TABLES` al rol cajero (TP7). |
| **Qué se aceptó** | El mapa de persistencia políglota definiendo Single Source of Truth, y la corrección de condiciones de trigger en TP6. |
| **Qué se descartó y por qué** | **DESCARTE FUNDAMENTADO 1:** La eliminación de `FOR UPDATE` se rechazó porque genera condiciones de carrera y sobreventas comprobadas empíricamente. **DESCARTE FUNDAMENTADO 2:** El índice en `Detalle_Pedido(id_pedido)` se rechazó por sobreindexación (ya cubierto por la PK). **DESCARTE FUNDAMENTADO 3:** Los permisos excesivos a cajero se rechazaron por violar confidencialidad de hashes en `usuario`. |
| **Verificación realizada** | Pruebas con `EXPLAIN ANALYZE`, sesiones concurrentes en PostgreSQL y comprobación de permisos con `SET ROLE`. |

---

## Declaración Ética y Compromiso de Autoría

Los integrantes abajo firmantes declaramos que la totalidad del código, consultas SQL, modelos de datos y documentación presentados en este Trabajo Práctico fueron revisados críticamente, comprendidos en profundidad y verificados empíricamente en motores de base de datos reales (PostgreSQL 18.3 y SQLite 3.45.3) antes de su versión final. Ninguna sugerencia de Inteligencia Artificial fue incorporada sin someterse a escrutinio técnico, prueba de laboratorio y descarte fundado cuando atentaba contra la integridad o seguridad del sistema.

* **Tiziano Valentini** — Comisión 2PRO4  
* **Juan Martin Garcia** — Comisión 2PRO4  
