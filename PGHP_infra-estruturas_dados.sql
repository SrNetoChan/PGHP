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
('Vedacoes','Elétrica fixa'),
('Vedacoes','Elétrica amovível'),
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



