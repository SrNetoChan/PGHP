--DROP TABLE testes_versioning;

CREATE TABLE testes_versioning(
gid serial primary key,
descr varchar(40),
geom geometry(MULTIPOLYGON,3763),
time_start timestamp without time zone,
user_update character varying(40)
);

CREATE INDEX testes_versioning_idx
  ON testes_versioning
  USING gist
  (geom);

--DROP TABLE testes_versioning_bk;
CREATE TABLE testes_versioning_bk (
   like testes_versioning
);
ALTER TABLE testes_versioning_bk
   ADD COLUMN time_end timestamp without time zone,
   ADD COLUMN gid_bk serial primary key;


CREATE OR REPLACE FUNCTION "testes_versioning_changes"()
RETURNS trigger AS
$$
BEGIN
    NEW."time_start" = now();
    NEW."user_update" = user;
RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION "testes_versioning_backup"()
RETURNS trigger AS
$$
BEGIN
    INSERT INTO testes_versioning_bk
    SELECT OLD.*;
RETURN OLD;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER "testes_versioning_2_add" BEFORE INSERT OR UPDATE ON "testes_versioning"
FOR EACH ROW EXECUTE PROCEDURE "testes_versioning_changes"();

--::FIXME tenho de separar o update do Delete, um tem de fazer return do NEW e outro do OLD 
CREATE TRIGGER "testes_versioning_1_backup" BEFORE UPDATE OR DELETE ON "testes_versioning"
FOR EACH ROW EXECUTE PROCEDURE "testes_versioning_backup"();

--::FIXME tenho de fazer testes como ver versão a data altura do tempo, ver se é rápido.




