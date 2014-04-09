/**
DROP TABLE testes_versioning CASCADE;
DROP TABLE testes_versioning_bk CASCADE;
DROP FUNCTION "versioning"();
**/

-- the original table
CREATE TABLE testes_versioning(
gid serial primary key,
descr varchar(40),
geom geometry(MULTIPOLYGON,3763)
);

CREATE INDEX testes_versioning_idx
  ON testes_versioning
  USING gist
  (geom);

-- VERSIONING ::FIXME Make function of this

-- add versioning fields
ALTER TABLE testes_versioning
    ADD COLUMN "vrs_start_time" timestamp without time zone,
    ADD COLUMN "vrs_start_user" character varying(40);

-- create table to store backups
CREATE TABLE testes_versioning_bk (
   like testes_versioning
);
ALTER TABLE testes_versioning_bk
   ADD COLUMN "vrs_gid" serial primary key,
   ADD COLUMN "vrs_end_time" timestamp without time zone,
   ADD COLUMN "vrs_end_user" character varying(40);

-- function and trigger to update versioning fields and backup old rows
CREATE OR REPLACE FUNCTION "versioning"()
RETURNS trigger AS
$$
BEGIN
    -- update versioning fields on original table
    IF TG_OP IN ('UPDATE','INSERT') THEN
        NEW."vrs_start_time" = now();
        NEW."vrs_start_user" = user;
    end IF;

    -- send old row to backup table
    IF TG_OP IN ('UPDATE','DELETE') THEN
        INSERT INTO testes_versioning_bk
            SELECT OLD.*;
    end IF;

    IF TG_OP IN ('UPDATE','INSERT') THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    end IF;
end;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER "testes_versioning_trigger" BEFORE INSERT OR DELETE OR UPDATE ON "testes_versioning"
FOR EACH ROW EXECUTE PROCEDURE "versioning"();

-- function and trigger to register user and time of the backup
CREATE OR REPLACE FUNCTION "bk_versioning"()
RETURNS trigger AS
$$
BEGIN
    -- update versioning fields on backup table
        NEW."vrs_end_time" = now();
        NEW."vrs_end_user" = user;
        RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER "testes_versioning_bk_trigger" BEFORE INSERT ON "testes_versioning_bk"
FOR EACH ROW EXECUTE PROCEDURE "bk_versioning"()

-- Functions to visualize table in prior state in time
CREATE OR REPLACE FUNCTION "testes_versioning_at_time"(timestamp without time zone)
RETURNS SETOF "testes_versioning" AS
$$
	WITH all_table as 
	(
		SELECT * 
		  FROM testes_versioning as f 
		  WHERE f.vrs_start_time <= $1
		UNION ALL
		SELECT o.gid, o.descr, o.geom, o.vrs_start_time, o.vrs_start_user
		  FROM testes_versioning_bk As o 
		  WHERE o.vrs_start_time <= $1 AND o.vrs_end_time > $1
	)
	SELECT DISTINCT ON (gid) *
	  FROM all_table
	  ORDER BY gid, vrs_start_time DESC;
$$
LANGUAGE 'sql';

-- Function use example
SELECT * from testes_versioning_at_time ('2014-04-08 16:12:29.832');


-- tests
SELECT * FROM testes_versioning
UNION ALL
(SELECT 'SELECT ' || array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
        FROM information_schema.columns As c
            WHERE table_name = 'testes_versioning_bk' 
            AND  c.column_name NOT IN ('vrs_end_time','vrs_end_user','vrs_gid')
    ), ', ') || ' FROM testes_versioning_bk As o');


