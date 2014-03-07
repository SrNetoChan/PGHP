/* INFRA-ESTRUTURAS */
/* carregar dados */
-- tabelas auxiliares --
INSERT INTO "PGHP".infraestruturas_classe_tipo (classe, tipo) VALUES
(NULL, NULL),
('Portões','Portão'),
('Portões','Cancela'),
('Sinalética','Placard interpretativo'),
('Sinalética','Placard informativo'),
('Sinalética','Postes direccionais'),
('Sinalética','Sinais de trânsito'),
('Sinalética','Identificação de espécies'),
('Sinalética','Talhões oxigénio'),
('Vedações','Elétrica fixa'),
('Vedações','Elétrica amovível'),
('Vedações','Rede ovelheira'),
('Edifícios','Edifício'),
('Passagens hidráulicas','Passagem hidráulica');

INSERT INTO "PGHP".infraestruturas_estado (estado) VALUES
(NULL),
('Bom estado'),
('Danificado'),
('Em ruínas'),
('Proposto'),
('Desactualizado');

INSERT INTO "PGHP".infraestruturas_accoes (accao) VALUES 
(NULL),
('Manter'),
('Reparar'),
('Recuperar'),
('Substituir'),
('Retirar');

-- Inserir dados antigos
INSERT INTO "PGHP".infra_portoes ("uniterr_oid", "tipo", "nome", "cadeado", "estado", "accao", "observacoes", "geom")
SELECT 
1, tipo, nome, cadeado,estado, accao, observacoes, geom
from "PGHP".portoes;

INSERT INTO "PGHP".infra_sinaletica ("uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom")
SELECT 
1, tipo, nome, estado, accao, observacoes, geom
from "PGHP".sinaletica;

INSERT INTO "PGHP".infra_vedacoes ("uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom")
SELECT 
1, tipo, NULL, estado, accao, observacoes, geom
from "PGHP".vedacoes;

INSERT INTO "PGHP".infra_passagens_hidraulicas ("uniterr_oid", "tipo", "nome", "estado", "accao", "observacoes", "geom")
SELECT 
1, tipo, NULL, estado, accao, observacoes, geom
from "PGHP".passagens_hidraulicas;
