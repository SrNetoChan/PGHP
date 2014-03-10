INSERT INTO "PGHP".unidadesterritoriais (nome) VALUES
('Quinta do Pisão'),
('Pedra Amarela campo base'),
('Duna da Cresmina');

INSERT INTO "PGHP".limites (uniterr_oid, nome, geom)
SELECT
uniterr_oid,
nome,
geom
FROM "PGHP".limites_bk