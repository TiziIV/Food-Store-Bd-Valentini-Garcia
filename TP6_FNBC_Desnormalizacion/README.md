# TP U4 - FNBC y desnormalización: Food Store

## Organización

```text
TP6_FNBC_Desnormalizacion/
├── README.md
├── tp_fnbc_control_lote.sql
├── tp_desnormalizacion_top_categorias.sql
├── informe_fnbc_desnormalizacion.pdf
├── evidencias/      # Salidas originales, planes, capturas y mediciones
└── herramientas/    # Scripts auxiliares para reproducir y verificar
```

Los tres archivos pedidos por la consigna están en la raíz: los dos SQL y el PDF. El informe concentra el análisis; las carpetas auxiliares contienen evidencia completa y herramientas ejecutables.

## Ejecutar los entregables

PostgreSQL 16 y `psql`. Preparar una copia poblada según el README raíz del proyecto, incluyendo `soft_delete.sql`. La Parte 1 usa el esquema aislado `tp_u4_fnbc`; la Parte 2 usa las tablas reales en `public`. Generar un respaldo previo.

Desde la raíz del repositorio:

```bash
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_fnbc_control_lote.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/tp_desnormalizacion_top_categorias.sql
```

Agregar host, puerto y usuario según la conexión. Los scripts incluyen sus verificaciones y la reversión del patrón. Las pruebas con ROLLBACK pueden dejar huecos en las secuencias identity.

## Evidencias

| Archivos en `evidencias/` | Contenido |
|---|---|
| `salida_parte1.txt`, `salida_parte2.txt` | Ejecución completa de los entregables |
| `plan_antes.txt`, `plan_despues.txt` y `captura_plan_*.png` | Planes completos y sus capturas |
| `planes_mediciones.json`, `mediciones_resumen.txt` | Las 14 repeticiones y su resumen |
| `volumen_base.txt`, `preparacion_datos_hoy.txt` | Entorno y preparación de datos |
| `pruebas_integridad.txt`, `prueba_concurrencia.txt` | Verificaciones adicionales |
| `verificacion_reversibilidad.txt`, `verificacion_script_concurrencia.txt` | Restauración, reversión y ejecución del script auxiliar |

Las mediciones corresponden al 13/10/2026. Nuevas ejecuciones pueden dar otros tiempos y montos.

## Herramientas opcionales

Ejecutar únicamente sobre una copia de trabajo. Desde la raíz del repositorio:

```bash
# Si faltan ventas suficientes en el día actual: modifica fechas de prueba.
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/herramientas/tp_preparar_datos_hoy.sql

# Después de instalar la Parte 2:
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/herramientas/pruebas_integridad.sql
psql -X -v ON_ERROR_STOP=1 -d food_store_dev -f TP6_FNBC_Desnormalizacion/herramientas/medir_consultas.sql
python TP6_FNBC_Desnormalizacion/herramientas/verificar_concurrencia.py --db food_store_dev --user postgres
python TP6_FNBC_Desnormalizacion/herramientas/repetir_mediciones.py --db food_store_dev --user postgres --output mediciones_nuevas.json
```

Los scripts Python usan `psql` y aceptan `--host`, `--port` y `--psql`. Las pruebas concurrentes crean y eliminan sus propios registros de prueba. Si se utiliza la materializada mensual de TP5, refrescarla después de cambiar fechas con el preparador.

Para desinstalar el patrón de Parte 2, ejecutar `herramientas/revertir_desnormalizacion.sql`. Conserva los datos fuente y los triggers anteriores del proyecto.

## Entrega

Entregar el enlace al repositorio. Los artefactos principales están en la raíz de esta carpeta y las evidencias de soporte están separadas.
