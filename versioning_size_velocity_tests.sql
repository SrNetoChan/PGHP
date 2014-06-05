-- TESTES COM O MASTER --

CREATE TABLE teste_vrs_master AS
SELECT * FROM bases.planimetriapoligonos2010

SELECT vsr_add_versioning_to('teste_vrs_master'); -- 15 seg

UPDATE teste_vrs_master
set shape_area = st_area(geom); -- 60 seg

DELETE FROM teste_vrs_master
WHERE tipo = 'Equipamento'; -- 0,3 seg

UPDATE teste_vrs_master
set geom = st_multi(St_buffer(geom,5))
WHERE tipo = 'Edifício'; -- 91 seg

UPDATE teste_vrs_master
set shape_area = (st_area(geom))/10000; -- 75 seg

SELECT * from vsr_table_at_time (NULL::teste_vrs_master, '2014-06-05 15:08:23.0'); 9,2 seg


-- TESTES COM O SPACE --

CREATE TABLE teste_vrs_space AS
SELECT * FROM bases.planimetriapoligonos2010

SELECT vsr_add_versioning_to('teste_vrs_space'); -- 7 seg

UPDATE teste_vrs_space
set shape_area = st_area(geom); -- 49 seg

DELETE FROM teste_vrs_space
WHERE tipo = 'Equipamento'; -- 0,5 seg

UPDATE teste_vrs_space
set geom = st_multi(St_buffer(geom,5))
WHERE tipo = 'Edifício'; -- 88 seg

UPDATE teste_vrs_space
set shape_area = (st_area(geom))/10000; -- 60 seg

SELECT * from vsr_table_at_time (NULL::teste_vrs_space, '2014-06-05 15:44:10.0'); --25 seg

-- TESTES SEM VERSIONING

CREATE TABLE teste_vrs_no_versioning AS
SELECT * FROM bases.planimetriapoligonos2010

UPDATE teste_vrs_no_versioning
set shape_area = st_area(geom); -- 4 seg

DELETE FROM teste_vrs_no_versioning
WHERE tipo = 'Equipamento'; -- 0,3 seg

UPDATE teste_vrs_no_versioning
set geom = st_multi(St_buffer(geom,5))
WHERE tipo = 'Edifício'; -- 40,8 seg

UPDATE teste_vrs_no_versioning
set shape_area = (st_area(geom))/10000; -- 11,7 seg


SELECT t.oid, n.nspname as schema_name, relname::char(35) as Table_Name,
     pg_size_pretty(pg_total_relation_size(t.oid))::VARCHAR(15) as Total_Table_Size
FROM pg_class as t JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
WHERE relname like 'teste_vrs%'

