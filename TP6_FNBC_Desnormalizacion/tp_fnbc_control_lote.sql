-- ============================================================================
-- TRABAJO PRÁCTICO UNIDAD 4 - PARTE 1
-- Normalización a Forma Normal de Boyce-Codd (FNBC): ControlLoteAlmacen
-- Cátedra: Base de Datos II - UTN FRM
-- Integrantes: Tiziano Valentini, Juan Martin Garcia
-- ============================================================================
-- Corre solo (no depende de las tablas de TP1-TP5). Es re-ejecutable:
-- elimina y recrea únicamente las tablas de esta extensión mayorista.
--
-- Las tablas maestras lote, deposito y usuario de la extensión mayorista
-- NO existen en TP1/schema.sql (que modela Cliente, Categoria, Producto,
-- Pedido y Detalle_Pedido). La consigna manda asumirlas existentes, por lo
-- que se crean acá en su versión mínima si faltan. "usuario" representa al
-- personal de la dotación (responsables de control), distinto de Cliente.
--
-- Uso:  psql -d food_store -f tp_fnbc_control_lote.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Tablas maestras mínimas (supuestas por la consigna) e instancia base
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lote     (id BIGINT PRIMARY KEY, codigo VARCHAR(50)  NOT NULL);
CREATE TABLE IF NOT EXISTS deposito (id BIGINT PRIMARY KEY, nombre VARCHAR(100) NOT NULL);
CREATE TABLE IF NOT EXISTS usuario  (id BIGINT PRIMARY KEY, nombre VARCHAR(100) NOT NULL);

INSERT INTO lote (id, codigo) VALUES
    (501, 'LOTE-A'), (502, 'LOTE-B'), (503, 'LOTE-C')
ON CONFLICT (id) DO NOTHING;

-- El depósito 32 y el usuario 803 solo se usan en la demostración de anomalías.
INSERT INTO deposito (id, nombre) VALUES
    (30, 'Depósito Central'), (31, 'Depósito Norte'), (32, 'Depósito Sur')
ON CONFLICT (id) DO NOTHING;

INSERT INTO usuario (id, nombre) VALUES
    (801, 'Inspector Gómez'), (802, 'Inspectora Rossi'), (803, 'Inspector Díaz')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 1. Esquema ORIGINAL (viola FNBC) y su instancia de ejemplo
--    DF1: {lote_id, deposito_id} -> responsable_control_id
--    DF2: responsable_control_id -> deposito_id   (determinante NO superclave)
-- ---------------------------------------------------------------------------
DROP VIEW  IF EXISTS vista_control_lote_almacen_fnbc;
DROP TABLE IF EXISTS asignacion_control_lote CASCADE;
DROP TABLE IF EXISTS responsable_deposito    CASCADE;
DROP TABLE IF EXISTS control_lote_almacen    CASCADE;

CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ---------------------------------------------------------------------------
-- 2. Las tres anomalías sobre el esquema original (evidencia ejecutable).
--    Cada demostración se revierte: la instancia original queda intacta.
-- ---------------------------------------------------------------------------

-- 2.a Anomalía de INSERCIÓN: el inspector 803 pertenece al depósito 32, pero
--     no puede registrarse ese hecho sin inventar un lote (lote_id es parte
--     de la PK y no admite NULL).
DO $$
BEGIN
    INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
    VALUES (NULL, 32, 803);
    RAISE NOTICE 'INSERCIÓN: se aceptó la fila (inesperado)';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'ANOMALÍA DE INSERCIÓN: no se puede registrar que 803 pertenece al depósito 32 sin un lote (%).', SQLERRM;
END $$;

-- 2.b Anomalía de BORRADO: al cancelar el control del lote 503 se pierde el
--     único dato de que el responsable 802 pertenece al depósito 31.
BEGIN;
    DELETE FROM control_lote_almacen WHERE lote_id = 503;
    SELECT 'ANOMALÍA DE BORRADO: filas que mencionan a 802 tras cancelar el lote 503' AS demo,
           count(*) AS filas
    FROM control_lote_almacen
    WHERE responsable_control_id = 802;
ROLLBACK;

-- 2.c Anomalía de ACTUALIZACIÓN: actualizar solo UNA de las dos filas de 801
--     deja al responsable en dos depósitos a la vez. La PK (lote, deposito)
--     NO lo impide: la DF2 no está protegida por ninguna restricción.
BEGIN;
    UPDATE control_lote_almacen
    SET deposito_id = 32
    WHERE lote_id = 501 AND responsable_control_id = 801;

    SELECT 'ANOMALÍA DE ACTUALIZACIÓN: responsables con más de un depósito' AS demo,
           responsable_control_id,
           count(DISTINCT deposito_id) AS depositos_distintos
    FROM control_lote_almacen
    GROUP BY responsable_control_id
    HAVING count(DISTINCT deposito_id) > 1;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- 3. Descomposición sin pérdida a FNBC (algoritmo sobre DF2)
--    R1(responsable_control_id, deposito_id)   PK: responsable_control_id
--    R2(lote_id, responsable_control_id)       PK: (lote_id, responsable_control_id)
--    R1 ∩ R2 = {responsable_control_id}, superclave (clave) de R1 => sin pérdida.
-- ---------------------------------------------------------------------------
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE asignacion_control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Índice para el camino inverso (qué lotes controla un responsable) y para el
-- ON DELETE/UPDATE de la FK. La PK solo cubre lote_id como columna líder.
CREATE INDEX idx_asignacion_responsable ON asignacion_control_lote (responsable_control_id);

-- ---------------------------------------------------------------------------
-- 4. Preservación de la DF1 ({lote, deposito} -> responsable).
--    La descomposición es sin pérdida pero NO preserva DF1 por restricciones
--    declarativas: un mismo lote podría quedar con dos responsables del mismo
--    depósito. Se la protege con dos disparadores (costo habitual de FNBC).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_df1_asignacion() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM asignacion_control_lote a
        JOIN responsable_deposito ra ON ra.responsable_control_id = a.responsable_control_id
        JOIN responsable_deposito rn ON rn.responsable_control_id = NEW.responsable_control_id
        WHERE a.lote_id = NEW.lote_id
          AND a.responsable_control_id <> NEW.responsable_control_id
          AND ra.deposito_id = rn.deposito_id
    ) THEN
        RAISE EXCEPTION
            'DF1 violada: el lote % ya tiene otro responsable de control en el mismo depósito',
            NEW.lote_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_df1_asignacion
    BEFORE INSERT OR UPDATE ON asignacion_control_lote
    FOR EACH ROW EXECUTE FUNCTION fn_validar_df1_asignacion();

CREATE OR REPLACE FUNCTION fn_validar_df1_cambio_deposito() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM asignacion_control_lote a1
        JOIN asignacion_control_lote a2
              ON a2.lote_id = a1.lote_id
             AND a2.responsable_control_id <> a1.responsable_control_id
        JOIN responsable_deposito r2 ON r2.responsable_control_id = a2.responsable_control_id
        WHERE a1.responsable_control_id = NEW.responsable_control_id
          AND r2.deposito_id = NEW.deposito_id
    ) THEN
        RAISE EXCEPTION
            'DF1 violada: mover al responsable % al depósito % lo deja compartiendo lote y depósito con otro responsable',
            NEW.responsable_control_id, NEW.deposito_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_df1_cambio_deposito
    BEFORE UPDATE OF deposito_id ON responsable_deposito
    FOR EACH ROW EXECUTE FUNCTION fn_validar_df1_cambio_deposito();

-- ---------------------------------------------------------------------------
-- 5. Vista de compatibilidad: reconstruye la relación original (reunión natural)
-- ---------------------------------------------------------------------------
CREATE VIEW vista_control_lote_almacen_fnbc AS
SELECT lote_id, deposito_id, responsable_control_id
FROM asignacion_control_lote
NATURAL JOIN responsable_deposito;

-- ---------------------------------------------------------------------------
-- 6. Migración de la instancia de ejemplo
--    (si la instancia violara DF2, el INSERT de responsable_deposito fallaría
--    por la PK: un responsable en dos depósitos no puede migrarse sin decidir)
-- ---------------------------------------------------------------------------
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

INSERT INTO asignacion_control_lote (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id FROM control_lote_almacen;

-- ---------------------------------------------------------------------------
-- 7. Verificación de equivalencia (ambas consultas deben devolver 0 filas)
-- ---------------------------------------------------------------------------
SELECT * FROM control_lote_almacen        EXCEPT SELECT * FROM vista_control_lote_almacen_fnbc;
SELECT * FROM vista_control_lote_almacen_fnbc EXCEPT SELECT * FROM control_lote_almacen;

-- Control adicional: misma cantidad de filas en ambos lados (esperado: 3 y 3).
SELECT (SELECT count(*) FROM control_lote_almacen)        AS filas_original,
       (SELECT count(*) FROM vista_control_lote_almacen_fnbc) AS filas_vista;

-- ---------------------------------------------------------------------------
-- 8. Las tres anomalías ya NO ocurren en el esquema descompuesto
-- ---------------------------------------------------------------------------

-- 8.a Inserción: 803 se registra en el depósito 32 sin necesidad de un lote.
BEGIN;
    INSERT INTO responsable_deposito VALUES (803, 32);
    SELECT 'INSERCIÓN OK: 803 -> depósito 32 sin lote' AS demo, * FROM responsable_deposito WHERE responsable_control_id = 803;
ROLLBACK;

-- 8.b Borrado: cancelar el lote 503 conserva el dato 802 -> depósito 31.
BEGIN;
    DELETE FROM asignacion_control_lote WHERE lote_id = 503;
    SELECT 'BORRADO OK: 802 conserva su depósito' AS demo, * FROM responsable_deposito WHERE responsable_control_id = 802;
ROLLBACK;

-- 8.c Actualización: reasignar a 801 es UN solo UPDATE y la vista queda coherente.
BEGIN;
    UPDATE responsable_deposito SET deposito_id = 32 WHERE responsable_control_id = 801;
    SELECT 'ACTUALIZACIÓN OK: 801 en un solo depósito' AS demo,
           responsable_control_id, count(DISTINCT deposito_id) AS depositos_distintos
    FROM vista_control_lote_almacen_fnbc
    GROUP BY responsable_control_id
    ORDER BY responsable_control_id;
ROLLBACK;

-- 8.d DF1 sigue protegida: asignar un 2.º responsable del mismo depósito al
--     mismo lote debe ser rechazado por el disparador.
DO $$
BEGIN
    INSERT INTO usuario (id, nombre) VALUES (804, 'Inspector Prueba') ON CONFLICT (id) DO NOTHING;
    BEGIN
        INSERT INTO responsable_deposito VALUES (804, 30);
        INSERT INTO asignacion_control_lote VALUES (501, 804);  -- lote 501 ya tiene a 801 en el depósito 30
        RAISE NOTICE 'DF1: se aceptó la fila (inesperado)';
    EXCEPTION WHEN raise_exception THEN
        RAISE NOTICE 'DF1 protegida: %', SQLERRM;
    END;
    -- Se limpia lo que haya quedado de la prueba (el subbloque ya revirtió sus filas).
    DELETE FROM usuario WHERE id = 804;
END $$;
