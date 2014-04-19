/** Add Versioning functionalities to database **/
/**                Alexandre Neto              **/
/**            senhor.neto@gmail.com           **/
/**                 10-04-2014                 **/

-- VERSIONING

-- function and trigger to update versioning fields and backup old rows
CREATE OR REPLACE FUNCTION "vrs_table_update"()
RETURNS trigger AS
$$
BEGIN

    -- update versioning fields on original table
    IF TG_OP IN ('UPDATE','INSERT') THEN
        NEW."vrs_start_time" = now();
        NEW."vrs_start_user" = user;
    end IF;

    -- move row to backup table
    IF TG_OP IN ('UPDATE','DELETE') THEN
        EXECUTE 'INSERT INTO ' || quote_ident(TG_TABLE_SCHEMA) || '.' || quote_ident(TG_TABLE_NAME || '_bk') ||
                ' SELECT ($1).*;'
        USING OLD;
    end IF;

    IF TG_OP IN ('UPDATE','INSERT') THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    end IF;
end;
$$
LANGUAGE 'plpgsql';

-- function and trigger to register user and time of the row backup
CREATE OR REPLACE FUNCTION "vsr_bk_table_update"()
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

CREATE OR REPLACE FUNCTION "vsr_add_versioning_to"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	schema_name text;
	table_name text;
	bk_table_name text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		schema_name := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		table_name := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		schema_name := 'public';
		table_name := regexp_replace(_t::text,'"','','g');
	END IF;

	bk_table_name := quote_ident(schema_name) || '.' || quote_ident(table_name || '_bk');
	
	-- add versioning fields to table
	EXECUTE 'ALTER TABLE ' || _t ||
		' ADD COLUMN "vrs_start_time" timestamp without time zone,
		  ADD COLUMN "vrs_start_user" character varying(40)';

        -- create indexes on versioning column to optimize queries
	
	EXECUTE 'CREATE INDEX ' || quote_ident(table_name || '_time_idx') ||
		' ON ' || _t || ' (vrs_start_time)';

	-- populate versioning fields with values (useful is table already has data)
	EXECUTE 'UPDATE ' || _t || ' SET vrs_start_time = now(), vrs_start_user = user';

	-- create table to store backups
	EXECUTE 'CREATE TABLE ' || bk_table_name ||
		' (like ' || _t || ')';

	EXECUTE	'ALTER TABLE ' || bk_table_name ||
		' ADD COLUMN "vrs_gid" serial primary key,
		  ADD COLUMN "vrs_end_time" timestamp without time zone,
		  ADD COLUMN "vrs_end_user" character varying(40)';

	EXECUTE	'CREATE INDEX ' || quote_ident(table_name || '_bk_idx') || 
		' ON ' || bk_table_name || ' (gid, vrs_start_time, vrs_end_time)';

	-- create trigger to update versioning fields in table
	EXECUTE 'CREATE TRIGGER ' || quote_ident(table_name || '_vrs_trigger') || ' BEFORE INSERT OR DELETE OR UPDATE ON ' || _t ||
		' FOR EACH ROW EXECUTE PROCEDURE "vrs_table_update"()';

	-- create trigger to update versioning fields in backup table
	EXECUTE 'CREATE TRIGGER ' || quote_ident(table_name || '_bk_trigger') || ' BEFORE INSERT ON ' || bk_table_name ||
		' FOR EACH ROW EXECUTE PROCEDURE "vsr_bk_table_update"()';
	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- function to remove versioning from a table (including backup table)
CREATE OR REPLACE FUNCTION "vsr_remove_versioning_from"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	schema_name text;
	table_name text;
	bk_table_name text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		schema_name := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		table_name := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		schema_name := 'public';
		table_name := regexp_replace(_t::text,'"','','g');
	END IF;

	bk_table_name := quote_ident(schema_name) || '.' || quote_ident(table_name || '_bk');
	
	-- Remove versioning fields from table
	EXECUTE 'ALTER TABLE ' || _t ||
		' DROP COLUMN IF EXISTS "vrs_start_time",
		  DROP COLUMN IF EXISTS "vrs_start_user"';

	-- Remove versioning trigger from table
	EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(table_name || '_vrs_trigger') || ' ON ' || _t;

	-- create table to store backups
	EXECUTE 'DROP TABLE IF EXISTS ' || bk_table_name || ' CASCADE';

	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- Function to visualize tables in prior state in time
-- ::FIXME to work with any versionalized table
CREATE OR REPLACE FUNCTION "vsr_table_at_time"(_t anyelement, _d timestamp)
RETURNS SETOF anyelement AS
$$
DECLARE
	_tfn text;
	_schema text;
	_table text;
	_table_bk text;
	_col text;
BEGIN
	-- Separate schema and table names
	_tfn := pg_typeof(_t)::text;
	IF _tfn LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_tfn, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_tfn, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_tfn,'"','','g');
	END IF;

	_table_bk := quote_ident(_schema) || '.' || quote_ident(_table || '_bk');

	-- getting columns from table
	_col := (SELECT array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = _schema and table_name = _table), ', '));

	RETURN QUERY EXECUTE format(
	'WITH g as 
		(
		SELECT * 
		  FROM %s AS f 
		  WHERE f.vrs_start_time <= $1
		UNION ALL
		SELECT %s
		  FROM %s AS o 
		  WHERE o.vrs_start_time <= $1 AND o.vrs_end_time > $1
		)
	SELECT DISTINCT ON (gid) *
	  FROM g
	  ORDER BY gid, vrs_start_time DESC', pg_typeof(_t), _col, _table_bk)
	  USING _d;
END
$$
LANGUAGE plpgsql;

-- USAGE EXAMPLE
-- the original table
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
SELECT * from vsr_table_at_time (NULL::"PGHP_2".testes_versioning, '2014-04-19 18:26:57');

-- See specific feature at certain time
SELECT * from vsr_table_at_time (NULL::"PGHP_2".testes_versioning, '2014-04-19 18:26:57') WHERE gid = 1;
