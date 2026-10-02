# TP6 — FNBC y Desnormalización Controlada

Unidad 4 — Base de Datos II. Cuarta unidad del proyecto Food Store: Parte 1
(llevar `control_lote_almacen` a FNBC) y Parte 2 (desnormalización controlada
del reporte «top 5 categorías del día»).

```
TP6_FNBC_Desnormalizacion/
├── tp_fnbc_control_lote.sql                 (Parte 1: esquema, anomalías, descomposición, vista, migración)
├── tp_preparar_datos_hoy.sql                (Parte 2, paso previo: volumen de pedidos en el día actual)
├── tp_desnormalizacion_top_categorias.sql   (Parte 2: antes, estructura, después, auditoría, pruebas)
├── informe_fnbc_desnormalizacion.md / .pdf  (informe técnico completo)
├── salida_parte1.txt                        (salida real de ejecución de la Parte 1)
├── salida_parte2.txt                        (salida real de ejecución de la Parte 2 y mediciones)
├── volumen_base.txt                         (volumen real de la base de pruebas)
└── README.md
```

## Requisitos

PostgreSQL 16+ y `psql`. La Parte 2 usa el esquema real del proyecto
(`Pedido`, `Detalle_Pedido`, `Producto`, `Categoria`) y necesita
`TP5_Indices_Vistas/soft_delete.sql` aplicado. Las diferencias entre la
consulta de la consigna y el esquema real están tabuladas en el encabezado del
script y en la sección 2.1 del informe.

## Cómo reproducir

```bash
# Parte 1 — corre solo (crea lote/deposito/usuario mínimos si no existen)
psql -d food_store -f TP6_FNBC_Desnormalizacion/tp_fnbc_control_lote.sql

# Parte 2 — sobre la copia de Food Store ya poblada (orden completo en el README raíz)
psql -d food_store -f TP6_FNBC_Desnormalizacion/tp_preparar_datos_hoy.sql
psql -d food_store -f TP6_FNBC_Desnormalizacion/tp_desnormalizacion_top_categorias.sql > TP6_FNBC_Desnormalizacion/salida_parte2.txt
```

`tp_preparar_datos_hoy.sql` modifica `Pedido.fecha_hora` (datos de prueba):
usar solo sobre la copia de trabajo (`protocolo_seguridad.md`).
