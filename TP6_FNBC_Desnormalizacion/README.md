# TP6 - FNBC y Desnormalización Controlada

Unidad 4 - Base de Datos II. Parte 1: normalización de `control_lote_almacen` hasta FNBC. Parte 2: desnormalización controlada del reporte top 5 de categorías del día.

## Archivos

```text
TP6_FNBC_Desnormalizacion/
├── tp_fnbc_control_lote.sql
├── tp_desnormalizacion_top_categorias.sql
├── informe_fnbc_desnormalizacion.pdf
├── README.md
├── evidencias/     # Planes, capturas y salidas de ejecución
└── herramientas/   # Preparación de datos, medición y pruebas auxiliares
```

## Requisitos

PostgreSQL 16 y `psql`. La Parte 2 se ejecuta sobre una copia poblada de Food Store, con los scripts del proyecto aplicados en el orden indicado en el README raíz, incluyendo `TP5_Indices_Vistas/soft_delete.sql`. Las diferencias entre los nombres de columna de la consigna y el esquema del proyecto están documentadas en la sección 2.1 del informe.

La Parte 1 crea los maestros mínimos y las tablas de la extensión en el esquema `tp_u4_fnbc`. La Parte 2 usa `Pedido`, `Detalle_Pedido`, `Producto` y `Categoria` del esquema `public`. Ambos scripts incluyen la verificación de resultados.

## Cómo reproducir

Desde la raíz del repositorio, con una copia de trabajo y un respaldo previo:

```bash
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_fnbc_control_lote.sql

# Paso opcional para disponer de volumen de ventas en el día actual.
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/herramientas/tp_preparar_datos_hoy.sql

psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_desnormalizacion_top_categorias.sql
```

El preparador modifica `Pedido.fecha_hora` de los datos de prueba: usar exclusivamente sobre la copia de trabajo. Si se utiliza la vista materializada mensual de TP5, refrescarla después de cambiar fechas. Agregar host, puerto y usuario según la conexión.

## Evidencias y herramientas

`evidencias/` contiene las salidas de las dos partes, los planes antes/después, sus capturas, las repeticiones de las mediciones y los resultados de auditoría y pruebas. El informe presenta su análisis.

Para las verificaciones adicionales, después de instalar la Parte 2:

```bash
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/herramientas/pruebas_integridad.sql
python TP6_FNBC_Desnormalizacion/herramientas/verificar_concurrencia.py --db food_store_dev --user postgres
python TP6_FNBC_Desnormalizacion/herramientas/repetir_mediciones.py --db food_store_dev --user postgres --output TP6_FNBC_Desnormalizacion/evidencias/mediciones_nuevas.json
```

Los scripts Python requieren `psql` y aceptan `--host`, `--port` y `--psql`. Las pruebas reversibles pueden dejar huecos en las secuencias identity. `herramientas/revertir_desnormalizacion.sql` permite retirar la estructura redundante conservando las fuentes.

## Formato de entrega

Enlace al repositorio con los dos scripts SQL y el informe PDF. Las carpetas de evidencia y herramientas brindan respaldo para reproducir los resultados.
