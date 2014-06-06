
-- USAGE EXAMPLE
-- the original table
-- ATTENTION: for now, the name "gid" must be always used as primary key
CREATE TABLE "PGHP_2".testes_versioning(
gid serial primary key,
descr varchar(40),
geom geometry(MULTIPOLYGON,3763)
);

CREATE INDEX testes_versioning_idx
  ON "PGHP_2".testes_versioning
  USING gist
  (geom);

-- Make table versionable
-- This will create the versioning fields, backup table and related triggers

SELECT vsr_add_versioning_to('"PGHP_2".testes_versioning');

-- Remove versioning from table
-- This will remove versioning fields, backup table and related triggers 

SELECT vsr_remove_versioning_from('"PGHP_2".testes_versioning');

-- See table content at certain time
SELECT * from vsr_table_at_time (NULL::"PGHP_2".testes_versioning, '2014-06-04 16:10:00');

-- See specific feature at certain time
SELECT * from vsr_table_at_time (NULL::"PGHP_2".testes_versioning, '2014-04-19 18:26:57') WHERE gid = 1;
