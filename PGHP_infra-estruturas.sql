/* INFRA-ESTRUTURAS */
-- Criação de tabelas auxiliares
CREATE TABLE "PGHP".infraestruturas_classe_tipo
(
oid serial primary key,
classe character varying(40),
tipo character varying(40)
);
-- ver possibilidade de criar views, rules e trigger automáticos para cada nova classe criada (ver postgis in action)

-- Indice para garantir que não existem valores repetidos
CREATE UNIQUE INDEX infraestruturas_tipo_idx ON "PGHP".infraestruturas_classe_tipo (classe, tipo);

CREATE OR REPLACE VIEW

CREATE TABLE "PGHP".infraestruturas_estado
(
oid serial primary key,
estado character varying(40) UNIQUE
);


CREATE TABLE "PGHP".infraestruturas_accoes
(
oid serial primary key,
accao character varying(40) UNIQUE
);

-- Criar tabela das infraestrutura (parent)

--DROP TABLE "PGHP".infraestruturas CASCADE;
--TRUNCATE TABLE "PGHP".infraestruturas RESTART IDENTITY;

CREATE TABLE "PGHP".infraestruturas
(
	gid serial primary key,
	oid serial, -- número de identificação da infraestrutura
	uniterr_oid integer REFERENCES "PGHP".unidadesterritoriais(oid),
	classe character varying(40),
	tipo character varying(40),
	nome character varying(40),
	cadeado boolean,
	estado character varying(40) REFERENCES "PGHP".infraestruturas_estado(estado),
	accao character varying(40) REFERENCES "PGHP".infraestruturas_accoes(accao),
	observacoes character varying,
	geom geometry(geometry, 3763),
	time_start timestamp, -- data de criação da linha
	time_end timestamp, -- data de "eliminação" da linha
	user_update character varying(40) -- nome de utilizador que criou, alterou ou eliminou a linha
);

CREATE INDEX infraestruturas_idx
  ON "PGHP".infraestruturas
  USING gist
  (geom);

-- criar indices para a class, para o oid
-- criar indices para time_start e time_stop? 

-- Tabela das infra-estruturas para geometrias de pontos (child)
CREATE TABLE "PGHP".infraestruturas_pontos
(
	--geom geometry(POINT, 3763),
	CONSTRAINT infraestruturas_pontos_pk PRIMARY KEY (gid),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'POINT'::text),
	CONSTRAINT infraestruturas_pontos_estado_fkey FOREIGN KEY (estado) REFERENCES "PGHP".infraestruturas_estado (estado),
	CONSTRAINT infraestruturas_pontos_accao_fkey FOREIGN KEY (accao) REFERENCES "PGHP".infraestruturas_accoes (accao),
	CONSTRAINT infraestruturas_pontos_uniterr_oid_fkey FOREIGN KEY (uniterr_oid) REFERENCES"PGHP".unidadesterritoriais(oid)
)
	INHERITS ("PGHP".infraestruturas);

-- Em tabelas com inherits, tanto CONSTRAINTs como INDEXes tem de ser recriadas
CREATE INDEX infraestruturas_pontos_idx
  ON "PGHP".infraestruturas_pontos
  USING gist
  (geom);

-- Tabela das infra-estruturas para geometrias de linhas (child)
CREATE TABLE "PGHP".infraestruturas_linhas
(
	--geom geometry(MULTILINESTRING, 3763),
	CONSTRAINT infraestruturas_linhas_pk PRIMARY KEY (gid),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTILINESTRING'::text),
	CONSTRAINT infraestruturas_linhas_estado_fkey FOREIGN KEY (estado) REFERENCES "PGHP".infraestruturas_estado (estado),
	CONSTRAINT infraestruturas_linhas_accao_fkey FOREIGN KEY (accao) REFERENCES "PGHP".infraestruturas_accoes (accao),
	CONSTRAINT infraestruturas_linhas_uniterr_oid_fkey FOREIGN KEY (uniterr_oid) REFERENCES"PGHP".unidadesterritoriais(oid)
)
	INHERITS ("PGHP".infraestruturas);

-- Em tabelas com inherits, tanto CONSTRAINTs como INDEXes tem de ser recriadas
CREATE INDEX infraestruturas_linhas_idx
  ON "PGHP".infraestruturas_linhas
  USING gist
  (geom);

-- Tabela das infra-estruturas para geometrias de polígonos (child)
CREATE TABLE "PGHP".infraestruturas_poligonos
(
	--geom geometry(MULTIPOLYGON, 3763),
	CONSTRAINT infraestruturas_poligonos_pk PRIMARY KEY (gid),
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTIPOLYGON'::text),
	CONSTRAINT infraestruturas_poligonos_estado_fkey FOREIGN KEY (estado) REFERENCES "PGHP".infraestruturas_estado (estado),
	CONSTRAINT infraestruturas_poligonos_accao_fkey FOREIGN KEY (accao) REFERENCES "PGHP".infraestruturas_accoes (accao),
	CONSTRAINT infraestruturas_poligonos_uniterr_oid_fkey FOREIGN KEY (uniterr_oid) REFERENCES"PGHP".unidadesterritoriais(oid)
)
	INHERITS ("PGHP".infraestruturas);

-- Em tabelas com inherits, tanto CONSTRAINTs como INDEXes tem de ser recriadas
CREATE INDEX infraestruturas_poligonos_idx
  ON "PGHP".infraestruturas_poligonos
  USING gist
  (geom);

-- Criar versioning --

-- View com estado actual da tabela geral das infraestruturas (i.e. a linha não foi eliminada)
CREATE OR REPLACE VIEW "PGHP"."infraestruturas_current" AS
  SELECT
    "gid",
    "oid",
    "uniterr_oid",
    "classe",
    "tipo",
    "nome",
    "cadeado",
    "estado",
    "accao",
    "observacoes",
    "geom",
    "time_start",
    "time_end",
    "user_update"
  FROM "PGHP"."infraestruturas"
  WHERE "time_end" IS NULL;

-- Função para visualizar tabela em determinado dia/hora (usado apenas pela administração para resolver problemas)
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_at_time"(timestamp without time zone)
RETURNS SETOF "PGHP"."infraestruturas_current" AS
$$
SELECT "gid","oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","time_start","time_end","user_update" FROM "PGHP"."infraestruturas" WHERE
  ( SELECT CASE WHEN "time_end" IS NULL THEN ("time_start" <= $1) ELSE ("time_start" <= $1 AND "time_end" > $1) END );
$$
LANGUAGE 'sql';

-- Criar triggers e respectivas funções para implementar o versioning nas tabelas --

-- Esta função, faz com que quando é pedido para actualizar uma linha na tabela,
-- em vez disso (ver trigger) arquiva a versão anterior da linha e insere
-- uma linha nova com os novos valores
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_update"()
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
      INSERT INTO "PGHP"."infraestruturas_poligonos" ("oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."time_start",current_timestamp,user);
    ELSIF var_geomtype IN ('LINESTRING', 'MULTILINESTRING') THEN
      INSERT INTO "PGHP"."infraestruturas_linhas" ("oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."time_start",current_timestamp,user);
    ELSE
      INSERT INTO "PGHP"."infraestruturas_pontos" ("oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom","time_start","time_end","user_update")
      VALUES (OLD."oid",OLD."uniterr_oid",OLD."classe",OLD."tipo",OLD."nome",OLD."cadeado",OLD."estado",OLD."accao",OLD."observacoes",OLD."geom",OLD."time_start",current_timestamp,user);
    END IF;
    NEW."time_start" = current_timestamp;
    -- se o oid for alterado manualmente para null é-lhe atribuído o próximo numero na sequencia
    -- o uso do -1 está relacionado com dificuldades em atribuir null no qgis
    IF NEW."oid" = -1 THEN 
      NEW."oid" = nextval('"PGHP".infraestruturas_oid_seq'::regclass);
    END IF;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- Esta função, faz com que quando é pedido para inserir uma linha na tabela,
-- sejam actualizados os campos de versioning time_start, time_end e user_update
CREATE OR REPLACE FUNCTION "PGHP"."infraestruturas_insert"()
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
    NEW."oid" = nextval('"PGHP".infraestruturas_oid_seq'::regclass);
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- RULES E TRIGGER PONTOS
CREATE RULE "infraestruturas_pontos_del" AS ON DELETE TO "PGHP"."infraestruturas_pontos"
DO INSTEAD UPDATE "PGHP"."infraestruturas_pontos" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_pontos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

-- LINHAS
CREATE RULE "infraestruturas_linhas_del" AS ON DELETE TO "PGHP"."infraestruturas_linhas"
DO INSTEAD UPDATE "PGHP"."infraestruturas_linhas" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_linhas"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

--POLIGONOS
CREATE RULE "infraestruturas_poligonos_del" AS ON DELETE TO "PGHP"."infraestruturas_poligonos"
DO INSTEAD UPDATE "PGHP"."infraestruturas_poligonos" SET "time_end" = current_timestamp, "user_update" = user WHERE "gid" = OLD."gid" AND "time_end" IS NULL;

CREATE TRIGGER "infraestruturas_update" BEFORE UPDATE ON "PGHP"."infraestruturas_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_update"();

CREATE TRIGGER "infraestruturas_insert" BEFORE INSERT ON "PGHP"."infraestruturas_poligonos"
FOR EACH ROW EXECUTE PROCEDURE "PGHP"."infraestruturas_insert"();

--CRIAR VIEWS para cada classe
--DROP VIEW "PGHP".infra_portoes CASCADE

-- Portoes
CREATE OR REPLACE VIEW "PGHP".infra_portoes AS
SELECT	"gid", "oid", "uniterr_oid", "tipo", "nome", "cadeado", "estado", "accao", "observacoes", "geom"::Geometry(POINT, 3763),"time_start","time_end","user_update"
FROM	"PGHP"."infraestruturas_pontos"
WHERE	"classe" = 'Portões' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_portoes DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_pontos" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_portoes DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_pontos" ("oid","uniterr_oid","classe","tipo","nome","cadeado","estado","accao","observacoes","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",'Portões',NEW."tipo",NEW."nome",NEW."cadeado",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_portoes DO INSTEAD
  UPDATE "PGHP"."infraestruturas_pontos"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","classe" = 'Portões',"tipo" = NEW."tipo","nome" = NEW."nome","cadeado" = NEW."cadeado","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom" 
    WHERE gid = OLD."gid";

-- Sinaletica
CREATE OR REPLACE VIEW "PGHP".infra_sinaletica AS
SELECT	"gid", "oid", "uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom"::Geometry(POINT, 3763),"time_start","time_end","user_update"
FROM	"PGHP"."infraestruturas_pontos"
WHERE	"classe" = 'Sinalética' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_sinaletica DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_pontos" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_sinaletica DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_pontos" ("oid","uniterr_oid","classe","tipo","nome","estado","accao","observacoes","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",'Sinalética',NEW."tipo",NEW."nome",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_sinaletica DO INSTEAD
  UPDATE "PGHP"."infraestruturas_pontos"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","classe" = 'Sinalética',"tipo" = NEW."tipo","nome" = NEW."nome","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom" 
    WHERE gid = OLD."gid";

-- Vedacoes
CREATE OR REPLACE VIEW "PGHP".infra_vedacoes AS
SELECT	"gid", "oid", "uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom"::Geometry(MULTILINESTRING, 3763),"time_start","time_end","user_update"
FROM	"PGHP"."infraestruturas_linhas"
WHERE	"classe" = 'Vedações' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_vedacoes DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_linhas" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_vedacoes DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_linhas" ("oid","uniterr_oid","classe","tipo","nome","estado","accao","observacoes","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",'Vedações',NEW."tipo",NEW."nome",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_vedacoes DO INSTEAD
  UPDATE "PGHP"."infraestruturas_linhas"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","classe" = 'Vedações',"tipo" = NEW."tipo","nome" = NEW."nome","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom" 
    WHERE gid = OLD."gid";

-- Passagens_hidraulicas
CREATE OR REPLACE VIEW "PGHP".infra_passagens_hidraulicas AS
SELECT	"gid", "oid", "uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom"::Geometry(MULTILINESTRING, 3763),"time_start","time_end","user_update"
FROM	"PGHP"."infraestruturas_linhas"
WHERE	"classe" = 'Passagens hidráulicas' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_passagens_hidraulicas DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_linhas" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_passagens_hidraulicas DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_linhas" ("oid","uniterr_oid","classe","tipo","nome","estado","accao","observacoes","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",'Passagens hidráulicas',NEW."tipo",NEW."nome",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_passagens_hidraulicas DO INSTEAD
  UPDATE "PGHP"."infraestruturas_linhas"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","classe" = 'Passagens hidráulicas',"tipo" = NEW."tipo","nome" = NEW."nome","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom" 
    WHERE gid = OLD."gid";

-- edificios
CREATE OR REPLACE VIEW "PGHP".infra_edificios AS
SELECT	"gid", "oid", "uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom"::Geometry(MULTIPOLYGON, 3763),"time_start","time_end","user_update"
FROM	"PGHP"."infraestruturas_poligonos"
WHERE	"classe" = 'Edifícios' AND "time_end" IS NULL;

--CRIAR TRIGGERS E RULES para tornar a VIEW "Editável"
CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO "PGHP".infra_edificios DO INSTEAD
  DELETE FROM "PGHP"."infraestruturas_poligonos" WHERE gid = OLD."gid";
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO "PGHP".infra_edificios DO INSTEAD
  INSERT INTO "PGHP"."infraestruturas_poligonos" ("oid","uniterr_oid","classe","tipo","nome","estado","accao","observacoes","geom")
    VALUES (NEW."oid",NEW."uniterr_oid",'Edifícios',NEW."tipo",NEW."nome",NEW."estado",NEW."accao",NEW."observacoes",NEW."geom");
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO "PGHP".infra_edificios DO INSTEAD
  UPDATE "PGHP"."infraestruturas_poligonos"
    SET "oid" = COALESCE(NEW."oid",-1),"uniterr_oid" = NEW."uniterr_oid","classe" = 'Edifícios',"tipo" = NEW."tipo","nome" = NEW."nome","estado" = NEW."estado","accao" = NEW."accao","observacoes" = NEW."observacoes","geom" = NEW."geom" 
    WHERE gid = OLD."gid";

-- View com todos os pontos a necessitar de reparação
CREATE OR REPLACE VIEW "PGHP".infraestruturas_alertas AS
SELECT
	gid as gid,
	classe as classe,
	tipo as tipo,
	estado as estado,
	accao as accao,
	(ST_PointOnSurface(geom))::Geometry(POINT, 3763) as geom
FROM
	"PGHP".infraestruturas
WHERE
	"time_end" IS NULL and NOT(estado = 'Bom estado') 