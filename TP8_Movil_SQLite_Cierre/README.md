# Trabajo Práctico N.º 8: Food Store en la Feria
## La Base de la Tablet y el Cierre de la Capa de Datos

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN FRM)  
**Integrantes:** Tiziano Valentini y Juan Martin Garcia  
**Comisión:** 2PRO4 — Ciclo Lectivo 2026  
**Docente:** Sergio Neira  
**Herramientas:** PostgreSQL 16+ (PostgreSQL 18.3), SQLite 3.37+ (SQLite 3.45.3), Python 3.12, Kiro  

---

## 1. Estructura del Proyecto

El entregable respeta estrictamente la jerarquía oficial exigida por la cátedra:

```
TP8_Movil_SQLite_Cierre/
├── README.md                      # Instrucciones de recreación y guion de defensa de 10 minutos
├── movil/
│   ├── schema_sqlite.sql          # Consigna 1.b: DDL SQLite con STRICT y PRAGMA foreign_keys = ON;
│   ├── pruebas_sqlite.sql         # Consigna 1.c: Transacciones COMMIT/ROLLBACK, Casos C1 y C7
│   ├── vista_postgres_snapshot.sql# Consigna 2.a: Vista v_snapshot_movil en PostgreSQL
│   ├── servidor_snapshot.csv      # Consigna 2.a: Exportación CSV del catálogo con booleanos t/f
│   ├── semaforo.sql               # Consigna 2.b: Motor de resolución offline con precedencia estricta
│   ├── simulador.py               # Orquestador automatizado y generador de la base binaria
│   └── foodstore_movil.db         # Base binaria real de SQLite 3 poblada y testeada
└── docs/
    ├── informe.md                 # Informe técnico completo (1.a, 2.c, 3.a, 3.b, 3.c)
    ├── kiro/
    │   ├── requirements.md        # Consigna 4.a: 6 requisitos en notación EARS formal
    │   ├── design.md              # Consigna 4.a: Arquitectura offline-first y diseño del semáforo
    │   └── tasks.md               # Consigna 4.a: Plan secuencial de tareas
    ├── bitacora_ia.md             # Consigna 4.b: 4 entradas de IA con descartes técnicos fundados
    └── DUIA.md                    # Consigna 4.b: Declaración institucional de Uso de IA
```

---

## 2. Instrucciones para Recrear Todo Desde Cero

### Paso 1: Configuración en PostgreSQL (Servidor Central)
1. Abrir terminal o consola `psql` conectado a la base de pruebas:
   ```bash
   psql -U postgres -d food_store_dev -f TP8_Movil_SQLite_Cierre/movil/vista_postgres_snapshot.sql
   ```
2. Exportar la instantánea hacia el CSV requerido por la tablet:
   ```bash
   psql -U postgres -d food_store_dev -c "\copy (SELECT * FROM v_snapshot_movil WHERE id <= 10 ORDER BY id) TO 'TP8_Movil_SQLite_Cierre/movil/servidor_snapshot.csv' WITH (FORMAT csv, HEADER true);"
   ```

### Paso 2: Ejecución Transaccional y Pruebas C1 y C7 en SQLite
Para verificar de forma interactiva las restricciones de integridad y aislamiento:
```bash
# Mediante Python (utilizando el motor nativo sqlite3):
python -c "
import sqlite3
con = sqlite3.connect('test_temp.db')
con.execute('PRAGMA foreign_keys = ON;')
with open('TP8_Movil_SQLite_Cierre/movil/schema_sqlite.sql', encoding='utf-8') as f:
    con.executescript(f.read())
with open('TP8_Movil_SQLite_Cierre/movil/pruebas_sqlite.sql', encoding='utf-8') as f:
    con.executescript(f.read())
print('Pruebas transaccionales C1 y C7 superadas con éxito.')
con.close()
"
```

### Paso 3: Simulación Integral del Semáforo (Casos C2 a C6) y Generación de la Base Binaria
Ejecutar el simulador orquestador:
```bash
python TP8_Movil_SQLite_Cierre/movil/simulador.py
```
Este script:
1. Recrea `movil/foodstore_movil.db` aplicando `schema_sqlite.sql`.
2. Importa `servidor_snapshot.csv` en `snapshot_servidor` y carga `producto_cache`.
3. Simula paso a paso el Caso C2 (conflicto y reintento aprobado), C3 (quiebre de stock), C4 (baja lógica / lápida), C5 (aprobación) y C6 (idempotencia y PK duplicada).
4. Aplica `semaforo.sql` y emite por consola las salidas reales.

### Paso 4: Comprobación de Invarianza en PostgreSQL
Verificar que la tablet no alteró ventas ni stock en el servidor:
```bash
psql -U postgres -d food_store_dev -c "SELECT COUNT(*) AS total_pedidos FROM Pedido; SELECT id_producto, nombre_producto, stock FROM Producto WHERE id_producto IN (1, 2, 3, 4, 7) ORDER BY id_producto;"
```

---

## 3. Guion de Ensayo para la Defensa de 10 Minutos

Estructura diseñada para responder las preguntas de la cátedra con precisión técnica:

### Minuto 0:00 a 3:00 — Bloque 1: El Mapa de la Capa de Datos (3 Motores)
* **Objetivo:** Demostrar visión global de la persistencia políglota de Food Store.
* **Discurso:**
  - *"Buenos días profesor. En el cierre de la capa de datos de Food Store integramos tres motores complementarios con fronteras de autoridad bien delimitadas:*
  - *1. **PostgreSQL 16+**: Es nuestro núcleo transaccional OLTP y la **única fuente de verdad (*Single Source of Truth*)**. Manda sobre las ventas confirmadas, el inventario maestro con bloqueo pesimista y el control de accesos RBAC.*
  - *2. **MongoDB** (Unidad 7): Es nuestra capa documental desnormalizada de solo lectura. Almacena pedidos embebidos con sus líneas de detalle para optimizar consultas de reporting y aggregations analíticas sin sobrecargar el motor relacional.*
  - *3. **SQLite 3.37+ STRICT** (Unidad 8): Es la base embebida en la tablet del food truck. Opera desconectada en la feria bajo una regla de oro innegociable: **El móvil propone, el servidor dispone**. La tablet solo consulta un catálogo cacheado y confecciona borradores. Jamás modifica stock ni confirma ventas reales."*

### Minuto 3:00 a 7:00 — Bloque 2: Demostración en Vivo de la Sincronización (Caso C2 o C4)
* **Objetivo:** Mostrar el funcionamiento real del semáforo y la precedencia en SQLite.
* **Acción en Vivo:** Ejecutar el simulador o abrir `foodstore_movil.db` y mostrar `cola_sync`.
* **Discurso:**
  - *"Aquí podemos ver en vivo el comportamiento del semáforo ante el **Caso C2**. El operador cargó una Muzzarella a $1.050,00. Al llegar la nueva instantánea del servidor donde la pizza subió a $1.200,00, el semáforo evaluó la cola y marcó `CONFLICTO`, indicando el desfasaje en el campo `motivo`. No rechazó el pedido porque había stock suficiente y el producto estaba activo.*
  - *Cuando el cliente en el mostrador aceptó la actualización de tarifa, la tablet actualizó el borrador local y despachó una nueva solicitud con un nuevo UUID. El semáforo corrió nuevamente y emitió `SIMULADO_APROBADO`.*
  - *Asimismo, demostramos el **Caso C6 de Idempotencia**: ante un reenvío por red inestable con el mismo UUID, SQLite disparó un error de clave primaria duplicada, y al correr el semáforo, la cláusula `WHERE estado = 'PENDIENTE'` garantizó que las solicitudes ya resueltas fueran 100% invariantes."*

### Minuto 7:00 a 10:00 — Bloque 3: Code Review con IA y Descarte Crítico Fundamentado
* **Objetivo:** Evidenciar lectura crítica, solvencia técnica y que no se aceptó código a ciegas.
* **Discurso:**
  - *"A lo largo de la cursada sometimos a revisión técnica todas las sugerencias de la IA. El hallazgo más crítico que **descartamos con fundamento técnico sólido** ocurrió al auditar `restricciones.sql` de la Unidad 1 (TP2).*
  - *La IA propuso eliminar el bloqueo `FOR UPDATE` en la función de validación de stock `fn_validar_stock_pedido()`, alegando que 'reducía los bloqueos de lectura y mejoraba la concurrencia'.*
  - *Hicimos la comprobación experimental en el laboratorio abriendo dos sesiones concurrentes bajo `READ COMMITTED`: sin `FOR UPDATE`, ambas sesiones leyeron el mismo stock disponible (2 unidades) y ambas confirmaron pedidos por 2 unidades, vendiendo 4 unidades y dejando el stock en negativo o generando quiebres no controlados.*
  - *Con `FOR UPDATE`, la segunda transacción esperó a que la primera finalice su descuento, releyó el stock real en 0 y arrojó limpiamente la excepción de negocio 'Stock insuficiente'. Descartamos la sugerencia de la IA porque sacrificaba consistencia financiera por latencia superficial.*
  - *Quedamos a disposición para cualquier consulta adicional."*
