
/****************************************************************************/
/**         Adds versioning functionalities to postgres database           **/
/**                        Alexandre Neto                                  **/
/**                      senhor.neto@gmail.com                             **/
/**                           10-04-2014                                   **/
/**                                                                        **/
/**                Copyright (C) 2013  Alexandre Neto                      **/
/**                                                                        **/
/**  This program is free software: you can redistribute it and/or modify  **/
/**  it under the terms of the GNU General Public License as published by  **/
/**  the Free Software Foundation, either version 3 of the License, or     **/
/**  (at your option) any later version.                                   **/
/**                                                                        **/
/**  This program is distributed in the hope that it will be useful,       **/
/**  but WITHOUT ANY WARRANTY; without even the implied warranty of        **/
/**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         **/
/**  GNU General Public License for more details.                          **/
/**                                                                        **/
/**  You should have received a copy of the GNU General Public License     **/
/**  along with this program.  If not, see <http://www.gnu.org/licenses/>  **/
/**                                                                        **/
/****************************************************************************/

-- ::FIXME do function to get backup table name from original table
-- ::FIXME do function to get schema and table names from concatenated table name
-- ::FIXME allow other names for primary keys

 
-- Install hstore EXTENSION
DROP EXTENSION IF EXISTS hstore;
CREATE EXTENSION hstore;

-- Create trigger fucntion to update versioning fields and backup old rows
CREATE OR REPLACE FUNCTION "vrs_table_update"()
RETURNS trigger AS
$$
DECLARE
	fields text;
BEGIN
    IF TG_OP IN ('UPDATE','INSERT') THEN
	-- update versioning fields on original table
	NEW."vrs_start_time" = now();
        NEW."vrs_start_user" = user;
    END IF;

    IF TG_OP = 'UPDATE' THEN
	--get a list of changed fields
	fields := 'gid,' || right(left(akeys((hstore(NEW)-hstore(OLD))::hstore)::text,-1),-1);

	-- move changed columns to backup table
        EXECUTE 'INSERT INTO ' || quote_ident(TG_TABLE_SCHEMA) || '.' || quote_ident(TG_TABLE_NAME || '_bk') || ' (' || fields ||')' ||
                ' VALUES (($1).'|| replace(fields,',',', ($1).') ||')'
        USING OLD;
    END IF;

    IF TG_OP = 'DELETE' THEN
	-- move complete row to backup table
        EXECUTE 'INSERT INTO ' || quote_ident(TG_TABLE_SCHEMA) || '.' || quote_ident(TG_TABLE_NAME || '_bk') ||
                ' SELECT ($1).*;'
        USING OLD;
    END IF;

    IF TG_OP IN ('UPDATE','INSERT') THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    END IF;
END;
$$
LANGUAGE 'plpgsql';

-- Create function for trigger to register user and time of the row backup
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

-- Function to create the versioning fields, backup table and related triggers on a table
CREATE OR REPLACE FUNCTION "vsr_add_versioning_to"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	_schema text;
	_table text;
	bk_table_name text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	-- compose backup table name
	bk_table_name := quote_ident(_schema) || '.' || quote_ident(_table || '_bk');
	
	-- add versioning fields to table
	EXECUTE 'ALTER TABLE ' || _t ||
		' ADD COLUMN "vrs_start_time" timestamp without time zone,
		  ADD COLUMN "vrs_start_user" character varying(40)';

        -- create indexes on versioning column to optimize queries
	
	EXECUTE 'CREATE INDEX ' || quote_ident(_table || '_time_idx') ||
		' ON ' || _t || ' (vrs_start_time)';

	-- populate versioning fields with values (useful is table already has data)
	EXECUTE 'UPDATE ' || _t || ' SET vrs_start_time = now(), vrs_start_user = user';

	-- create table to store backups
	EXECUTE 'CREATE TABLE ' || bk_table_name ||
		' (like ' || _t || ')';

	-- Drop NOT NULL constraints from backup table
	EXECUTE (SELECT 'ALTER TABLE '|| bk_table_name || ' ALTER '
			|| string_agg (quote_ident(attname), ' DROP NOT NULL, ALTER ')
			|| ' DROP NOT NULL'
		FROM   pg_catalog.pg_attribute
		WHERE  attrelid = bk_table_name::regclass
		AND    attnotnull
		AND    NOT attisdropped
		AND    attnum > 0
		AND    attname NOT like 'vrs%'
		);

	EXECUTE	'ALTER TABLE ' || bk_table_name ||
		' ADD COLUMN "vrs_gid" serial primary key,
		  ADD COLUMN "vrs_end_time" timestamp without time zone,
		  ADD COLUMN "vrs_end_user" character varying(40)';

	-- ::FIXME add spatial index to spatial tables

	EXECUTE	'CREATE INDEX ' || quote_ident(_table || '_bk_idx') || 
		' ON ' || bk_table_name || ' (gid, vrs_start_time, vrs_end_time)';

	-- create trigger to update versioning fields in table
	EXECUTE 'CREATE TRIGGER ' || quote_ident(_table || '_vrs_trigger') || ' BEFORE INSERT OR DELETE OR UPDATE ON ' || _t ||
		' FOR EACH ROW EXECUTE PROCEDURE "vrs_table_update"()';

	-- create trigger to update versioning fields in backup table
	EXECUTE 'CREATE TRIGGER ' || quote_ident(_table || '_bk_trigger') || ' BEFORE INSERT ON ' || bk_table_name ||
		' FOR EACH ROW EXECUTE PROCEDURE "vsr_bk_table_update"()';
	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- function to remove versioning from a table (including backup table)
CREATE OR REPLACE FUNCTION "vsr_remove_versioning_from"(_t regclass)
  RETURNS boolean AS
$body$
DECLARE
	_schema text;
	_table text;
	_table_bk text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	-- compose backup table name
	_table_bk := quote_ident(_schema) || '.' || quote_ident(_table || '_bk');
	
	-- Remove versioning fields from table
	EXECUTE 'ALTER TABLE ' || _t ||
		' DROP COLUMN IF EXISTS "vrs_start_time",
		  DROP COLUMN IF EXISTS "vrs_start_user"';

	-- Remove versioning trigger from table
	EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(_table || '_vrs_trigger') || ' ON ' || _t;

	-- create table to store backups
	EXECUTE 'DROP TABLE IF EXISTS ' || _table_bk || ' CASCADE';

	RETURN true;
END
$body$ LANGUAGE plpgsql;

-- Function to obtain a column data type
CREATE OR REPLACE FUNCTION "vsr_get_data_type"(_t regclass, _c text)
  RETURNS text AS
$body$
DECLARE
	_schema text;
	_table text;
	data_type text;
BEGIN
	-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
		_schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
		_table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
	ELSE
		_schema := 'public';
		_table := regexp_replace(_t::text,'"','','g');
	END IF;

	data_type := (SELECT format_type(a.atttypid, a.atttypmod)
	FROM pg_attribute a 
	JOIN pg_class b ON (a.attrelid = b.relfilenode)
	JOIN pg_namespace c ON (c.oid = b.relnamespace)
WHERE
	b.relname = _table AND
	c.nspname = _schema AND
	a.attname = _c);
	
	RETURN data_type;
END
$body$ LANGUAGE plpgsql;


-- Create first aggregation functions to use in "vsr_table_at_time"
-- Original code is from https://wiki.postgresql.org/wiki/First/last_(aggregate)

CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE sql IMMUTABLE STRICT AS $$
        SELECT $1;
$$;
 
-- And then wrap an aggregate around it
DROP AGGREGATE IF EXISTS public.first(anyelement);
CREATE AGGREGATE public.first (
        sfunc    = public.first_agg,
        basetype = anyelement,
        stype    = anyelement
);


-- Function to visualize tables in prior state in time
CREATE OR REPLACE FUNCTION "vsr_table_at_time"(_t anyelement, _d timestamp)
RETURNS SETOF anyelement AS
$$
DECLARE
	_tfn text;
	_schema text;
	_table text;
	_table_bk text;
	_col text;
	_col2 text;
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

	-- compose backup table name
	_table_bk := quote_ident(_schema) || '.' || quote_ident(_table || '_bk');

	-- preparing list of columns from table separated by commas
	-- this gets simple list of columns
	_col := (SELECT array_to_string(ARRAY(SELECT 'o' || '.' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = _schema and table_name = _table), ', '));
	--this gets list of columns with aggregation function and data type casting
	--casting is needed in order to allow "return set of anyelement"
	_col2 := (SELECT array_to_string(ARRAY(SELECT 'first(g' || '.' || c.column_name || ')::' || vsr_get_data_type(_tfn,c.column_name) || ' as ' || c.column_name
			FROM information_schema.columns As c
			WHERE table_schema = _schema and table_name = _table
						), ', '));
	
	RETURN QUERY EXECUTE format(
	'WITH g as 
		(
		SELECT %s
		  FROM %s AS o 
		  WHERE o.vrs_start_time <= $1 AND o.vrs_end_time > $1
		UNION ALL
		SELECT * 
		  FROM %s AS f
		)
	SELECT %s
	  FROM g
	  GROUP BY gid', _col, _table_bk, pg_typeof(_t), _col2)
	  USING _d;
END
$$
LANGUAGE plpgsql;