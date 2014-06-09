/*DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesterritoriais CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".usos CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesdegestao_bk CASCADE;
  DROP TABLE IF EXISTS "PGHP_2".unidadesterritoriais_bk CASCADE; */


-- UNIDADES TERRITORIAIS --
/** Unidades territoriais representam as macro unidades que devem ser geridas como um todo
    Exemplo disso são Quinta do Pisão, Pedra amarela Campo base, Duna da Cresmina, etc... **/


CREATE TABLE "PGHP_2".unidadesterritoriais
(
  gid serial PRIMARY KEY,
  oid serial UNIQUE,
  nome character varying(50) UNIQUE NOT NULL,
  descricao character varying(255),
  geom geometry(MultiPolygon, 3763)
);

CREATE INDEX unidadesterritoriais_gist
  ON "PGHP_2".unidadesterritoriais
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP_2".unidadesterritoriais');

-- UNIDADES DE GESTAO --
/** Unidades de gestão representam áreas homogéneas tanto em termos de proposta de ocupação,
    quer no conjunto de acções que se preconizam de futuro, devem ser criadas em sede de planeamento
    de forma concertada entre os vários interveniente e responsáveis antes de se definir acções **/

-- Criação de tabelas auxiliares referente aos possíveis usos do solo
CREATE TABLE "PGHP_2".usos (
  oid serial PRIMARY KEY,
  nome character varying(30) UNIQUE NOT NULL
);

-- tabela de unidades de gestão geral (parent)
CREATE TABLE "PGHP_2".unidadesdegestao
(
  gid serial PRIMARY KEY,
  oid serial UNIQUE NOT NULL,
  uniterr_oid integer REFERENCES "PGHP_2".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
  nome character varying(40),
  act_uso character varying(30) REFERENCES "PGHP_2".usos(nome) ON UPDATE CASCADE ON DELETE RESTRICT,
  act_composicao character varying(50),
  prop_uso character varying(30) REFERENCES "PGHP_2".usos(nome) ON UPDATE CASCADE ON DELETE RESTRICT,
  prop_composicao character varying(50),
  prop_data_limite date,
  geom geometry(geometry, 3763)
);

CREATE INDEX unidadesdegestao_idx
  ON "PGHP_2".unidadesdegestao
  USING gist
  (geom);

-- Tabela inherits das unidades de gestao para geometrias de linhas (child)
CREATE TABLE "PGHP_2".unidadesdegestao_linhas
(
	-- colocar constraint na geometria para aceitar só linhas
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTILINESTRING'::text),
	-- constraints da tabela parent têm de ser refeitas nas tabelas child
	CONSTRAINT unidadesdegestao_linhas_pk PRIMARY KEY (gid),
	CONSTRAINT unidadesdegestao_linhas_oid_key UNIQUE (oid),
	CONSTRAINT unidadesdegestao_unidadesterritoriais_fkey FOREIGN KEY (uniterr_oid) REFERENCES "PGHP_2".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (act_uso) REFERENCES "PGHP_2".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (prop_uso) REFERENCES "PGHP_2".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT
)
	INHERITS ("PGHP_2".unidadesdegestao);

-- Em tabelas child os índices têm de ser recriados
CREATE INDEX unidadesdegestao_linhas_idx
  ON "PGHP_2".unidadesdegestao_linhas
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP_2".unidadesdegestao_linhas');

-- Tabela das unidades de gestao para geometrias de polígonos (child)
CREATE TABLE "PGHP_2".unidadesdegestao_poligonos
(
	-- colocar constraint na geometria para aceitar só linhas
	CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = 'MULTIPOLYGON'::text),
	-- constraints da tabela parent têm de ser refeitas nas tabelas child
	CONSTRAINT unidadesdegestao_poligonos_pk PRIMARY KEY (gid),
	CONSTRAINT unidadesdegestao_poligonos_oid_key UNIQUE (oid),
	CONSTRAINT unidadesdegestao_unidadesterritoriais_fkey FOREIGN KEY (uniterr_oid) REFERENCES "PGHP_2".unidadesterritoriais(oid) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_act_uso_fkey FOREIGN KEY (act_uso) REFERENCES "PGHP_2".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT unidadesdegestao_linhas_prop_uso_fkey FOREIGN KEY (prop_uso) REFERENCES "PGHP_2".usos (nome) ON UPDATE CASCADE ON DELETE RESTRICT
)
	INHERITS ("PGHP_2".unidadesdegestao);

-- Em tabelas child os índices têm de ser recriados
CREATE INDEX unidadesdegestao_poligonos_idx
  ON "PGHP_2".unidadesdegestao_poligonos
  USING gist
  (geom);

-- Criar versioning --

SELECT vsr_add_versioning_to('"PGHP_2".unidadesdegestao_poligonos');