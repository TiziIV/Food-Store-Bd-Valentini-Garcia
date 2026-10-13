\set ON_ERROR_STOP on
-- PostgreSQL 16. Demo aislada: no toca tablas del proyecto Food Store.
BEGIN;
CREATE SCHEMA IF NOT EXISTS tp_u4_fnbc;
SET LOCAL search_path = tp_u4_fnbc, public;
DROP VIEW IF EXISTS vista_control_lote_almacen_fnbc;
DROP TABLE IF EXISTS asignacion_control_lote, responsable_deposito, control_lote_almacen;
CREATE TABLE IF NOT EXISTS lote (id BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS deposito (id BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS usuario (id BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS mutex_fnbc (id INTEGER PRIMARY KEY);
INSERT INTO lote VALUES (501),(502),(503) ON CONFLICT DO NOTHING;
INSERT INTO deposito VALUES (30),(31),(32) ON CONFLICT DO NOTHING;
INSERT INTO usuario VALUES (801),(802),(803) ON CONFLICT DO NOTHING;
CREATE TABLE control_lote_almacen (
 lote_id BIGINT NOT NULL REFERENCES lote(id),
 deposito_id BIGINT NOT NULL REFERENCES deposito(id),
 responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
 PRIMARY KEY (lote_id, deposito_id)
);
INSERT INTO control_lote_almacen VALUES (501,30,801),(502,30,801),(503,31,802);
CREATE TABLE responsable_deposito (
 responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
 deposito_id BIGINT NOT NULL REFERENCES deposito(id)
);
CREATE TABLE asignacion_control_lote (
 lote_id BIGINT NOT NULL REFERENCES lote(id),
 responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
 PRIMARY KEY (lote_id, responsable_control_id)
);
INSERT INTO responsable_deposito SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;
INSERT INTO asignacion_control_lote SELECT DISTINCT lote_id, responsable_control_id FROM control_lote_almacen;
CREATE VIEW vista_control_lote_almacen_fnbc AS
 SELECT lote_id, deposito_id, responsable_control_id
 FROM asignacion_control_lote NATURAL JOIN responsable_deposito;
-- R1 inter R2 = {ResponsableControlID}, clave de R1: union sin perdida.
-- La DF {LoteID,DepositoID}->ResponsableControlID NO queda preservada
-- por las PK/FK de R1 y R2. Proteccion adicional sobre AMBAS tablas.
CREATE OR REPLACE FUNCTION bloquear_fnbc() RETURNS trigger LANGUAGE plpgsql
SET search_path = tp_u4_fnbc, public AS $$
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
  RAISE EXCEPTION 'Esta demo requiere READ COMMITTED';
 END IF;
 LOCK TABLE mutex_fnbc IN SHARE ROW EXCLUSIVE MODE;
 RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION validar_fnbc() RETURNS trigger LANGUAGE plpgsql
SET search_path = tp_u4_fnbc, public AS $$
BEGIN
 IF EXISTS (SELECT 1 FROM vista_control_lote_almacen_fnbc
            GROUP BY lote_id, deposito_id HAVING COUNT(*) > 1) THEN
  RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Viola DF (LoteID, DepositoID) -> ResponsableControlID';
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER bloquear_asignacion BEFORE INSERT OR UPDATE OR DELETE ON asignacion_control_lote
 FOR EACH STATEMENT EXECUTE FUNCTION bloquear_fnbc();
CREATE TRIGGER bloquear_responsable BEFORE INSERT OR UPDATE OR DELETE ON responsable_deposito
 FOR EACH STATEMENT EXECUTE FUNCTION bloquear_fnbc();
CREATE TRIGGER validar_asignacion AFTER INSERT OR UPDATE OR DELETE ON asignacion_control_lote
 FOR EACH STATEMENT EXECUTE FUNCTION validar_fnbc();
CREATE TRIGGER validar_responsable AFTER INSERT OR UPDATE OR DELETE ON responsable_deposito
 FOR EACH STATEMENT EXECUTE FUNCTION validar_fnbc();
\echo RECONSTRUCCION Y DIFERENCIAS (esperado: 3 filas y 0 diferencias)
TABLE vista_control_lote_almacen_fnbc;
SELECT * FROM control_lote_almacen EXCEPT SELECT * FROM vista_control_lote_almacen_fnbc;
SELECT * FROM vista_control_lote_almacen_fnbc EXCEPT SELECT * FROM control_lote_almacen;
SELECT (SELECT COUNT(*) FROM control_lote_almacen) original,
       (SELECT COUNT(*) FROM vista_control_lote_almacen_fnbc) reconstruida;
INSERT INTO responsable_deposito VALUES (803,30);
DO $$ BEGIN
 BEGIN
  INSERT INTO asignacion_control_lote VALUES (501,803);
  RAISE EXCEPTION 'FALLO: se acepto asignacion incompatible';
 EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: asignacion duplicada rechazada'; END;
 INSERT INTO asignacion_control_lote VALUES (503,803);
 BEGIN
  UPDATE responsable_deposito SET deposito_id=31 WHERE responsable_control_id=803;
  RAISE EXCEPTION 'FALLO: se acepto cambio incompatible de deposito';
 EXCEPTION WHEN check_violation THEN RAISE NOTICE 'OK: cambio de deposito rechazado'; END;
 DELETE FROM asignacion_control_lote WHERE responsable_control_id=803;
END $$;
SELECT r.* FROM responsable_deposito r WHERE NOT EXISTS
 (SELECT 1 FROM asignacion_control_lote a WHERE a.responsable_control_id=r.responsable_control_id);
COMMIT;
