﻿-- UNIDADES TERRITORIAIS --

CREATE TABLE "PGHP".unidadesterritoriais
(
  gid serial primary key,
  oid SERIAL PRIMARY KEY,
  nome character varying(50) UNIQUE NOT NULL,
  descricao character varying(255),
  time_start timestamp, -- data de criação da linha
  time_end timestamp, -- data de "eliminação" da linha
  user_update character varying(40) -- nome de utilizador que criou, alterou ou eliminou a linha
);


-- Criar versioning --

-- View com estado actual da tabela geral das infraestruturas (i.e. a linha não foi eliminada)
CREATE OR REPLACE VIEW "PGHP"."unidadesterritoriais_current" AS
  SELECT "gid", "oid", "nome", "descricao", "time_start", "time_end", "user_update"
  FROM "PGHP"."unidadesterritoriais"
  WHERE "time_end" IS NULL;

 -- Função para visualizar tabela em determinado dia/hora (usado apenas pela administração para resolver problemas)
CREATE OR REPLACE FUNCTION "PGHP"."unidadesterritoriais_at_time"(timestamp without time zone)
RETURNS SETOF "PGHP"."unidadesterritoriais_current" AS
$$
SELECT "gid", "oid", "nome", "descricao", "time_start", "time_end", "user_update" FROM "PGHP"."infraestruturas" WHERE
  ( SELECT CASE WHEN "time_end" IS NULL THEN ("time_start" <= $1) ELSE ("time_start" <= $1 AND "time_end" > $1) END );
$$
LANGUAGE 'sql';

-- Criar triggers e respectivas funções para implementar o versioning nas tabelas --

-- Esta função, faz com que quando é pedido para actualizar uma linha na tabela,
-- em vez disso (ver trigger) arquiva a versão anterior da linha e insere
CREATE OR REPLACE FUNCTION "PGHP".unidadesterritoriais_update()
  RETURNS trigger AS
$BODY$
BEGIN
  IF OLD."time_end" IS NOT NULL THEN
    RETURN NULL;
  END IF;
  IF NEW."time_end" IS NULL THEN
    INSERT INTO "PGHP"."unidadesterritoriais" ("gid","oid","nome","descricao","time_start","time_end","user_update") VALUES (OLD."gid",OLD."nome",OLD."geom", OLD."time_start", current_timestamp,user);
    NEW."time_start" = current_timestamp;
  END IF;
  RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION "PGHP".unidadesterritoriais_update()
  OWNER TO postgres;

-- Esta função, faz com que quando é pedido para inserir uma linha na tabela,
-- sejam actualizados os campos de versioning time_start, time_end e user_update
CREATE OR REPLACE FUNCTION "PGHP".unidadesterritoriais_insert()
RETURNS trigger AS
$$
BEGIN
  if NEW."time_start" IS NULL then
    NEW."time_start" = now();
    NEW."time_end" = null;
    NEW."user_update" = user;
  end if;
  -- se o oid for deixado em branco é-lhe atribuído o próximo número na sequencia
  if NEW."oid" IS NULL then
    NEW."oid" = nextval('"PGHP".unidadesterritoriais_oid_seq'::regclass);
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- RULES E TRIGGER
CREATE RULE "unidadesterritoriais_del" AS ON DELETE TO "PGHP"."unidadesterritoriais"
DO INSTEAD UPDATE "PGHP"."unidadesterritoriais" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "unidadesterritoriais_update" BEFORE UPDATE ON "PGHP"."unidadesterritoriais"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."unidadesterritoriais_update"();

CREATE TRIGGER "unidadesterritoriais_insert" BEFORE INSERT ON "PGHP"."unidadesterritoriais"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."unidadesterritoriais_insert"();


--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP"."unidadesterritoriais_current" DO INSTEAD
  DELETE FROM "PGHP"."unidadesterritoriais" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP"."unidadesterritoriais_current" DO INSTEAD
  INSERT INTO "PGHP"."unidadesterritoriais" ("oid","nome","descricao")
    VALUES (NEW."oid",NEW."nome",NEW."descricao");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP"."unidadesterritoriais_current" DO INSTEAD
  UPDATE "PGHP"."unidadesterritoriais_current"
    SET "oid" = NEW."oid", "nome" = NEW."nome", "descricao" = NEW."descricao" 
    WHERE gid = OLD."gid";



-- LIMITES --

CREATE TABLE "PGHP".limites (
  gid SERIAL NOT NULL,
  uniterr_oid integer references "PGHP".unidadesterritoriais(oid),
  nome character varying(30),
  geom geometry(MultiPolygon, 3763),
  CONSTRAINT "limites_pkey" PRIMARY KEY (gid));

CREATE INDEX limites_gist
  ON "PGHP".limites
  USING gist
  (geom);