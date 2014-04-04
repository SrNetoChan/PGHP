/* UNIDADES DE GESTAO */
-- Criação de tabelas auxiliares

CREATE TABLE "PGHP_2".usos (
  oid serial PRIMARY KEY,
  nome character varying(30) UNIQUE
);

CREATE TABLE "PGHP_2".unidadesdegestao
(
  gid serial PRIMARY KEY,
  oid serial,
  uniterr_oid integer,
  nome character varying(40),
  act_uso character varying(30) REFERENCES "PGHP_2".usos(nome),
  act_composicao character varying(40),
  prop_uso character varying(30) REFERENCES "PGHP_2".usos(nome),
  prop_composicao character varying(40),
  prop_data_limite character varying(20),
  geom geometry(geometry, 3763),
  time_start timestamp, -- data de criação da linha
  time_end timestamp, -- data de "eliminação" da linha
  user_update character varying(40) -- nome de utilizador que criou, alterou ou eliminou a linha
);

CREATE INDEX unidadesdegestao_idx
  ON "PGHP_2".unidadesdegestao
  USING gist
  (geom);

-- Tabela das unidades de gestao para geometrias de linhas (child)
CREATE TABLE "PGHP_2".unidadesdegestao_linhas
(
	--geom geometry(MULTILINESTRING, 3763),
	CONSTRAINT unidadesdegestao_linhas_pk PRIMARY KEY (gid),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTILINESTRING'::text),
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (nome) REFERENCES "PGHP_2".usos (nome),
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (nome) REFERENCES "PGHP_2".usos (nome)
)
	INHERITS ("PGHP_2".unidadesdegestao);

-- Em tabelas com inherits, tanto CONSTRAINTs como INDEXes tem de ser recriadas
CREATE INDEX unidadesdegestao_linhas_idx
  ON "PGHP_2".unidadesdegestao_linhas
  USING gist
  (geom);

-- Tabela das infra-estruturas para geometrias de polígonos (child)
CREATE TABLE "PGHP_2".unidadesdegestao_poligonos
(
	--geom geometry(MULTIPOLYGON, 3763),
	CONSTRAINT unidadesdegestao_poligonos_pk PRIMARY KEY (gid),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTIPOLYGON'::text),
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (nome) REFERENCES "PGHP_2".usos (nome),
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (nome) REFERENCES "PGHP_2".usos (nome)
)
	INHERITS ("PGHP_2".unidadesdegestao);

-- Em tabelas com inherits, tanto CONSTRAINTs como INDEXes tem de ser recriadas
CREATE INDEX unidadesdegestao_poligonos_idx
  ON "PGHP_2".unidadesdegestao_poligonos
  USING gist
  (geom);


-- Criar versioning --

-- View com estado actual da tabela geral das unidadesdegestao (i.e. a linha não foi eliminada)
CREATE OR REPLACE VIEW "PGHP_2"."unidadesdegestao_current" AS
  SELECT *
  FROM "PGHP_2"."unidadesdegestao"
  WHERE "time_end" IS NULL;

-- Função para visualizar tabela em determinado dia/hora (usado apenas pela administração para resolver problemas)
CREATE OR REPLACE FUNCTION "PGHP_2"."unidadesdegestao_at_time"(timestamp without time zone)
RETURNS SETOF "PGHP_2"."unidadesdegestao_current" AS
$$
SELECT * FROM "PGHP_2"."unidadesdegestao" WHERE
  ( SELECT CASE WHEN "time_end" IS NULL THEN ("time_start" <= $1) ELSE ("time_start" <= $1 AND "time_end" > $1) END );
$$
LANGUAGE 'sql';

-- Criar triggers e respectivas funções para implementar o versioning nas tabelas --

-- Esta função, faz com que quando é pedido para actualizar uma linha na tabela,
-- em vez disso (ver trigger) arquiva a versão anterior da linha e insere
-- uma linha nova com os novos valores
CREATE OR REPLACE FUNCTION "PGHP_2"."unidadesdegestao_update"()
RETURNS TRIGGER AS
$$
DECLARE
	var_geomtype text;
BEGIN
  IF OLD."time_end" IS NOT NULL THEN
    RETURN NULL;
  END IF;
  IF NEW."time_end" IS NULL THEN
    var_geomtype := geometrytype(NEW.geom);
    IF var_geomtype IN ('MULTIPOLYGON', 'POLYGON') THEN
      INSERT INTO "PGHP_2"."unidadesdegestao_poligonos" ("oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."nome",OLD."act_uso",OLD."act_composicao",OLD."prop_uso",OLD."prop_composicao", OLD."prop_data_limite",OLD."geom",OLD."time_start",current_timestamp,user);
    ELSIF var_geomtype IN ('LINESTRING', 'MULTILINESTRING') THEN
      INSERT INTO "PGHP_2"."unidadesdegestao_linhas" ("oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."nome",OLD."act_uso",OLD."act_composicao",OLD."prop_uso",OLD."prop_composicao", OLD."prop_data_limite",OLD."geom",OLD."time_start",current_timestamp,user);
    ELSE
      INSERT INTO "PGHP_2"."unidadesdegestao_pontos" ("oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."nome",OLD."act_uso",OLD."act_composicao",OLD."prop_uso",OLD."prop_composicao", OLD."prop_data_limite",OLD."geom",OLD."time_start",current_timestamp,user);
    END IF;
    NEW."time_start" = current_timestamp;
    -- se o oid for alterado manualmente para null é-lhe atribuído o próximo numero na sequencia
    -- o uso do -1 está relacionado com dificuldades em atribuir null no qgis
    IF NEW."oid" = -1 THEN 
      NEW."oid" = nextval('"PGHP_2".unidadesdegestao_oid_seq'::regclass);
    END IF;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- Esta função, faz com que quando é pedido para inserir uma linha na tabela,
-- sejam actualizados os campos de versioning time_start, time_end e user_update
CREATE OR REPLACE FUNCTION "PGHP_2"."unidadesdegestao_insert"()
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
    NEW."oid" = nextval('"PGHP_2".unidadesdegestao_oid_seq'::regclass);
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- RULES E TRIGGER PONTOS
/**CREATE RULE "unidadesdegestao_pontos_del" AS ON DELETE TO "PGHP_2"."unidadesdegestao_pontos"
DO INSTEAD UPDATE "PGHP_2"."unidadesdegestao_pontos" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "unidadesdegestao_update" BEFORE UPDATE ON "PGHP_2"."unidadesdegestao_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_update"();

CREATE TRIGGER "unidadesdegestao_insert" BEFORE INSERT ON "PGHP_2"."unidadesdegestao_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_insert"();**/

-- LINHAS
CREATE RULE "unidadesdegestao_linhas_del" AS ON DELETE TO "PGHP_2"."unidadesdegestao_linhas"
DO INSTEAD UPDATE "PGHP_2"."unidadesdegestao_linhas" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "unidadesdegestao_update" BEFORE UPDATE ON "PGHP_2"."unidadesdegestao_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_update"();

CREATE TRIGGER "unidadesdegestao_insert" BEFORE INSERT ON "PGHP_2"."unidadesdegestao_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_insert"();

--POLIGONOS
CREATE RULE "unidadesdegestao_poligonos_del" AS ON DELETE TO "PGHP_2"."unidadesdegestao_poligonos"
DO INSTEAD UPDATE "PGHP_2"."unidadesdegestao_poligonos" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "unidadesdegestao_update" BEFORE UPDATE ON "PGHP_2"."unidadesdegestao_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_update"();

CREATE TRIGGER "unidadesdegestao_insert" BEFORE INSERT ON "PGHP_2"."unidadesdegestao_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP_2"."unidadesdegestao_insert"();

--CRIAR VIEWS para cada tipo de unidade de gestão

-- Poligonos
CREATE OR REPLACE VIEW "PGHP_2".unidadesdegestao_poligonos_current AS
SELECT	"gid", "oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom"::Geometry(MULTIPOLYGON, 3763),"time_start","time_end","user_update"
FROM	"PGHP_2"."unidadesdegestao_poligonos"
WHERE	"time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP_2".unidadesdegestao_poligonos_current DO INSTEAD
  DELETE FROM "PGHP_2"."unidadesdegestao_poligonos" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP_2".unidadesdegestao_poligonos_current DO INSTEAD
  INSERT INTO "PGHP_2"."unidadesdegestao_poligonos" ("oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",NEW."nome",NEW."act_uso",NEW."act_composicao",NEW."prop_uso",NEW."prop_composicao", NEW."prop_data_limite",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP_2".unidadesdegestao_poligonos_current DO INSTEAD
  UPDATE "PGHP_2"."unidadesdegestao_poligonos"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","nome" = NEW."nome","act_uso" = NEW."act_uso","act_composicao" = NEW."act_composicao","prop_uso" = NEW."prop_uso","prop_composicao" = NEW."prop_composicao","prop_data_limite" = NEW."prop_data_limite","geom" = NEW."geom"
    WHERE gid = OLD."gid";

-- Linhas
-- DROP VIEW "PGHP_2".unidadesdegestao_linhas_current CASCADE;
CREATE OR REPLACE VIEW "PGHP_2".unidadesdegestao_linhas_current AS
SELECT	"gid", "oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom"::Geometry(MULTILINESTRING, 3763),"time_start","time_end","user_update"
FROM	"PGHP_2"."unidadesdegestao_linhas"
WHERE	"time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP_2".unidadesdegestao_linhas_current DO INSTEAD
  DELETE FROM "PGHP_2"."unidadesdegestao_linhas" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP_2".unidadesdegestao_linhas_current DO INSTEAD
  INSERT INTO "PGHP_2"."unidadesdegestao_linhas" ("oid","uniterr_oid","nome","act_uso","act_composicao","prop_uso","prop_composicao","prop_data_limite","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",NEW."nome",NEW."act_uso",NEW."act_composicao",NEW."prop_uso",NEW."prop_composicao", NEW."prop_data_limite",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP_2".unidadesdegestao_linhas_current DO INSTEAD
  UPDATE "PGHP_2"."unidadesdegestao_linhas"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","nome" = NEW."nome","act_uso" = NEW."act_uso","act_composicao" = NEW."act_composicao","prop_uso" = NEW."prop_uso","prop_composicao" = NEW."prop_composicao","prop_data_limite" = NEW."prop_data_limite","geom" = NEW."geom"
    WHERE gid = OLD."gid";