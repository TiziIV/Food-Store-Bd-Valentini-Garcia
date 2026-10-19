# TP7 (Unidad 5) — Administración y Seguridad de Food Store: Roles, Auditoría, Incidentes y Protección de Datos Personales

**Asignatura:** Base de Datos II — Unidad 5: Administración y Seguridad (Semana 9)  
**Integrantes:** Tiziano Valentini y Juan Martin Garcia  
**Motor:** PostgreSQL 16+ (verificado en PostgreSQL 18.3)  
**Herramientas:** Kiro (especificación), OpenCode (asistente de terminal) y Git  

---

## Estructura del Entregable

Esta carpeta sigue exactamente la estructura consolidada exigida en la página 6 de la consigna de la Unidad 5:

```text
TP7_Seguridad_Roles_Auditoria/
├── sql/
│   ├── roles.sql                     # Parte A: Prerrequisitos, roles, permisos por columna y ALTER DEFAULT PRIVILEGES
│   ├── auditoria_test.sql            # Parte B: Activación de auditoría (ALTER SYSTEM) y secuencia de prueba
│   ├── simulacro_incidente.sql       # Parte C: Simulacro de fuerza bruta, lectura masiva y escalamiento fallido
│   └── usuario_anon.sql              # Parte D: Anonimización determinista y consultas de equivalencia
├── docs/
│   ├── kiro_roles_spec/
│   │   ├── requirements.md           # Parte A: Requerimientos y justificación en una oración por rol
│   │   └── design.md                 # Parte A: Arquitectura RBAC, matriz de permisos y salidas de \du / role_table_grants
│   ├── informe_auditoria.md          # Parte B: Parámetros configurados, análisis vs. pgaudit y permisos 0600/0640
│   ├── log_auditoria_prueba.txt      # Parte B: Fragmento de log real capturado en PostgreSQL
│   ├── log_simulacro_anonimizado.txt # Parte C: Fragmento de log del simulacro anonimizado antes de enviarlo a IA
│   ├── informe_incidente.md          # Parte C: Reconstrucción de IA, contraste crítico y decisión humana de contención
│   └── verificacion_equivalencia.md  # Parte D: Resultados agregados lado a lado (EXCEPT = 0 filas) y frontera de PII
├── BITACORA.md                       # Parte E: Bitácora obligatoria de 3 columnas y análisis crítico del proceso
└── README.md                         # Guía rápida de reproducción de la Unidad 5
```

---

## Cómo Reproducir la Unidad 5 Completa

Siguiendo el [`protocolo_seguridad.md`](../protocolo_seguridad.md) del repositorio, todos los scripts se ejecutan sobre una copia de trabajo aislada (`food_store_dev`):

```bash
# 1. Crear copia de trabajo a partir de la base poblada del proyecto
createdb -U postgres -T food_store_tp6 food_store_dev

# 2. Parte A — Roles, funciones de seguridad y mínimo privilegio
psql -X -v ON_ERROR_STOP=1 -U postgres -d food_store_dev -f TP7_Seguridad_Roles_Auditoria/sql/roles.sql

# 3. Parte B — Activación de auditoría y secuencia de operaciones de prueba
psql -X -h 127.0.0.1 -U postgres -d food_store_dev -f TP7_Seguridad_Roles_Auditoria/sql/auditoria_test.sql

# 4. Parte C — Laboratorio de simulacro de incidente y bloqueo de escalamiento
psql -X -h 127.0.0.1 -U postgres -d food_store_dev -f TP7_Seguridad_Roles_Auditoria/sql/simulacro_incidente.sql

# 5. Parte D — Construcción determinista de usuario_anon y verificación de equivalencia
psql -X -v ON_ERROR_STOP=1 -U postgres -d food_store_dev -f TP7_Seguridad_Roles_Auditoria/sql/usuario_anon.sql
```
