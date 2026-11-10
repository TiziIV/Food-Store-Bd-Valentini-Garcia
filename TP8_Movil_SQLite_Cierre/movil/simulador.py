#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulador.py — Orquestador de Sincronización y Simulación de Casos C2 a C6
Trabajo Práctico N.º 8 — Consigna 2
Cátedra: Base de Datos II — Ciclo Lectivo 2026
Integrantes: Tiziano Valentini y Juan Martin Garcia (Comisión 2PRO4)
Motor: SQLite 3.37+
"""

import os
import csv
import sqlite3

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "foodstore_movil.db")
SCHEMA_SQL = os.path.join(BASE_DIR, "schema_sqlite.sql")
SEMAFORO_SQL = os.path.join(BASE_DIR, "semaforo.sql")
SNAPSHOT_CSV = os.path.join(BASE_DIR, "servidor_snapshot.csv")


def get_db():
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON;")
    return con


def inicializar_base():
    print("=" * 80)
    print("1. INICIALIZANDO BASE DE DATOS MÓVIL SQLITE (STRICT)...")
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    con = get_db()
    with open(SCHEMA_SQL, "r", encoding="utf-8") as f:
        con.executescript(f.read())
    
    print("-> Tablas creadas con éxito: producto_cache, pedido_borrador, item_borrador, cola_sync, snapshot_servidor")
    con.close()


def cargar_snapshot_inicial(fecha_copia="2026-11-02T18:00:00Z"):
    print("=" * 80)
    print(f"2. IMPORTANDO INSTANTÁNEA DEL SERVIDOR (servidor_snapshot.csv) - Fecha copia: {fecha_copia}")
    con = get_db()
    
    con.execute("DELETE FROM snapshot_servidor;")
    with open(SNAPSHOT_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        filas = []
        for r in reader:
            filas.append((
                int(r["id"]),
                r["nombre"],
                int(r["precio_centavos"]),
                int(r["stock"]),
                r["disponible"],
                r["eliminado"]
            ))
        con.executemany(
            "INSERT INTO snapshot_servidor (id, nombre, precio_centavos, stock, disponible, eliminado) VALUES (?, ?, ?, ?, ?, ?);",
            filas
        )
    
    # Alimentar producto_cache desde snapshot_servidor
    con.execute("DELETE FROM producto_cache;")
    con.execute("""
        INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
        SELECT 
            id,
            nombre,
            precio_centavos,
            stock,
            CASE WHEN disponible IN ('t', '1') THEN 1 ELSE 0 END,
            CASE WHEN eliminado IN ('t', '1') THEN 1 ELSE 0 END,
            ?
        FROM snapshot_servidor;
    """, (fecha_copia,))
    con.commit()
    
    cur = con.cursor()
    cur.execute("SELECT COUNT(*) FROM snapshot_servidor;")
    count_snap = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM producto_cache;")
    count_cache = cur.fetchone()[0]
    print(f"-> {count_snap} productos cargados en snapshot_servidor.")
    print(f"-> {count_cache} productos cacheados en producto_cache (modo offline listo).")
    con.close()


def ejecutar_semaforo():
    con = get_db()
    with open(SEMAFORO_SQL, "r", encoding="utf-8") as f:
        # Se ejecuta todo el script
        con.executescript(f.read())
    con.commit()
    con.close()


def imprimir_tabla(titulo, filas, columnas):
    print(f"\n--- {titulo} ---")
    if not filas:
        print("(0 filas)")
        return
    col_widths = [max(len(str(val)) for val in [col] + [f[i] for f in filas]) for i, col in enumerate(columnas)]
    header_str = " | ".join(f"{col:<{col_widths[i]}}" for i, col in enumerate(columnas))
    separator = "-+-".join("-" * col_widths[i] for i in range(len(columnas)))
    print(header_str)
    print(separator)
    for f in filas:
        row_str = " | ".join(f"{str(f[i]):<{col_widths[i]}}" for i in range(len(columnas)))
        print(row_str)


def simular_caso_c2():
    print("=" * 80)
    print("CASO C2: CAMBIO DE PRECIO EN SERVIDOR -> CONFLICTO -> REINTENTO ACEPTADO -> SIMULADO_APROBADO")
    print("=" * 80)
    con = get_db()
    
    # Paso 1: Confeccionar borrador con Muzzarella (id: 1) a precio visto $1050.00 (105000 centavos)
    con.execute("INSERT INTO pedido_borrador VALUES ('borrador-c2', 'operador_tablet_1', 'EFECTIVO', '2026-11-02T18:30:00Z');")
    con.execute("INSERT INTO item_borrador VALUES ('borrador-c2', 1, 1, 105000);")
    con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c2-v1', 'borrador-c2', 'PENDIENTE', 'Pendiente de evaluacion inicial');")
    con.commit()
    
    # Paso 2: Simular actualización de precio en el snapshot del servidor (de $1050 a $1200)
    con.execute("UPDATE snapshot_servidor SET precio_centavos = 120000 WHERE id = 1;")
    con.commit()
    
    # Paso 3: Correr el semáforo
    ejecutar_semaforo()
    
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c2-v1';")
    filas = cur.fetchall()
    imprimir_tabla("Resultado Primera Evaluación C2 (Conflicto de Precio)", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    
    # Paso 4: El cliente acepta la actualización a $1200. Se actualiza el borrador local y se emite nueva solicitud
    print("\n-> El cliente acepta la diferencia de precio ($1200.00). Se actualiza item_borrador y se envía nueva solicitud...")
    con.execute("UPDATE item_borrador SET precio_centavos_visto = 120000 WHERE id_local = 'borrador-c2' AND producto_id = 1;")
    con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c2-v2', 'borrador-c2', 'PENDIENTE', 'Reintento con precio actualizado por cliente');")
    con.commit()
    
    # Paso 5: Reevaluar semáforo
    ejecutar_semaforo()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c2-v2';")
    filas_v2 = cur.fetchall()
    imprimir_tabla("Resultado Segunda Evaluación C2 (Aprobado)", filas_v2, ["solicitud_uuid", "id_local", "estado", "motivo"])
    con.close()


def simular_caso_c3():
    print("=" * 80)
    print("CASO C3: INSUFICIENCIA DE STOCK -> RECHAZADO")
    print("=" * 80)
    con = get_db()
    
    # Producto Napolitana (id: 2) tiene stock 25 en snapshot. Borrador solicita 200 unidades.
    con.execute("INSERT INTO pedido_borrador VALUES ('borrador-c3', 'operador_tablet_1', 'TARJETA', '2026-11-02T18:40:00Z');")
    con.execute("INSERT INTO item_borrador VALUES ('borrador-c3', 2, 200, 150000);")
    con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c3', 'borrador-c3', 'PENDIENTE', 'Pendiente evaluacion stock');")
    con.commit()
    
    ejecutar_semaforo()
    
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c3';")
    filas = cur.fetchall()
    imprimir_tabla("Resultado Evaluación C3 (Rechazo por Stock)", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    con.close()


def simular_caso_c4():
    print("=" * 80)
    print("CASO C4: PRODUCTO DADO DE BAJA LÓGICA (LÁPIDA / TOMBSTONE) -> RECHAZADO Y OCULTO EN CATÁLOGO")
    print("=" * 80)
    con = get_db()
    
    # Borrador con Calzone Calabres (id: 7)
    con.execute("INSERT INTO pedido_borrador VALUES ('borrador-c4', 'operador_tablet_1', 'TRANSFERENCIA', '2026-11-02T18:45:00Z');")
    con.execute("INSERT INTO item_borrador VALUES ('borrador-c4', 7, 1, 180000);")
    con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c4', 'borrador-c4', 'PENDIENTE', 'Pendiente evaluacion baja');")
    con.commit()
    
    # En el servidor se aplica baja lógica al producto 7
    print("-> Servidor emite baja lógica sobre producto 7 (eliminado='t', disponible='f')...")
    con.execute("UPDATE snapshot_servidor SET eliminado = 't', disponible = 'f' WHERE id = 7;")
    con.commit()
    
    ejecutar_semaforo()
    
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c4';")
    filas = cur.fetchall()
    imprimir_tabla("Resultado Evaluación C4 (Rechazo por Baja Lógica)", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    
    # Al recargar catálogo local:
    print("-> Sincronizando producto_cache con la nueva instantánea...")
    con.execute("""
        UPDATE producto_cache 
        SET eliminado = 1, disponible = 0 
        WHERE id = 7;
    """)
    con.commit()
    
    cur.execute("SELECT id, nombre, stock_visto, disponible, eliminado FROM producto_cache WHERE id = 7;")
    filas_lapida = cur.fetchall()
    imprimir_tabla("Estado en producto_cache (La fila física queda como lápida)", filas_lapida, ["id", "nombre", "stock_visto", "disponible", "eliminado"])
    
    cur.execute("SELECT COUNT(*) FROM producto_cache WHERE disponible = 1 AND eliminado = 0 AND id = 7;")
    oculto = cur.fetchone()[0]
    print(f"-> Verificación en vista comercial (WHERE disponible=1 AND eliminado=0): {oculto} filas (Oculto de la venta).")
    con.close()


def simular_caso_c5():
    print("=" * 80)
    print("CASO C5: BORRADOR SIN CAMBIOS -> SIMULADO_APROBADO")
    print("=" * 80)
    con = get_db()
    
    # 2 Coca 1.5L (id: 3, $800.00 c/u, stock 100) y 1 Agua Mineral (id: 4, $400.00, stock 150)
    con.execute("INSERT INTO pedido_borrador VALUES ('borrador-c5', 'operador_tablet_1', 'EFECTIVO', '2026-11-02T18:50:00Z');")
    con.execute("INSERT INTO item_borrador VALUES ('borrador-c5', 3, 2, 80000);")
    con.execute("INSERT INTO item_borrador VALUES ('borrador-c5', 4, 1, 40000);")
    con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c5', 'borrador-c5', 'PENDIENTE', 'Pendiente evaluacion normal');")
    con.commit()
    
    ejecutar_semaforo()
    
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c5';")
    filas = cur.fetchall()
    imprimir_tabla("Resultado Evaluación C5 (Aprobación Normal)", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    con.close()


def simular_caso_c6():
    print("=" * 80)
    print("CASO C6: REENVÍO DE MISMA SOLICITUD (IDEMPOTENCIA POR UUID Y SEMÁFORO INVARIANTE)")
    print("=" * 80)
    con = get_db()
    
    # Reintento de insertar exactamente el mismo solicitud_uuid ('sync-uuid-c5')
    print("-> Intentando reinsertar en cola_sync la solicitud duplicada 'sync-uuid-c5'...")
    try:
        con.execute("INSERT INTO cola_sync VALUES ('sync-uuid-c5', 'borrador-c5', 'PENDIENTE', 'Reintento duplicado por red');")
        print("ERROR: La base permitió el duplicado!")
    except sqlite3.IntegrityError as e:
        con.rollback()
        print(f"-> Rechazo por Clave Primaria Duplicada en SQLite: {e}")
    
    # Cerrar la conexión previa antes de llamar a ejecutar_semaforo
    con.close()
    
    # Repetir la ejecución del semáforo para verificar que C5 no se reevalúa
    print("-> Re-ejecutando semáforo sobre la base...")
    ejecutar_semaforo()
    
    con = get_db()
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'sync-uuid-c5';")
    filas = cur.fetchall()
    imprimir_tabla("Estado C5 post-reejecución del semáforo (Invariante: sigue SIMULADO_APROBADO)", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    con.close()


def resumen_final():
    print("=" * 80)
    print("RESUMEN GENERAL DE cola_sync EN LA TABLET (foodstore_movil.db)")
    print("=" * 80)
    con = get_db()
    cur = con.cursor()
    cur.execute("SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY solicitud_uuid ASC;")
    filas = cur.fetchall()
    imprimir_tabla("Contenido Final de cola_sync", filas, ["solicitud_uuid", "id_local", "estado", "motivo"])
    con.close()


if __name__ == "__main__":
    inicializar_base()
    cargar_snapshot_inicial()
    simular_caso_c2()
    simular_caso_c3()
    simular_caso_c4()
    simular_caso_c5()
    simular_caso_c6()
    resumen_final()
