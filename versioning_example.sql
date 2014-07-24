
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



WITH g as
(
SELECT gid, descr, valor, valor_dec, geom FROM "PGHP_2".testes_versioning_bk WHERE vrs_start_time <= '2014-06-11 11:26:0' and vrs_end_time >= '2014-06-11 11:26:0'
UNION ALL
SELECT gid, descr, valor, valor_dec, geom FROM "PGHP_2".testes_versioning WHERE vrs_start_time <= '2014-06-11 11:26:0'
UNION ALL
SELECT gid, descr, valor, valor_dec, geom FROM "PGHP_2".testes_versioning_bk WHERE vrs_end_time >= '2014-06-11 11:26:0'
)
SELECT gid, first(descr), first(valor), first(valor_dec), first(geom)
FROM g
GROUP BY gid

with actual as
(
SELECT
	gid, descr, valor, valor_dec, geom, vrs_start_time
FROM
	"PGHP_2".testes_versioning
WHERE vrs_start_time <= '2014-06-12 11:01:00'
),
incomplete as
(
SELECT 
	gid, descr, valor, valor_dec, geom, vrs_start_time
FROM
	"PGHP_2".testes_versioning_bk
WHERE
	vrs_start_time <= '2014-06-12 11:01:00' and vrs_end_time >= '2014-06-12 11:01:0'
),
old_backup as
(
SELECT 
	gid, descr, valor, valor_dec, geom, vrs_start_time
FROM
	"PGHP_2".testes_versioning_bk
WHERE 
	gid in (SELECT distinct gid from incomplete)
),
old_table as
(
SELECT 
	gid, descr, valor, valor_dec, geom, vrs_start_time
FROM
	"PGHP_2".testes_versioning
WHERE
	gid in (SELECT distinct gid from incomplete)
)
SELECT * FROM actual
UNION ALL
SELECT * FROM incomplete
UNION ALL
SELECT * FROM old_backup
UNION ALL
SELECT * FROM old_table

WITH tudo as
(SELECT 
	gid, descr, valor, valor_dec, geom, vrs_start_time, vrs_end_time
 FROM
	"PGHP_2".testes_versioning_bk
UNION ALL
 SELECT
	gid, descr, valor, valor_dec, geom, vrs_start_time,NULL
 FROM "PGHP_2".testes_versioning
)
SELECT gid, descr, valor, valor_dec, geom, vrs_start_time, vrs_end_time
FROM tudo
WHERE gid in (SELECT DISTINCT gid
		FROM tudo
		WHERE vrs_start_time <= '2014-06-12 11:21:00' and (vrs_end_time >= '2014-06-12 11:21:0' OR vrs_end_time IS NULL))
GROUP BY gid




