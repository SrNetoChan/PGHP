WITH f as (
SELECT st_transform(geom,3763)::geometry(Multipolygon,3763) as geom
FROM "PGHP".unidadesterritoriais
WHERE oid = 4)
SELECT g.gid as gid_temp, 4 as uniterr_oid, (g.cosn3 || '-' ||t.descricao) as nome, St_Intersection(st_transform(g.geom,3763),f.geom) as geom  FROM cosc.cosc09 as g JOIN f ON (St_Intersects(st_transform(g.geom,3763),f.geom)) JOIN cosc.nomenclatura_cosn3 as t ON (g.cosn3 = t.cosn3)