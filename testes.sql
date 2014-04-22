SELECT gid, descr, geom, vrs_start_time, vrs_start_user from "PGHP_2".testes_versioning

SELECT gid, descr, geom, vrs_start_time, vrs_start_user from "PGHP_2".testes_versioning_bk

"2014-04-22 14:47:45.008"

WITH all_tables as
(
SELECT gid, descr, geom, vrs_start_time, vrs_start_user
FROM "PGHP_2".testes_versioning_bk
WHERE vrs_start_time <= '2014-04-22 14:47:44.008' and vrs_end_time > '2014-04-22 14:47:44.008'
UNION ALL
SELECT gid, descr, geom, vrs_start_time, vrs_start_user
FROM "PGHP_2".testes_versioning
)
SELECT gid, first(descr) as descr, first(geom) as geom, first(vrs_start_time) as vrs_start_time, first(vrs_start_user) as vrs_start_user
FROM all_tables
GROUP BY gid
ORDER BY gid
SELECT array_to_string(ARRAY(SELECT 'first(g.' || c.column_name || ') as ' || c.column_name

SELECT array_to_string(ARRAY(SELECT 'first(g.' || c.column_name || ') as ' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = 'PGHP_2' and table_name = 'testes_versioning'), ', ')


SELECT array_to_string(ARRAY(SELECT 'first(g.' || c.column_name || ') as ' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = 'PGHP_2' and table_name = 'testes_versioning'), ', ')