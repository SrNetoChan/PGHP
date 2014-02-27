DROP TABLE "PGHP".infraestruturas CASCADE;
TRUNCATE TABLE "PGHP".infraestruturas
-- Criar tabela parente das infraestrutura

CREATE TABLE "PGHP".infraestruturas
(
	infra_oid integer not null,
	uniterr_oid integer REFERENCES "PGHP".unidadesterritoriais(oid),
	classe character varying(40),
	tipo character varying(40),
	nome character varying(40),
	cadeado boolean,
	estado character varying(40) REFERENCES "PGHP".estado_infraestruturas(nome_estado),
	accao character varying(40) REFERENCES "PGHP".accoes_infraestruturas(nome_accao),
	observacoes character varying,
	geom geometry(geometry, 3763),
	"id_hist" serial primary key, --hidden
	"time_start" timestamp, --hidden
	"time_end" timestamp, --hidden
	"user_update" character varying(40) --hidden
);

CREATE INDEX infraestruturas_idx
  ON "PGHP".infraestruturas
  USING gist
  (geom);

-- criar indices para a class, para o infra_oid
-- criar indices para time_start e time_stop? 

CREATE TABLE "PGHP".infraestruturas_pontos
(
	--geom geometry(POINT, 3763),
	CONSTRAINT infraestruturas_pontos_pk PRIMARY KEY (id_hist),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'POINT'::text),
	CONSTRAINT infraestruturas_pontos_estado_fkey FOREIGN KEY (estado) REFERENCES "PGHP".estado_infraestruturas (nome_estado),
	CONSTRAINT infraestruturas_pontos_accao_fkey FOREIGN KEY (accao) REFERENCES "PGHP".accoes_infraestruturas (nome_accao),
	CONSTRAINT infraestruturas_pontos_uniterr_oid_fkey FOREIGN KEY (uniterr_oid) REFERENCES"PGHP".unidadesterritoriais(oid)
)
	INHERITS ("PGHP".infraestruturas);

CREATE INDEX infraestruturas_pontos_idx
  ON "PGHP".infraestruturas_pontos
  USING gist
  (geom);


--ALTER TABLE "PGHP".infraestruturas_pontos
--    ALTER COLUMN geom TYPE geometry(POINT,3763) USING geom;

--UPDATE geometry_columns SET type = 'POINT'-
--WHERE f_table_name = "infraestruturas_pontos" AND f_geometry_column = 'geom';

-- CRIAR VERSIONING
-- View com estado actual da tabela geral das infraestruturas
CREATE VIEW "PGHP"."infraestruturas_current" AS
  SELECT
    "infra_oid",
    "uniterr_oid",
    "classe",
    "tipo",
    "nome",
    "cadeado",
    "estado",
    "accao",
    "observacoes",
    "geom",
    "id_hist",
    "time_start",
    "time_end",
    "user_update"
  FROM "PGHP"."infraestruturas"
  WHERE "time_end" IS NULL;

-- função para ver tabela em determinado dia/hora (usado apenas pela administração para resolver problemas)
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_at_time"(timestamp)
RETURNS SETOF "PGHP"."infraestruturas_current" AS
$$
SELECT "infra_oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","id_hist","time_start","time_end","user_update" FROM "PGHP"."infraestruturas" WHERE
  ( SELECT CASE WHEN "time_end" IS NULL THEN ("time_start" <= $1) ELSE ("time_start" <= $1 AND "time_end" > $1) END );
$$
LANGUAGE 'sql';

-- Criar de trigger para implementar o versioning na tabela -- TENHO DE CRIAR UMA PARA CADA TIPO DE GEOMETRIA
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_update"()
RETURNS TRIGGER AS
$$
DECLARE
	var_geomtype text;
	var_table text;
BEGIN
  IF OLD."time_end" IS NOT NULL THEN
    RETURN NULL;
  END IF;
  IF NEW."time_end" IS NULL THEN
    var_geomtype := geometrytype(NEW.geom);
    IF var_geomtype IN ('MULTIPOLYGON', 'POLYGON') THEN
      INSERT INTO "PGHP"."infraestruturas_poligonos" ("infra_oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","id_hist","time_start","time_end","user_update")
      VALUES (OLD."infra_oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."id_hist",OLD."time_start",current_timestamp,user);
    ELSIF var_geomtype IN ('LINESTRING', 'MULTILINESTRING') THEN
      INSERT INTO "PGHP"."infraestruturas_linhas" ("infra_oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","id_hist","time_start","time_end","user_update")
      VALUES (OLD."infra_oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."id_hist",OLD."time_start",current_timestamp,user);
    ELSE
      INSERT INTO "PGHP"."infraestruturas_pontos" ("infra_oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","id_hist","time_start","time_end","user_update")
      VALUES (OLD."infra_oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."id_hist",OLD."time_start",current_timestamp,user);
    END IF;
    NEW."time_start" = current_timestamp;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- REVER PARA CONSIDERAR a alteração do infra_oid
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_insert"()
RETURNS trigger AS
$$
BEGIN
  if NEW."time_start" IS NULL then
    NEW."time_start" = now();
    NEW."time_end" = null;
    NEW."user_update" = user;
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- RECRIAR ESTES TRIGGERS PARA CADA TABELA CHILD DE PONTOS, LINHAS OU POLIGONOS
CREATE RULE "infraestruturas_del" AS ON DELETE TO "PGHP"."infraestruturas"
DO INSTEAD UPDATE "PGHP"."infraestruturas" SET "time_end" = current_timestamp, "user_update" = user WHERE "id_hist" = OLD."id_hist" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

-- PONTOS
CREATE RULE "infraestruturas_pontos_del" AS ON DELETE TO "PGHP"."infraestruturas_pontos"
DO INSTEAD UPDATE "PGHP"."infraestruturas_pontos" SET "time_end" = current_timestamp, "user_update" = user WHERE "id_hist" = OLD."id_hist" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

-- LINHAS
CREATE RULE "infraestruturas_linhas_del" AS ON DELETE TO "PGHP"."infraestruturas_linhas"
DO INSTEAD UPDATE "PGHP"."infraestruturas_linhas" SET "time_end" = current_timestamp, "user_update" = user WHERE "id_hist" = OLD."id_hist" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

--POLIGONOS
CREATE RULE "infraestruturas_poligonos_del" AS ON DELETE TO "PGHP"."infraestruturas_poligonos"
DO INSTEAD UPDATE "PGHP"."infraestruturas_poligonos" SET "time_end" = current_timestamp, "user_update" = user WHERE "id_hist" = OLD."id_hist" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

-- CRIAR VIEWS para cada classe

CREATE OR REPLACE VIEW "PGHP".infra_portoes AS
SELECT	"infra_oid", "uniterr_oid", "tipo", "nome", "cadeado", "estado", "accao", "observacoes", "geom"::Geometry(POINT, 3763), "id_hist", "time_start", "time_end", "user_update"
FROM	"PGHP"."infraestruturas_pontos"
WHERE	"classe" = 'portoes' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_portoes DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_pontos" WHERE "id_hist" = old."id_hist";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_portoes DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_pontos" ("infra_oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","id_hist","time_start","time_end","user_update") VALUES (NEW."infra_oid",NEW."uniterr_oid",'portoes',NEW."tipo",NEW."nome",NEW."cadeado",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom",nextval('"PGHP".infraestruturas_id_hist_seq'::regclass),NEW."time_start",NEW."time_end",NEW."user_update");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_portoes DO INSTEAD
  UPDATE "PGHP"."infraestruturas_pontos" SET "infra_oid" = NEW."infra_oid","uniterr_oid" = NEW."uniterr_oid","classe" = 'portoes',"tipo" = NEW."tipo","nome" = NEW."nome","cadeado" = NEW."cadeado","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom","id_hist" = NEW."id_hist","time_start" = NEW."time_start","time_end" = NEW."time_end","user_update" = NEW."user_update" WHERE "id_hist" = NEW."id_hist";

























-- criar indíce do parente time_start e time_stop?
CREATE TABLE "PGHP".infraestruturas_linhas
(
	CONSTRAINT infraestruturas_linhas_pk PRIMARY KEY (id_hist),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTILINESTRING'::text)
)
	INHERITS ("PGHP".infraestruturas);
	
-- recriar indices da parente

CREATE TABLE "PGHP".infraestruturas_poligonos
(
	CONSTRAINT infraestruturas_linhas_pk PRIMARY KEY (id_hist),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTIPOLYGON'::text)
)
	INHERITS ("PGHP".infraestruturas);






