/*DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesterritoriais CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".usos CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesterritoriais_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao_linhas_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao_poligonos_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".acao_tipo CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".acoes CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".acoes_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".acoes_detalhe CASCADE;
   DROP TABLE IF EXISTS "PGHP_2".acoes_detalhe_bk CASCADE;*/


-- UNIDADES TERRITORIAIS --
/** Unidades territoriais representam as macro unidades que devem ser geridas como um todo
    Exemplo disso são Quinta do Pisão, Pedra amarela Campo base, Duna da Cresmina, etc... **/

CREATE TABLE "PGHP".unidadesterritoriais
(
  gid serial PRIMARY KEY,
  oid serial UNIQUE,
  nome character varying(50) UNIQUE NOT NULL,
  descricao character varying(255),
  geom geometry(MultiPolygon, 3763)
);

CREATE INDEX unidadesterritoriais_gist
  ON "PGHP".unidadesterritoriais
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP".unidadesterritoriais');

-- UNIDADES DE GESTAO --
/** Unidades de gestão representam áreas homogéneas tanto em termos de proposta de ocupação,
    quer no conjunto de acções que se preconizam de futuro, devem ser criadas em sede de planeamento
    de forma concertada entre os vários interveniente e responsáveis antes de se definir acções **/

-- Criação de tabelas auxiliares referente aos possíveis usos do solo
DROP TABLE "PGHP".usos
CREATE TABLE "PGHP".usos (
  oid serial PRIMARY KEY,
  nome character varying(30) UNIQUE
);

-- tabela de unidades de gestão geral (parent)
CREATE TABLE "PGHP".unidadesdegestao
(
  gid serial PRIMARY KEY,
  oid serial UNIQUE NOT NULL,
  uniterr_oid integer REFERENCES "PGHP".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
  nome character varying(40),
  act_uso character varying(30) REFERENCES "PGHP".usos(nome) ON UPDATE CASCADE ON DELETE RESTRICT,
  act_composicao character varying(50),
  prop_uso character varying(30) REFERENCES "PGHP".usos(nome) ON UPDATE CASCADE ON DELETE RESTRICT,
  prop_composicao character varying(50),
  prop_data_limite timestamp without time zone,
  geom geometry(geometry, 3763),
  obs character varying
);

CREATE INDEX unidadesdegestao_idx
  ON "PGHP".unidadesdegestao
  USING gist
  (geom);

-- Tabela inherits das unidades de gestao para geometrias de linhas (child)
CREATE TABLE "PGHP".unidadesdegestao_linhas
(
	-- colocar constraint na geometria para aceitar só linhas
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTILINESTRING'::text),
	-- constraints da tabela parent têm de ser refeitas nas tabelas child
	CONSTRAINT unidadesdegestao_linhas_pk PRIMARY KEY (gid),
	CONSTRAINT unidadesdegestao_linhas_oid_key UNIQUE (oid),
	CONSTRAINT unidadesdegestao_unidadesterritoriais_fkey FOREIGN KEY (uniterr_oid) REFERENCES "PGHP".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (act_uso) REFERENCES "PGHP".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (prop_uso) REFERENCES "PGHP".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT
)
	INHERITS ("PGHP".unidadesdegestao);

-- Em tabelas child os índices têm de ser recriados
CREATE INDEX unidadesdegestao_linhas_idx
  ON "PGHP".unidadesdegestao_linhas
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP".unidadesdegestao_linhas');

-- Tabela das unidades de gestao para geometrias de polígonos (child)
CREATE TABLE "PGHP".unidadesdegestao_poligonos
(
	-- colocar constraint na geometria para aceitar só linhas
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTIPOLYGON'::text),
	-- constraints da tabela parent têm de ser refeitas nas tabelas child
	CONSTRAINT unidadesdegestao_poligonos_pk PRIMARY KEY (gid),
	CONSTRAINT unidadesdegestao_poligonos_oid_key UNIQUE (oid),
	CONSTRAINT unidadesdegestao_unidadesterritoriais_fkey FOREIGN KEY (uniterr_oid) REFERENCES "PGHP".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (act_uso) REFERENCES "PGHP".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (prop_uso) REFERENCES "PGHP".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT
)
	INHERITS ("PGHP".unidadesdegestao);

-- Em tabelas child os índices têm de ser recriados
CREATE INDEX unidadesdegestao_poligonos_idx
  ON "PGHP".unidadesdegestao_poligonos
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP".unidadesdegestao_poligonos');

-- Workaround to assign default sequential value to an empty oid field instead of Zero
-- Useful when the feature geometry is split and you want to keep one of the oid to one part and default values to the others

-- Function to replace oid zero values
CREATE OR REPLACE FUNCTION "PGHP".update_oid()
RETURNS trigger AS
$$
BEGIN
	IF NEW.oid = 0 THEN
		NEW.oid = nextval('"PGHP".unidadesdegestao_oid_seq'::regclass);
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

-- Trigger Function to replace oid zero values
CREATE TRIGGER update_oid_trg
  BEFORE INSERT OR UPDATE OF oid ON "PGHP".unidadesdegestao_linhas
  FOR EACH ROW
  EXECUTE PROCEDURE "PGHP".update_oid();

CREATE TRIGGER update_oid_trg
  BEFORE INSERT OR UPDATE OF oid ON "PGHP".unidadesdegestao_poligonos
  FOR EACH ROW
  EXECUTE PROCEDURE "PGHP".update_oid();


-- ACÇÕES --

-- tabelas auxiliares --  

CREATE TABLE "PGHP".acao_tipo (
  oid SERIAL PRIMARY KEY,
  nome character varying(40) UNIQUE
);

-- tabela espacial
CREATE TABLE "PGHP".acoes_detalhe (
  gid SERIAL PRIMARY KEY,
  geom geometry(MultiPolygon,3763)
);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP".acoes_detalhe');

-- tabela das accoes
CREATE TABLE "PGHP".acoes(
  gid SERIAL PRIMARY KEY,
  data_prev_inicio timestamp without time zone,
  data_prev_fim timestamp without time zone,
  uniges_oid INTEGER REFERENCES "PGHP".unidadesdegestao(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
  tipo character varying(40) REFERENCES "PGHP".acao_tipo(nome) ON UPDATE CASCADE ON DELETE RESTRICT,
  descricao character varying(255),
  entidade character varying(30),
  responsavel character varying(30),
  custo numeric(20,2),
  areas_detalhe_gid integer REFERENCES "PGHP".acoes_detalhe(gid) ON UPDATE CASCADE ON DELETE RESTRICT,
  data_exec_inicio timestamp without time zone,
  data_exec_fim timestamp without time zone
);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP".acoes');

-- View para espacializar as acções
CREATE OR REPLACE VIEW "PGHP".geo_acoes AS 
 SELECT a.gid, a.data_prev_inicio, a.data_prev_fim, a.uniges_oid, a.tipo, a.descricao, 
    a.entidade, a.responsavel, a.custo, a.areas_detalhe_gid, a.data_exec_inicio, a.data_exec_fim,
        CASE
            WHEN a.areas_detalhe_gid IS NULL THEN u.geom
            ELSE d.geom
        END AS geom
   FROM "PGHP".acoes a
   LEFT JOIN "PGHP".acoes_detalhe d ON a.areas_detalhe_gid = d.gid
   LEFT JOIN "PGHP".unidadesdegestao u ON a.uniges_oid = u.oid;

-- ::FIXME 


-- Siglas para composição
CREATE TABLE "PGHP".uso_siglas (
gid SERIAL PRIMARY KEY,
tipo varchar(10),
sigla varchar(5),
nome varchar(40)
);
