-- UNIDADES TERRITORIAIS --
--DROP TABLE "PGHP_2".unidadesterritoriais CASCADE;


CREATE TABLE "PGHP_2".unidadesterritoriais
(
  gid serial primary key,
  oid SERIAL,
  nome character varying(50) NOT NULL,
  descricao character varying(255),
  time_start timestamp, -- data de criação da linha
  time_end timestamp, -- data de "eliminação" da linha
  user_update character varying(40) -- nome de utilizador que criou, alterou ou eliminou a linha
);


-- Criar versioning --

-- View com estado actual da tabela geral das infraestruturas (i.e. a linha não foi eliminada)
CREATE OR REPLACE VIEW "PGHP_2"."unidadesterritoriais_current" AS
  SELECT "gid", "oid", "nome", "descricao", "time_start", "time_end", "user_update"
  FROM "PGHP_2"."unidadesterritoriais"
  WHERE "time_end" IS NULL;

 -- Função para visualizar tabela em determinado dia/hora (usado apenas pela administração para resolver problemas)
CREATE OR REPLACE FUNCTION "PGHP_2"."unidadesterritoriais_at_time"(timestamp without time zone)
RETURNS SETOF "PGHP_2"."unidadesterritoriais_current" AS
$$
SELECT "gid", "oid", "nome", "descricao", "time_start", "time_end", "user_update" FROM "PGHP_2"."unidadesterritoriais" WHERE
  ( SELECT CASE WHEN "time_end" IS NULL THEN ("time_start" <= $1) ELSE ("time_start" <= $1 AND "time_end" > $1) END );
$$
LANGUAGE 'sql';

-- Criar triggers e respectivas funções para implementar o versioning nas tabelas --

-- Esta função, faz com que quando é pedido para actualizar uma linha na tabela,
-- em vez disso (ver trigger) arquiva a versão anterior da linha e insere
CREATE OR REPLACE FUNCTION "PGHP_2".unidadesterritoriais_update()
  RETURNS trigger AS
$BODY$
BEGIN
  IF OLD."time_end" IS NOT NULL THEN
    RETURN NULL;
  END IF;
  IF NEW."time_end" IS NULL THEN
    INSERT INTO "PGHP_2"."unidadesterritoriais" ("oid","nome","descricao","time_start","time_end","user_update") 
       VALUES (OLD."oid",OLD."nome",OLD."descricao", OLD."time_start", current_timestamp,user);
    NEW."time_start" = current_timestamp;
  END IF;
  RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION "PGHP_2".unidadesterritoriais_update()
  OWNER TO postgres;

-- Esta função, faz com que quando é pedido para inserir uma linha na tabela,
-- sejam actualizados os campos de versioning time_start, time_end e user_update
CREATE OR REPLACE FUNCTION "PGHP_2".unidadesterritoriais_insert()
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
    NEW."oid" = nextval('"PGHP_2".unidadesterritoriais_oid_seq'::regclass);
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- RULES E TRIGGER
CREATE RULE "unidadesterritoriais_del" AS ON DELETE TO "PGHP_2"."unidadesterritoriais"
DO INSTEAD UPDATE "PGHP_2"."unidadesterritoriais" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "unidadesterritoriais_update" BEFORE UPDATE ON "PGHP_2"."unidadesterritoriais"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesterritoriais_update"();

CREATE TRIGGER "unidadesterritoriais_insert" BEFORE INSERT ON "PGHP_2"."unidadesterritoriais"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesterritoriais_insert"();


--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP_2"."unidadesterritoriais_current" DO INSTEAD
  DELETE FROM "PGHP_2"."unidadesterritoriais" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP_2"."unidadesterritoriais_current" DO INSTEAD
  INSERT INTO "PGHP_2"."unidadesterritoriais" ("oid","nome","descricao")
    VALUES (NEW."oid",NEW."nome",NEW."descricao");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP_2"."unidadesterritoriais_current" DO INSTEAD
  UPDATE "PGHP_2"."unidadesterritoriais"
    SET "oid" = NEW."oid", "nome" = NEW."nome", "descricao" = NEW."descricao" 
    WHERE gid = OLD."gid";


/*
-- LIMITES --

CREATE TABLE "PGHP_2".limites (
  gid SERIAL NOT NULL,
  uniterr_oid integer references "PGHP_2".unidadesterritoriais(oid),
  nome character varying(30),
  geom geometry(MultiPolygon, 3763),
  CONSTRAINT "limites_pkey" PRIMARY KEY (gid));

CREATE INDEX limites_gist
  ON "PGHP_2".limites
  USING gist
  (geom);
*/